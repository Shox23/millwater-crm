import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/throttle.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/notification_event.dart';
import '../../../data/models/order.dart';
import '../../../data/models/result_page.dart';
import 'orders_source.dart';

import 'orders_date_filter.dart';

export 'orders_date_filter.dart';

part 'orders_event.dart';
part 'orders_state.dart';

/// Список заказов: страницы, отбор и поиск.
///
/// Один блок на обе роли — различие спрятано в [OrdersSource]. Весь отбор
/// делает сервер: у `/admin/orders` и `/driver/orders` есть и статус, и цель,
/// и поиск по имени, телефону и адресу. Досчитывать что-либо на клиенте
/// здесь нельзя: страница — не вся выдача, и локальный фильтр поверх неё
/// показывал бы «ничего не найдено» там, где найденное лежит на второй.
class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc(this._source, {Stream<NotificationEvent>? notifications})
      : super(const OrdersState()) {
    on<OrdersRequested>(_onRequested);
    on<OrdersSearchChanged>(_onSearchChanged);
    on<OrdersStatusChanged>(_onStatusChanged);
    on<OrdersPurposeChanged>(_onPurposeChanged);
    on<OrdersDateChanged>(_onDateChanged);
    on<OrdersNextPageRequested>(_onNextPage);

    // Водитель закрыл заказ — список устарел прямо сейчас. Первое событие
    // перечитывает сразу, всплеск за ним — один раз: утром водители
    // закрывают точки почти одновременно.
    _notifications = notifications?.listen(
      (_) => _reload(() {
        if (!isClosed) add(const OrdersRequested());
      }),
    );
  }

  final OrdersSource _source;
  StreamSubscription<NotificationEvent>? _notifications;
  final _reload = Throttle(kNotificationReloadWindow);

  /// Откладывает запрос, пока пользователь печатает.
  Timer? _debounce;
  static const _debounceDelay = Duration(milliseconds: 300);

  /// Номер последнего запроса: ответы обогнавших друг друга запросов не
  /// должны затирать более свежий результат.
  int _requestId = 0;

  @override
  Future<void> close() async {
    _debounce?.cancel();
    _reload.dispose();
    await _notifications?.cancel();
    return super.close();
  }

  Future<void> _onRequested(
    OrdersRequested event,
    Emitter<OrdersState> emit,
  ) async {
    final id = ++_requestId;
    emit(state.copyWith(status: OrdersStatus.loading));
    try {
      final page = await _load(1);
      if (id != _requestId) return;
      emit(state.copyWith(
        status: OrdersStatus.ready,
        orders: page.items,
        page: page.page,
        hasMore: page.hasMore,
        total: page.total,
        loadingMore: false,
      ));
    } catch (_) {
      if (id != _requestId) return;
      emit(state.copyWith(status: OrdersStatus.error, loadingMore: false));
    }
  }

  /// Догружает следующую страницу в конец списка.
  Future<void> _onNextPage(
    OrdersNextPageRequested event,
    Emitter<OrdersState> emit,
  ) async {
    if (!state.hasMore || state.loadingMore) return;
    if (state.status == OrdersStatus.loading) return;

    final id = _requestId;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _load(state.page + 1);
      // Пока страница шла, отбор могли поменять — она уже не о том.
      if (id != _requestId) return;
      emit(state.copyWith(
        orders: [...state.orders, ...page.items],
        page: page.page,
        hasMore: page.hasMore,
        total: page.total,
        loadingMore: false,
      ));
    } catch (_) {
      if (id != _requestId) return;
      // Показанное не рушим: не догрузилось — список остался прежним,
      // а повторить можно ещё одной прокруткой.
      emit(state.copyWith(loadingMore: false));
    }
  }

  Future<ResultPage<Order>> _load(int page) {
    final (from, to) = state.dateFilter.range;
    return _source.load(
      page: page,
      status: state.statusFilter,
      purpose: state.purposeFilter,
      search: state.query,
      dateFrom: from,
      dateTo: to,
    );
  }

  void _onDateChanged(OrdersDateChanged event, Emitter<OrdersState> emit) {
    if (event.filter == state.dateFilter) return;
    // Как и у остальных фильтров: отложенный запрос от набора текста ушёл бы
    // со старым отбором и затёр бы свежий ответ.
    _debounce?.cancel();
    emit(state.copyWith(dateFilter: event.filter));
    add(const OrdersRequested());
  }

  void _onStatusChanged(OrdersStatusChanged event, Emitter<OrdersState> emit) {
    if (event.status == state.statusFilter) return;
    // Отложенный запрос от набора текста здесь только помешает: он ушёл бы
    // со старым отбором и затёр бы свежий ответ.
    _debounce?.cancel();
    emit(state.copyWith(statusFilter: event.status, clearStatus: true));
    add(const OrdersRequested());
  }

  void _onPurposeChanged(
    OrdersPurposeChanged event,
    Emitter<OrdersState> emit,
  ) {
    if (event.purpose == state.purposeFilter) return;
    _debounce?.cancel();
    emit(state.copyWith(purposeFilter: event.purpose, clearPurpose: true));
    add(const OrdersRequested());
  }

  void _onSearchChanged(
    OrdersSearchChanged event,
    Emitter<OrdersState> emit,
  ) {
    emit(state.copyWith(query: event.query));
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!isClosed) add(const OrdersRequested());
    });
  }
}

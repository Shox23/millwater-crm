import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/text_match.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/crm_repository.dart';

part 'customers_event.dart';
part 'customers_state.dart';

class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  CustomersBloc(this._repository) : super(const CustomersState()) {
    on<CustomersRequested>(_onRequested);
    on<CustomersSearchChanged>(_onSearchChanged);
    on<CustomersFilterChanged>(_onFilterChanged);
    on<CustomersSearchModeChanged>(_onSearchModeChanged);
    on<CustomersNextPageRequested>(_onNextPage);
  }

  final CrmRepository _repository;

  /// Откладывает запрос, пока пользователь печатает.
  Timer? _debounce;

  /// Номер последнего запроса: ответы обогнавших друг друга запросов
  /// не должны затирать более свежий результат.
  int _requestId = 0;

  /// Полная выборка для поиска по адресу.
  ///
  /// Параметра `address` в API нет, поэтому отбор идёт здесь — а чтобы не
  /// обходить все страницы на каждую букву, выборка живёт между нажатиями
  /// клавиш. Любой другой повод перечитать список (обновление, смена чипа,
  /// правка заказчика) её сбрасывает: она уже могла устареть.
  List<Customer>? _addressPool;

  /// Перезагрузка пришла из набора текста — выборку можно не перезапрашивать.
  bool _fromTyping = false;

  static const _debounceDelay = Duration(milliseconds: 300);

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  Future<void> _onRequested(
    CustomersRequested event,
    Emitter<CustomersState> emit,
  ) async {
    final id = ++_requestId;
    // Выборку под адресный поиск бережём только между нажатиями клавиш.
    final keepPool = _fromTyping;
    _fromTyping = false;
    if (!keepPool) _addressPool = null;

    emit(state.copyWith(status: CustomersStatus.loading));
    try {
      if (state.isAddressSearch) {
        await _loadByAddress(id, emit);
        return;
      }
      // Фильтрует сервер, а не мы: локальный фильтр поверх серверного прятал
      // бы часть найденного. Берём первую страницу — остальные догрузит
      // прокрутка, см. [CustomersNextPageRequested].
      final page = await _repository.getCustomersPage(
        search: state.query,
        hasDebt: state.filter.hasDebt,
        hasCooler: state.filter.hasCooler,
        isActive: state.filter.isActive,
      );
      if (id != _requestId) return;
      emit(state.copyWith(
        status: CustomersStatus.ready,
        customers: page.items,
        page: page.page,
        hasMore: page.hasMore,
        total: page.total,
        loadingMore: false,
      ));
    } catch (_) {
      if (id != _requestId) return;
      emit(state.copyWith(status: CustomersStatus.error, loadingMore: false));
    }
  }

  /// Ищет по адресу поверх полной выборки.
  ///
  /// Страниц здесь нет: список уже полон, и `hasMore` выключается — иначе
  /// прокрутка просила бы вторую страницу того, что целиком на экране.
  Future<void> _loadByAddress(int id, Emitter<CustomersState> emit) async {
    final pool = _addressPool ??= await _repository.getCustomers(
      hasDebt: state.filter.hasDebt,
      hasCooler: state.filter.hasCooler,
      isActive: state.filter.isActive,
    );
    if (id != _requestId) return;

    final found = pool
        .where((c) => matchesAllWords(c.address, state.query))
        .toList();

    emit(state.copyWith(
      status: CustomersStatus.ready,
      customers: found,
      page: 1,
      hasMore: false,
      total: found.length,
      loadingMore: false,
    ));
  }

  /// Догружает следующую страницу в конец списка.
  ///
  /// Молча выходит, если грузить нечего или загрузка уже идёт: событие
  /// приходит из обработчика прокрутки и повторяется на каждый кадр у края.
  Future<void> _onNextPage(
    CustomersNextPageRequested event,
    Emitter<CustomersState> emit,
  ) async {
    if (!state.hasMore || state.loadingMore) return;
    if (state.status == CustomersStatus.loading) return;

    final id = _requestId;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repository.getCustomersPage(
        page: state.page + 1,
        search: state.query,
        hasDebt: state.filter.hasDebt,
        hasCooler: state.filter.hasCooler,
        isActive: state.filter.isActive,
      );
      // Пока страница шла, поиск могли поменять — её содержимое уже не о том.
      if (id != _requestId) return;
      emit(state.copyWith(
        customers: [...state.customers, ...page.items],
        page: page.page,
        hasMore: page.hasMore,
        total: page.total,
        loadingMore: false,
      ));
    } catch (_) {
      if (id != _requestId) return;
      // Показанное не рушим: не догрузилось — значит, список остался прежним,
      // а повторить можно ещё одной прокруткой.
      emit(state.copyWith(loadingMore: false));
    }
  }

  void _onFilterChanged(
    CustomersFilterChanged event,
    Emitter<CustomersState> emit,
  ) {
    if (event.filter == state.filter) return;
    // Отложенный запрос от набора текста здесь только помешает: он ушёл бы
    // со старым фильтром и затёр бы свежий ответ.
    _debounce?.cancel();
    emit(state.copyWith(filter: event.filter));
    add(const CustomersRequested());
  }

  void _onSearchModeChanged(
    CustomersSearchModeChanged event,
    Emitter<CustomersState> emit,
  ) {
    if (event.mode == state.searchMode) return;
    _debounce?.cancel();
    emit(state.copyWith(searchMode: event.mode));
    add(const CustomersRequested());
  }

  void _onSearchChanged(
    CustomersSearchChanged event,
    Emitter<CustomersState> emit,
  ) {
    emit(state.copyWith(query: event.query));
    // Следующая перезагрузка — из набора текста: полную выборку под адресный
    // поиск она переиспользует, а не тянет заново на каждую букву.
    _fromTyping = true;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!isClosed) add(const CustomersRequested());
    });
  }
}

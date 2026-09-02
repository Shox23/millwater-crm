import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    on<CustomersNextPageRequested>(_onNextPage);
  }

  final CrmRepository _repository;

  /// Откладывает запрос, пока пользователь печатает.
  Timer? _debounce;

  /// Номер последнего запроса: ответы обогнавших друг друга запросов
  /// не должны затирать более свежий результат.
  int _requestId = 0;

  static const _debounceDelay = Duration(milliseconds: 300);

  /// Оставляет из страницы то, что просит чип.
  ///
  /// Сервер отбирает всё, кроме кулеров: параметр `has_cooler` он потерял
  /// вместе с самим полем, а неизвестный query-параметр молча игнорирует —
  /// то есть без этого отбора чип «С кулером» показывал бы всех подряд.
  ///
  /// Отбор идёт по уже загруженным страницам, и это видно: счётчик в шапке
  /// считает найденное, а страница может прийти почти пустой. Убрать, когда
  /// сервер вернёт фильтр, — см. [CustomerFilter.filtersCoolerLocally].
  List<Customer> _applyLocalFilter(List<Customer> items) =>
      state.filter.filtersCoolerLocally
          ? items.where((c) => c.hasCooler).toList()
          : items;

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

    emit(state.copyWith(status: CustomersStatus.loading));
    try {
      // Ищет сервер: `search` у него идёт по имени, телефону и адресу сразу,
      // поэтому отдельного режима поиска по адресу с выкачиванием всей базы
      // больше нет. Берём первую страницу — остальные догрузит прокрутка,
      // см. [CustomersNextPageRequested].
      final page = await _repository.getCustomersPage(
        search: state.query,
        hasDebt: state.filter.hasDebt,
        isActive: state.filter.isActive,
      );
      if (id != _requestId) return;
      final items = _applyLocalFilter(page.items);
      emit(state.copyWith(
        status: CustomersStatus.ready,
        customers: items,
        page: page.page,
        hasMore: page.hasMore,
        // При клиентском отборе серверный `total` считает не то, что видно на
        // экране: он не знает про кулеры. Показываем найденное.
        total: state.filter.filtersCoolerLocally ? items.length : page.total,
        loadingMore: false,
      ));
    } catch (_) {
      if (id != _requestId) return;
      emit(state.copyWith(status: CustomersStatus.error, loadingMore: false));
    }
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
        isActive: state.filter.isActive,
      );
      // Пока страница шла, поиск могли поменять — её содержимое уже не о том.
      if (id != _requestId) return;
      final items = [...state.customers, ..._applyLocalFilter(page.items)];
      emit(state.copyWith(
        customers: items,
        page: page.page,
        hasMore: page.hasMore,
        total: state.filter.filtersCoolerLocally ? items.length : page.total,
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

  void _onSearchChanged(
    CustomersSearchChanged event,
    Emitter<CustomersState> emit,
  ) {
    emit(state.copyWith(query: event.query));
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!isClosed) add(const CustomersRequested());
    });
  }
}

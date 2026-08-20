import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/customer.dart';
import '../../../data/repositories/crm_repository.dart';

part 'customers_event.dart';
part 'customers_state.dart';

class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  CustomersBloc(this._repository) : super(const CustomersState()) {
    on<CustomersRequested>(_onRequested);
    on<CustomersSearchChanged>(_onSearchChanged);
    on<CustomersNextPageRequested>(_onNextPage);
  }

  final CrmRepository _repository;

  /// Откладывает запрос, пока пользователь печатает.
  Timer? _debounce;

  /// Номер последнего запроса: ответы обогнавших друг друга запросов
  /// не должны затирать более свежий результат.
  int _requestId = 0;

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
    emit(state.copyWith(status: CustomersStatus.loading));
    try {
      // Фильтрует сервер, а не мы: локальный фильтр поверх серверного прятал
      // бы часть найденного. Берём первую страницу — остальные догрузит
      // прокрутка, см. [CustomersNextPageRequested].
      final page = await _repository.getCustomersPage(search: state.query);
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

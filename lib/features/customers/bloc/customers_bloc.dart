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
      // Фильтрует сервер: локально видна лишь первая страница выдачи.
      final customers = await _repository.getCustomers(search: state.query);
      if (id != _requestId) return;
      emit(state.copyWith(status: CustomersStatus.ready, customers: customers));
    } catch (_) {
      if (id != _requestId) return;
      emit(state.copyWith(status: CustomersStatus.error));
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

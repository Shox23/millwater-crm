import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/driver.dart';
import '../../../data/repositories/crm_repository.dart';

part 'drivers_event.dart';
part 'drivers_state.dart';

class DriversBloc extends Bloc<DriversEvent, DriversState> {
  DriversBloc(this._repository) : super(const DriversState()) {
    on<DriversRequested>(_onRequested);
    on<DriversSearchChanged>(_onSearchChanged);
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
    DriversRequested event,
    Emitter<DriversState> emit,
  ) async {
    final id = ++_requestId;
    emit(state.copyWith(status: DriversStatus.loading));
    try {
      // Фильтрует сервер: локально видна лишь первая страница выдачи.
      final drivers = await _repository.getDrivers(search: state.query);
      if (id != _requestId) return;
      emit(state.copyWith(status: DriversStatus.ready, drivers: drivers));
    } catch (_) {
      if (id != _requestId) return;
      emit(state.copyWith(status: DriversStatus.error));
    }
  }

  void _onSearchChanged(
    DriversSearchChanged event,
    Emitter<DriversState> emit,
  ) {
    emit(state.copyWith(query: event.query));
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!isClosed) add(const DriversRequested());
    });
  }
}

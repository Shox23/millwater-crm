import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/route_models.dart';
import '../../../data/repositories/driver_repository.dart';

part 'my_routes_event.dart';
part 'my_routes_state.dart';

/// Маршруты текущего водителя.
///
/// В отличие от админского `RoutesBloc` здесь один запрос: сводный отчёт
/// (`/admin/reports/summary`) водителю недоступен, а денежных показателей
/// на его экране и не предусмотрено.
class MyRoutesBloc extends Bloc<MyRoutesEvent, MyRoutesState> {
  MyRoutesBloc(this._repository) : super(const MyRoutesState()) {
    on<MyRoutesRequested>(_onRequested);
    on<MyRoutesFilterChanged>(_onFilterChanged);
  }

  final DriverRepository _repository;

  Future<void> _onRequested(
    MyRoutesRequested event,
    Emitter<MyRoutesState> emit,
  ) async {
    emit(state.copyWith(status: MyRoutesStatus.loading));
    try {
      final routes = await _repository.getMyRoutes();
      emit(state.copyWith(status: MyRoutesStatus.ready, routes: routes));
    } catch (_) {
      emit(state.copyWith(status: MyRoutesStatus.error));
    }
  }

  void _onFilterChanged(
    MyRoutesFilterChanged event,
    Emitter<MyRoutesState> emit,
  ) {
    emit(state.copyWith(filter: event.filter));
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/route_models.dart';
import '../../../data/repositories/crm_repository.dart';

part 'routes_event.dart';
part 'routes_state.dart';

class RoutesBloc extends Bloc<RoutesEvent, RoutesState> {
  RoutesBloc(this._repository) : super(const RoutesState()) {
    on<RoutesRequested>(_onRequested);
    on<RoutesFilterChanged>(_onFilterChanged);
  }

  final CrmRepository _repository;

  Future<void> _onRequested(
    RoutesRequested event,
    Emitter<RoutesState> emit,
  ) async {
    emit(state.copyWith(status: RoutesStatus.loading));
    try {
      // Выручки нет в списке маршрутов — берём её из сводного отчёта.
      final routes = await _repository.getRoutes();
      final summary = await _repository.getReportsSummary();
      emit(state.copyWith(
        status: RoutesStatus.ready,
        routes: routes,
        collected: summary.revenueToday,
      ));
    } catch (e) {
      emit(state.copyWith(status: RoutesStatus.error, error: e.toString()));
    }
  }

  void _onFilterChanged(
    RoutesFilterChanged event,
    Emitter<RoutesState> emit,
  ) {
    emit(state.copyWith(filter: event.filter));
  }
}

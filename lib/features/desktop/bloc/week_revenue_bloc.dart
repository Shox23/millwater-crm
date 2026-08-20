import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/day.dart';
import '../../../data/repositories/crm_repository.dart';

part 'week_revenue_event.dart';
part 'week_revenue_state.dart';

/// Выручка по дням недели — столбики графика в отчётах.
///
/// Сводка (`/admin/reports/summary`) отдаёт агрегат за период целиком, а не
/// разбивку по дням, поэтому за каждый день идёт свой запрос. Семь запросов
/// уходят параллельно и ровно один раз на открытие раздела: перечитывать их
/// на каждую перерисовку было бы расточительством.
class WeekRevenueBloc extends Bloc<WeekRevenueEvent, WeekRevenueState> {
  WeekRevenueBloc(this._repository) : super(const WeekRevenueState()) {
    on<WeekRevenueRequested>(_onRequested);
  }

  final CrmRepository _repository;

  Future<void> _onRequested(
    WeekRevenueRequested event,
    Emitter<WeekRevenueState> emit,
  ) async {
    emit(state.copyWith(status: WeekRevenueStatus.loading));

    try {
      final days = WeekRevenueState.week();
      final reports = await Future.wait(
        days.map((day) => _repository.getSummaryReport(
              dateFrom: day,
              dateTo: day,
            )),
      );

      emit(state.copyWith(
        status: WeekRevenueStatus.ready,
        bars: [
          for (final (i, report) in reports.indexed)
            RevenueBar(day: days[i], revenue: report.totalRevenue),
        ],
      ));
    } catch (_) {
      emit(state.copyWith(status: WeekRevenueStatus.error));
    }
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';
import '../../../data/models/reports_summary.dart';
import '../../../data/repositories/crm_repository.dart';

part 'reports_event.dart';
part 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  ReportsBloc(this._repository) : super(const ReportsState()) {
    on<ReportsRequested>(_onRequested);
    on<ReportsPeriodChanged>(_onPeriodChanged);
  }

  final CrmRepository _repository;

  Future<void> _onRequested(
    ReportsRequested event,
    Emitter<ReportsState> emit,
  ) async {
    emit(state.copyWith(status: ReportsStatus.loading));
    try {
      final (from, to) = _rangeFor(state.period);
      final summary =
          await _repository.getReportsSummary(dateFrom: from, dateTo: to);
      emit(state.copyWith(status: ReportsStatus.ready, summary: summary));
    } catch (_) {
      emit(state.copyWith(status: ReportsStatus.error));
    }
  }

  void _onPeriodChanged(
    ReportsPeriodChanged event,
    Emitter<ReportsState> emit,
  ) {
    emit(state.copyWith(period: event.period));
    add(const ReportsRequested());
  }

  /// Границы периода для запроса отчёта.
  (DateTime, DateTime) _rangeFor(ReportPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      ReportPeriod.today => (today, today),
      ReportPeriod.week => (today.subtract(const Duration(days: 6)), today),
      ReportPeriod.month => (DateTime(now.year, now.month, 1), today),
    };
  }
}

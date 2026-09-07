part of 'reports_bloc.dart';

/// Период отчёта (селектор в шапке) — общий с профилем водителя.
typedef ReportPeriod = StatsPeriod;

sealed class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

class ReportsRequested extends ReportsEvent {
  const ReportsRequested();
}

class ReportsPeriodChanged extends ReportsEvent {
  const ReportsPeriodChanged(this.period);
  final ReportPeriod period;

  @override
  List<Object?> get props => [period];
}

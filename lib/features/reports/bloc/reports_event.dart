part of 'reports_bloc.dart';

/// Период отчёта (селектор в шапке): пресет или диапазон из календаря.
///
/// Раньше был синонимом [StatsPeriod]; теперь это [DatePeriod], потому что
/// админу нужно и «с 3-го по 12-е», а профиль водителя остался на пресетах.
typedef ReportPeriod = DatePeriod;

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

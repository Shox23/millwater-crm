part of 'reports_bloc.dart';

/// Период отчёта (селектор в шапке).
enum ReportPeriod {
  today,
  week,
  month;

  String get label => switch (this) {
        ReportPeriod.today => 'Сегодня',
        ReportPeriod.week => 'Неделя',
        ReportPeriod.month => 'Месяц',
      };
}

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

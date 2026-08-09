part of 'reports_bloc.dart';

/// Период отчёта (селектор в шапке).
enum ReportPeriod {
  today,
  week,
  month;

  /// Подпись периода на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        ReportPeriod.today => l10n.periodToday,
        ReportPeriod.week => l10n.periodWeek,
        ReportPeriod.month => l10n.periodMonth,
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

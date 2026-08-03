part of 'reports_bloc.dart';

enum ReportsStatus { initial, loading, ready, error }

class ReportsState extends Equatable {
  const ReportsState({
    this.status = ReportsStatus.initial,
    this.summary,
    this.period = ReportPeriod.today,
  });

  final ReportsStatus status;
  final ReportsSummary? summary;
  final ReportPeriod period;

  ReportsState copyWith({
    ReportsStatus? status,
    ReportsSummary? summary,
    ReportPeriod? period,
  }) {
    return ReportsState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      period: period ?? this.period,
    );
  }

  @override
  List<Object?> get props => [status, summary, period];
}

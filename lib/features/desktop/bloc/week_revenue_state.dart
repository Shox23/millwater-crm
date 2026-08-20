part of 'week_revenue_bloc.dart';

enum WeekRevenueStatus { initial, loading, ready, error }

/// Один столбик графика.
class RevenueBar extends Equatable {
  const RevenueBar({required this.day, required this.revenue});

  final DateTime day;
  final int revenue;

  @override
  List<Object?> get props => [day, revenue];
}

class WeekRevenueState extends Equatable {
  const WeekRevenueState({
    this.status = WeekRevenueStatus.initial,
    this.bars = const [],
  });

  final WeekRevenueStatus status;
  final List<RevenueBar> bars;

  /// Семь дней по сегодняшний включительно.
  static List<DateTime> week() {
    final today = dayOnly(DateTime.now());
    return [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
  }

  /// Самый высокий столбик — по нему масштабируются остальные.
  int get maxRevenue =>
      bars.fold<int>(0, (max, bar) => bar.revenue > max ? bar.revenue : max);

  WeekRevenueState copyWith({
    WeekRevenueStatus? status,
    List<RevenueBar>? bars,
  }) {
    return WeekRevenueState(
      status: status ?? this.status,
      bars: bars ?? this.bars,
    );
  }

  @override
  List<Object?> get props => [status, bars];
}

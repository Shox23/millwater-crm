part of 'week_revenue_bloc.dart';

sealed class WeekRevenueEvent extends Equatable {
  const WeekRevenueEvent();

  @override
  List<Object?> get props => [];
}

class WeekRevenueRequested extends WeekRevenueEvent {
  const WeekRevenueRequested();
}

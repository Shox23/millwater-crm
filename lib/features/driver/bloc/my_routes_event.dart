part of 'my_routes_bloc.dart';

sealed class MyRoutesEvent extends Equatable {
  const MyRoutesEvent();

  @override
  List<Object?> get props => [];
}

class MyRoutesRequested extends MyRoutesEvent {
  const MyRoutesRequested();
}

class MyRoutesFilterChanged extends MyRoutesEvent {
  const MyRoutesFilterChanged(this.filter);
  final RouteFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// Выбран другой день в ленте дат.
class MyRoutesDateChanged extends MyRoutesEvent {
  const MyRoutesDateChanged(this.date);
  final DateTime date;

  @override
  List<Object?> get props => [date];
}

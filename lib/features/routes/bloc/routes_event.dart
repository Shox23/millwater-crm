part of 'routes_bloc.dart';

sealed class RoutesEvent extends Equatable {
  const RoutesEvent();

  @override
  List<Object?> get props => [];
}

class RoutesRequested extends RoutesEvent {
  const RoutesRequested();
}

class RoutesFilterChanged extends RoutesEvent {
  const RoutesFilterChanged(this.filter);
  final RouteFilter filter;

  @override
  List<Object?> get props => [filter];
}

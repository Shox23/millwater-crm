part of 'routes_bloc.dart';

/// Фильтр списка маршрутов (чипы на экране).
enum RouteFilter {
  all('Все'),
  inProgress('В пути'),
  completed('Завершены'),
  created('Новые');

  const RouteFilter(this.label);
  final String label;
}

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

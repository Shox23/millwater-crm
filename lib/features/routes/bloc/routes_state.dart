part of 'routes_bloc.dart';

enum RoutesStatus { initial, loading, ready, error }

class RoutesState extends Equatable {
  const RoutesState({
    this.status = RoutesStatus.initial,
    this.routes = const [],
    this.filter = RouteFilter.all,
    this.collected = 0,
    this.error,
  });

  final RoutesStatus status;
  final List<RouteListItem> routes;
  final RouteFilter filter;

  /// Собрано за период (из сводного отчёта).
  final int collected;
  final String? error;

  /// Список с учётом активного фильтра.
  List<RouteListItem> get visible {
    final wanted = filter.status;
    if (wanted == null) return routes;
    return routes.where((r) => r.status == wanted).toList();
  }

  /// Всего остановок во всех маршрутах.
  int get stopsTotal =>
      routes.fold<int>(0, (sum, r) => sum + r.totalCustomers);

  /// Завершённых остановок.
  int get stopsDone =>
      routes.fold<int>(0, (sum, r) => sum + r.completedCount);

  /// Маршруты «в работе» — созданные и выполняющиеся.
  int get inWorkCount => routes
      .where((r) =>
          r.status == RouteStatus.created || r.status == RouteStatus.inProgress)
      .length;

  RoutesState copyWith({
    RoutesStatus? status,
    List<RouteListItem>? routes,
    RouteFilter? filter,
    int? collected,
    String? error,
  }) {
    return RoutesState(
      status: status ?? this.status,
      routes: routes ?? this.routes,
      filter: filter ?? this.filter,
      collected: collected ?? this.collected,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, routes, filter, collected, error];
}

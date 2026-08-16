part of 'routes_bloc.dart';

enum RoutesStatus { initial, loading, ready, error }

class RoutesState extends Equatable {
  const RoutesState({
    required this.date,
    this.status = RoutesStatus.initial,
    this.routes = const [],
    this.filter = RouteFilter.all,
    this.collected = 0,
  });

  /// Выбранный день: за него запрошены и [routes], и [collected].
  final DateTime date;

  final RoutesStatus status;
  final List<RouteListItem> routes;
  final RouteFilter filter;

  /// Собрано за выбранный день (из сводного отчёта).
  final int collected;

  /// Список с учётом активного фильтра.
  List<RouteListItem> get visible {
    final wanted = filter.status;
    if (wanted == null) return routes;
    return routes.where((r) => r.status == wanted).toList();
  }

  /// Всего остановок за день.
  int get stopsTotal =>
      routes.fold<int>(0, (sum, r) => sum + r.totalCustomers);

  /// Завершённых остановок за день.
  int get stopsDone =>
      routes.fold<int>(0, (sum, r) => sum + r.completedCount);

  RoutesState copyWith({
    DateTime? date,
    RoutesStatus? status,
    List<RouteListItem>? routes,
    RouteFilter? filter,
    int? collected,
  }) {
    return RoutesState(
      date: date ?? this.date,
      status: status ?? this.status,
      routes: routes ?? this.routes,
      filter: filter ?? this.filter,
      collected: collected ?? this.collected,
    );
  }

  @override
  List<Object?> get props => [date, status, routes, filter, collected];
}

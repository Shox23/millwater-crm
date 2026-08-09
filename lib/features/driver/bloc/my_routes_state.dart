part of 'my_routes_bloc.dart';

enum MyRoutesStatus { initial, loading, ready, error }

class MyRoutesState extends Equatable {
  const MyRoutesState({
    this.status = MyRoutesStatus.initial,
    this.routes = const [],
    this.filter = RouteFilter.all,
  });

  final MyRoutesStatus status;
  final List<RouteListItem> routes;
  final RouteFilter filter;

  /// Список с учётом активного фильтра.
  List<RouteListItem> get visible {
    final wanted = filter.status;
    if (wanted == null) return routes;
    return routes.where((r) => r.status == wanted).toList();
  }

  /// Маршруты на сегодня.
  ///
  /// Дата берётся с устройства: серверного «сегодня» в ответе нет, а водитель
  /// смотрит экран там же, где ездит. Сравниваются календарные дни — в
  /// `date` маршрута времени нет, и приводить к полуночи нечего.
  List<RouteListItem> get todayRoutes {
    final now = DateTime.now();
    return routes
        .where((r) =>
            r.date.year == now.year &&
            r.date.month == now.month &&
            r.date.day == now.day)
        .toList();
  }

  /// Показатели главного экрана водителя (ТЗ, раздел 5).
  int get routesCount => routes.length;

  int get stopsTotal => routes.fold<int>(0, (sum, r) => sum + r.totalCustomers);

  /// Доставлено сегодня — только по сегодняшним маршрутам: шапка экрана
  /// подписана «Сегодня», и цифры под ней должны значить то же самое.
  int get deliveredToday =>
      todayRoutes.fold<int>(0, (sum, r) => sum + r.completedCount);

  /// Сколько точек предстоит объехать сегодня.
  int get stopsToday =>
      todayRoutes.fold<int>(0, (sum, r) => sum + r.totalCustomers);

  MyRoutesState copyWith({
    MyRoutesStatus? status,
    List<RouteListItem>? routes,
    RouteFilter? filter,
  }) {
    return MyRoutesState(
      status: status ?? this.status,
      routes: routes ?? this.routes,
      filter: filter ?? this.filter,
    );
  }

  @override
  List<Object?> get props => [status, routes, filter];
}

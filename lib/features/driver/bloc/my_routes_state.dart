part of 'my_routes_bloc.dart';

enum MyRoutesStatus { initial, loading, ready, error }

class MyRoutesState extends Equatable {
  const MyRoutesState({
    required this.date,
    this.status = MyRoutesStatus.initial,
    this.routes = const [],
    this.filter = RouteFilter.all,
  });

  /// Выбранный в ленте день.
  ///
  /// В отличие от админского экрана день не уходит в запрос: `/driver/routes`
  /// плюс достроенная история отдают все маршруты водителя разом, и отбор
  /// идёт здесь же. Переключение дня поэтому не ходит в сеть и работает
  /// там, где связи нет.
  final DateTime date;

  final MyRoutesStatus status;

  /// Все маршруты водителя — за выбранный день отбирает [dayRoutes].
  final List<RouteListItem> routes;

  final RouteFilter filter;

  /// Маршруты выбранного дня.
  ///
  /// Сравниваются календарные дни — в `date` маршрута времени нет, и
  /// приводить к полуночи нечего.
  List<RouteListItem> get dayRoutes => routes
      .where((r) =>
          r.date.year == date.year &&
          r.date.month == date.month &&
          r.date.day == date.day)
      .toList();

  /// Список за выбранный день с учётом активного фильтра.
  List<RouteListItem> get visible {
    final wanted = filter.status;
    final day = dayRoutes;
    if (wanted == null) return day;
    return day.where((r) => r.status == wanted).toList();
  }

  /// Показатели над списком (ТЗ, раздел 5).
  ///
  /// Считаются за выбранный день, а не за всё время: под ними лежит список
  /// этого же дня, и накопительная цифра рядом с ним читалась бы как ошибка.
  int get routesCount => dayRoutes.length;

  /// Сколько точек предстоит объехать за день.
  int get stopsCount =>
      dayRoutes.fold<int>(0, (sum, r) => sum + r.totalCustomers);

  /// Сколько из них уже закрыто.
  int get deliveredCount =>
      dayRoutes.fold<int>(0, (sum, r) => sum + r.completedCount);

  MyRoutesState copyWith({
    DateTime? date,
    MyRoutesStatus? status,
    List<RouteListItem>? routes,
    RouteFilter? filter,
  }) {
    return MyRoutesState(
      date: date ?? this.date,
      status: status ?? this.status,
      routes: routes ?? this.routes,
      filter: filter ?? this.filter,
    );
  }

  @override
  List<Object?> get props => [date, status, routes, filter];
}

import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/route_models.dart';
import 'seed_data.dart';

/// Общее in-memory состояние демо-режима.
///
/// Один и тот же экземпляр разделяют `MockCrmRepository` и
/// `MockDriverRepository`: завершённая водителем доставка должна быть видна
/// в админских списках, иначе демо разъезжается.
class MockStore {
  MockStore();

  final List<Driver> drivers = SeedData.drivers();
  final List<Customer> customers = SeedData.customers();
  final List<RouteDetail> routes = SeedData.routes();

  int _seq = 0;

  String nextId(String prefix) => '${prefix}_${++_seq}';

  /// Счётчики (`completedCount`, `totalCustomers`) не принимаются параметрами
  /// намеренно: их всегда выводим из списка точек, как это делает сервер.
  RouteDetail copyRoute(
    RouteDetail r, {
    RouteStatus? status,
    List<RouteStop>? stops,
    DateTime? date,
    String? driverId,
    String? driverFullName,
  }) {
    final newStops = stops ?? r.stops;
    return RouteDetail(
      id: r.id,
      date: date ?? r.date,
      status: status ?? r.status,
      completedCount: newStops.where((s) => s.isCompleted).length,
      totalCustomers: newStops.length,
      driverId: driverId ?? r.driverId,
      driverFullName: driverFullName ?? r.driverFullName,
      stops: newStops,
    );
  }

  void replaceRoute(String id, RouteDetail Function(RouteDetail) update) {
    final i = routes.indexWhere((r) => r.id == id);
    if (i != -1) routes[i] = update(routes[i]);
  }

  /// Находит остановку по id и заменяет её, пересчитывая статус маршрута.
  void updateStop(String stopId, RouteStop Function(RouteStop) update) {
    for (var i = 0; i < routes.length; i++) {
      final route = routes[i];
      final si = route.stops.indexWhere((s) => s.id == stopId);
      if (si == -1) continue;
      final stops = route.stops.toList();
      stops[si] = update(stops[si]);
      final allDone = stops.every((s) => s.isCompleted);
      routes[i] = copyRoute(
        route,
        stops: stops,
        status: allDone ? RouteStatus.completed : RouteStatus.inProgress,
      );
      return;
    }
  }
}

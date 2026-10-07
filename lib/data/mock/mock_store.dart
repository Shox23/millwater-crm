import '../../core/utils/cancel_reason.dart' as cancel_reason;
import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/route_expense.dart';
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

  /// Удалённые водители. Удаление на сервере мягкое — снимает `is_active`, —
  /// и в демо водитель так же уходит сюда, откуда его можно вернуть.
  final List<Driver> inactiveDrivers = [];
  final List<Customer> customers = SeedData.customers();
  final List<RouteDetail> routes = SeedData.routes();

  /// Расходы водителей по маршрутам. Пусты в начале демо: расход заводит сам
  /// водитель по дороге, придумывать их за него незачем.
  final List<RouteExpense> expenses = [];

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

  /// Заказы демо-режима.
  ///
  /// Выводятся из точек маршрутов, а не хранятся отдельным списком: на
  /// сервере это одна и та же таблица (`route_customers` переименовали в
  /// `orders`). Держи мок две независимые копии — закрытая водителем доставка
  /// оказалась бы видна в маршруте и не видна в списке заказов, а именно это
  /// расхождение демо и должно исключать.
  ///
  /// Цель у всех заказов одна: внутри маршрута сервер `purpose` не отдаёт,
  /// и придумывать её здесь значило бы показывать в демо то, чего в API нет.
  List<Order> orders({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? customerId,
    String? driverId,
    String? routeId,
    DeliveryStatus? status,
    OrderPurpose? purpose,
    PaymentMethod? paymentMethod,
    String? search,
  }) {
    final result = <Order>[];
    var number = 0;

    for (final route in routes) {
      for (final stop in route.stops) {
        number++;
        result.add(Order(
          id: stop.id,
          number: number,
          sequence: stop.sequence,
          status: stop.status,
          purpose: OrderPurpose.delivery19l,
          paymentMethod: stop.paymentMethod,
          deliveredCapsules: stop.deliveredCapsules,
          returnedCapsules: stop.returnedCapsules,
          returnedFullCapsules: stop.returnedFullCapsules,
          damagedCapsules: stop.damagedCapsules,
          capsuleBalanceAfter: stop.capsuleBalanceAfter,
          customPrice: stop.customPrice,
          bottleSellCount: stop.bottleSellCount,
          orderAmount: stop.paymentAmount,
          completedAt: stop.completedAt,
          cancelReason: stop.cancelReason,
          cancelledAt: stop.cancelledAt,
          comment: stop.comment,
          createdAt: route.date,
          customerId: stop.customerId,
          customerName: stop.customerName,
          customerPhone: stop.customerPhone,
          customerAddress: stop.customerAddress,
          routeId: route.id,
          routeDate: route.date,
          driverId: route.driverId,
          driverFullName: route.driverFullName,
        ));
      }
    }

    // Локальная копия: параметр метода внутри замыкания не повышается до
    // ненулевого типа, и без неё пришлось бы ставить `!` на каждое обращение.
    final query = search?.trim().toLowerCase() ?? '';

    bool matches(Order o) {
      final date = o.routeDate ?? o.createdAt;
      if (dateFrom != null && date.isBefore(dateFrom)) return false;
      if (dateTo != null && date.isAfter(dateTo)) return false;
      if (customerId != null && o.customerId != customerId) return false;
      if (driverId != null && o.driverId != driverId) return false;
      if (routeId != null && o.routeId != routeId) return false;
      if (status != null && o.status != status) return false;
      if (purpose != null && o.purpose != purpose) return false;
      if (paymentMethod != null && o.paymentMethod != paymentMethod) {
        return false;
      }
      if (query.isNotEmpty) {
        final fields = [o.customerName, o.customerPhone, o.customerAddress];
        if (!fields.any((f) => f.toLowerCase().contains(query))) return false;
      }
      return true;
    }

    // Новые сверху — как отдаёт сервер и как их ждёт список.
    return result.where(matches).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Переносит точку в другой маршрут.
  ///
  /// Повторяет поведение сервера: точка встаёт в конец очереди целевого
  /// маршрута, а опустевший маршрут-источник отменяется — иначе в списке
  /// остался бы маршрут на ноль точек, который водителю нечего везти.
  void moveStop({required String stopId, required String targetRouteId}) {
    for (var i = 0; i < routes.length; i++) {
      final source = routes[i];
      final si = source.stops.indexWhere((s) => s.id == stopId);
      if (si == -1) continue;
      if (source.id == targetRouteId) return;

      final stop = source.stops[si];
      final left = source.stops.toList()..removeAt(si);
      routes[i] = copyRoute(
        source,
        stops: left,
        status: left.isEmpty ? RouteStatus.cancelled : null,
      );

      replaceRoute(
        targetRouteId,
        (target) => copyRoute(target, stops: [...target.stops, stop]),
      );
      return;
    }
  }

  /// Находит остановку по id и заменяет её, пересчитывая статус маршрута.
  void updateStop(String stopId, RouteStop Function(RouteStop) update) {
    for (var i = 0; i < routes.length; i++) {
      final route = routes[i];
      final si = route.stops.indexWhere((s) => s.id == stopId);
      if (si == -1) continue;
      final stops = route.stops.toList();
      stops[si] = update(stops[si]);
      // Первое действие по точке выводит маршрут в рейс. Обратно — нет:
      // сервер с 2026-09-19 не закрывает маршрут по последней доставке,
      // только явной командой, см. [completeRoute]. Иначе мок показывал бы
      // «Завершён» там, где боевой сервер держит «В пути».
      routes[i] = copyRoute(
        route,
        stops: stops,
        status: route.status == RouteStatus.created
            ? RouteStatus.inProgress
            : route.status,
      );
      return;
    }
  }

  /// Причина, которую сервер ставит точкам, отменённым при закрытии
  /// маршрута, — его текст, как есть.
  static const routeCompletionCancelReason = cancel_reason.routeCompletionCancelReason;

  /// Завершает маршрут — как это сделает сервер по
  /// `POST /driver/routes/{id}/complete`.
  ///
  /// Незакрытые точки отменяются с [routeCompletionCancelReason], маршрут
  /// становится `completed`. Завершить можно только `in_progress`: у
  /// остальных сервер отвечает 409 `ORDER_ALREADY_COMPLETED` (код у него
  /// общий с заказом).
  void completeRoute(String routeId) {
    final i = routes.indexWhere((r) => r.id == routeId);
    if (i == -1) throw StateError('ROUTE_NOT_FOUND');
    final route = routes[i];
    if (!route.status.canComplete) throw StateError('ORDER_ALREADY_COMPLETED');
    final now = DateTime.now();
    final stops = [
      for (final s in route.stops)
        s.status.isOpen
            ? s.copyWith(
                status: DeliveryStatus.cancelled,
                cancelReason: routeCompletionCancelReason,
                cancelledAt: now,
              )
            : s,
    ];
    routes[i] = copyRoute(route, stops: stops, status: RouteStatus.completed);
  }

  /// Отменяет точку с причиной — как это сделает сервер по
  /// `POST /{admin,driver}/orders/{id}/cancel`.
  ///
  /// Закрытую точку отменить нельзя (409 `ORDER_ALREADY_COMPLETED`): доставка
  /// состоялась, деньги приняты, и отмена стёрла бы уже случившееся.
  void cancelStop(String stopId, {String? reason}) {
    final stop = routes.expand((r) => r.stops).where((s) => s.id == stopId).firstOrNull;
    if (stop == null) return;
    if (!stop.status.isOpen) throw StateError('ORDER_ALREADY_COMPLETED');
    final trimmed = reason?.trim();
    updateStop(
      stopId,
      (s) => s.copyWith(
        status: DeliveryStatus.cancelled,
        cancelReason: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        cancelledAt: DateTime.now(),
      ),
    );
  }
}

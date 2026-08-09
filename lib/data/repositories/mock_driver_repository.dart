import '../mock/mock_store.dart';
import '../models/enums.dart';
import '../models/route_models.dart';
import 'driver_repository.dart';

/// In-memory реализация водительской части (демо-режим и тесты).
class MockDriverRepository implements DriverRepository {
  MockDriverRepository({MockStore? store, this.driverId = 'd1'})
      : _store = store ?? MockStore();

  final MockStore _store;

  /// Чьи маршруты отдаём: у водителя в приложении он всегда один.
  final String driverId;

  /// Ключи Idempotency-Key уже принятых завершений — повтор не проводит
  /// доставку второй раз, как и на сервере.
  final Set<String> seenIdempotencyKeys = {};

  /// Последний отправленный остаток капсул — для проверок в тестах.
  int? lastBottleBalance;

  Future<void> _tick() =>
      Future<void>.delayed(const Duration(milliseconds: 150));

  /// Водительские эндпоинты не возвращают полей водителя — маршрут и так «свой».
  RouteListItem _toListItem(RouteDetail r) => RouteListItem(
        id: r.id,
        date: r.date,
        status: r.status,
        completedCount: r.stops.where((s) => s.isCompleted).length,
        totalCustomers: r.stops.length,
      );

  @override
  Future<List<RouteListItem>> getMyRoutes() async {
    await _tick();
    return _store.routes
        .where((r) => r.driverId == driverId)
        .map(_toListItem)
        .toList();
  }

  @override
  Future<RouteDetail?> getMyRoute(String id) async {
    await _tick();
    return _store.routes
        .where((r) => r.id == id && r.driverId == driverId)
        .firstOrNull;
  }

  @override
  Future<void> updateDeliveryStatus({
    required String stopId,
    required DeliveryStatus status,
  }) async {
    await _tick();
    _store.updateStop(
      stopId,
      (s) => RouteStop(
        id: s.id,
        customerId: s.customerId,
        customerName: s.customerName,
        customerAddress: s.customerAddress,
        customerPhone: s.customerPhone,
        status: status,
        customerLatitude: s.customerLatitude,
        customerLongitude: s.customerLongitude,
        deliveredCapsules: s.deliveredCapsules,
        paymentAmount: s.paymentAmount,
        paymentPhoto: s.paymentPhoto,
        completedAt: s.completedAt,
      ),
    );
  }

  @override
  Future<void> completeDelivery({
    required String stopId,
    required int capsules,
    required int amount,
    required int bottleBalance,
    String? photoPath,
    String? idempotencyKey,
    double? latitude,
    double? longitude,
  }) async {
    await _tick();
    lastBottleBalance = bottleBalance;
    if (idempotencyKey != null && !seenIdempotencyKeys.add(idempotencyKey)) {
      return;
    }
    _store.updateStop(
      stopId,
      (s) => RouteStop(
        id: s.id,
        customerId: s.customerId,
        customerName: s.customerName,
        customerAddress: s.customerAddress,
        customerPhone: s.customerPhone,
        status: DeliveryStatus.paid,
        // Как это сделает сервер: присланные координаты запоминаются у точки,
        // а если водитель их не снял — прежние не затираются.
        customerLatitude: latitude ?? s.customerLatitude,
        customerLongitude: longitude ?? s.customerLongitude,
        deliveredCapsules: capsules,
        paymentAmount: amount,
        paymentPhoto: photoPath,
        completedAt: DateTime.now(),
      ),
    );
  }
}

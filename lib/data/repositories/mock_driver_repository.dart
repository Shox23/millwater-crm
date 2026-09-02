import '../mock/mock_store.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/result_page.dart';
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

  /// Последний отправленный способ оплаты — для проверок в тестах.
  PaymentMethod? lastMethod;

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

  /// Свои заказы: те же, что у сервера, — за всё время и только свои.
  ///
  /// Размер страницы маленький, как и у админского мока: с сидом из полудюжины
  /// маршрутов боевая сотня никогда не дала бы второй страницы, и догрузку
  /// было бы нечем проверить.
  static const int pageSize = 4;

  @override
  Future<ResultPage<Order>> getMyOrders({
    int page = 1,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? customerId,
    String? routeId,
    DeliveryStatus? status,
    OrderPurpose? purpose,
    PaymentMethod? paymentMethod,
    String? search,
  }) async {
    await _tick();
    final all = _store.orders(
      dateFrom: dateFrom,
      dateTo: dateTo,
      customerId: customerId,
      // Водитель видит только свои заказы, и подставляет это не он, а
      // источник данных — как сервер подставляет водителя из токена.
      driverId: driverId,
      routeId: routeId,
      status: status,
      purpose: purpose,
      paymentMethod: paymentMethod,
      search: search,
    );

    final start = (page - 1) * pageSize;
    if (start >= all.length) {
      return ResultPage(
        items: const [],
        page: page,
        hasMore: false,
        total: all.length,
      );
    }
    final end = start + pageSize;
    return ResultPage(
      items: all.sublist(start, end > all.length ? all.length : end),
      page: page,
      hasMore: end < all.length,
      total: all.length,
    );
  }

  @override
  Future<Order?> getMyOrder(String id) async {
    await _tick();
    return _store
        .orders(driverId: driverId)
        .where((o) => o.id == id)
        .firstOrNull;
  }

  @override
  Future<void> updateDeliveryStatus({
    required String stopId,
    required DeliveryStatus status,
  }) async {
    await _tick();
    _store.updateStop(stopId, (s) => s.copyWith(status: status));
  }

  @override
  Future<void> completeDelivery({
    required String stopId,
    required int capsules,
    required int amount,
    required int bottleBalance,
    required PaymentMethod method,
    String? photoPath,
    String? idempotencyKey,
    double? latitude,
    double? longitude,
  }) async {
    await _tick();
    lastBottleBalance = bottleBalance;
    lastMethod = method;
    if (idempotencyKey != null && !seenIdempotencyKeys.add(idempotencyKey)) {
      return;
    }
    _store.updateStop(
      stopId,
      (s) => s.copyWith(
        status: DeliveryStatus.delivered,
        // Как это сделает сервер: присланные координаты запоминаются у точки,
        // а если водитель их не снял — прежние не затираются.
        customerLatitude: latitude,
        customerLongitude: longitude,
        deliveredCapsules: capsules,
        paymentAmount: amount,
        paymentMethod: method,
        paymentPhoto: photoPath,
        completedAt: DateTime.now(),
      ),
    );
  }
}

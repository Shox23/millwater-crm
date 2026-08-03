import '../mock/seed_data.dart';
import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/reports_summary.dart';
import '../models/route_models.dart';
import 'crm_repository.dart';

/// In-memory реализация репозитория (демо-режим без сервера).
/// Данные живут в рамках сессии; отчёт считается из текущего состояния.
class MockCrmRepository implements CrmRepository {
  final List<Driver> _drivers = SeedData.drivers();
  final List<Customer> _customers = SeedData.customers();
  final List<RouteDetail> _routes = SeedData.routes();
  int _seq = 0;

  String _nextId(String prefix) => '${prefix}_${++_seq}';

  /// Небольшая задержка, чтобы UI показывал состояние загрузки.
  Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 150));

  bool _matches(String query, List<String> fields) {
    final q = query.toLowerCase().trim();
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  @override
  Future<int> getCapsulePrice() async {
    await _tick();
    return SeedData.capsulePrice;
  }

  // ---- Водители ----
  @override
  Future<List<Driver>> getDrivers({String? search}) async {
    await _tick();
    if (search == null || search.trim().isEmpty) {
      return List.unmodifiable(_drivers);
    }
    return _drivers
        .where((d) => _matches(search, [d.fullName, d.phone, d.email]))
        .toList();
  }

  @override
  Future<Driver?> getDriver(String id) async {
    await _tick();
    return _drivers.where((d) => d.id == id).firstOrNull;
  }

  @override
  Future<Driver> addDriver({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    await _tick();
    final driver = Driver(
      id: _nextId('d'),
      fullName: fullName,
      phone: phone,
      email: email,
      createdAt: DateTime.now(),
    );
    _drivers.add(driver);
    return driver;
  }

  @override
  Future<Driver> updateDriver(Driver driver) async {
    await _tick();
    final i = _drivers.indexWhere((d) => d.id == driver.id);
    if (i != -1) _drivers[i] = driver;
    return driver;
  }

  @override
  Future<void> deleteDriver(String id) async {
    await _tick();
    _drivers.removeWhere((d) => d.id == id);
  }

  // ---- Заказчики ----
  @override
  Future<List<Customer>> getCustomers({String? search, bool? hasDebt}) async {
    await _tick();
    var result = _customers.toList();
    if (search != null && search.trim().isNotEmpty) {
      result = result
          .where((c) => _matches(search, [c.name, c.phone, c.address]))
          .toList();
    }
    if (hasDebt == true) {
      result = result.where((c) => c.debt > 0).toList();
    }
    return result;
  }

  @override
  Future<Customer?> getCustomer(String id) async {
    await _tick();
    return _customers.where((c) => c.id == id).firstOrNull;
  }

  @override
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    required String address,
    String? comment,
  }) async {
    await _tick();
    final customer = Customer(
      id: _nextId('c'),
      name: name,
      phone: phone,
      address: address,
      comment: comment,
      createdAt: DateTime.now(),
    );
    _customers.add(customer);
    return customer;
  }

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    await _tick();
    final i = _customers.indexWhere((c) => c.id == customer.id);
    if (i != -1) _customers[i] = customer;
    return customer;
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await _tick();
    _customers.removeWhere((c) => c.id == id);
  }

  // ---- Маршруты ----
  RouteListItem _toListItem(RouteDetail r) => RouteListItem(
        id: r.id,
        date: r.date,
        status: r.status,
        completedCount: r.stops.where((s) => s.isCompleted).length,
        totalCustomers: r.stops.length,
        driverId: r.driverId,
        driverFullName: r.driverFullName,
      );

  @override
  Future<List<RouteListItem>> getRoutes({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? driverId,
    RouteStatus? status,
  }) async {
    await _tick();
    var result = _routes.toList();
    if (driverId != null) {
      result = result.where((r) => r.driverId == driverId).toList();
    }
    if (status != null) {
      result = result.where((r) => r.status == status).toList();
    }
    return result.map(_toListItem).toList();
  }

  @override
  Future<RouteDetail?> getRoute(String id) async {
    await _tick();
    return _routes.where((r) => r.id == id).firstOrNull;
  }

  @override
  Future<RouteDetail> createRoute({
    required String driverId,
    required DateTime date,
    required List<String> customerIds,
  }) async {
    await _tick();
    final driver = _drivers.where((d) => d.id == driverId).firstOrNull;
    final stops = <RouteStop>[];
    for (final cid in customerIds) {
      final c = _customers.where((x) => x.id == cid).firstOrNull;
      if (c == null) continue;
      stops.add(RouteStop(
        id: _nextId('s'),
        customerId: c.id,
        customerName: c.name,
        customerAddress: c.address,
        customerPhone: c.phone,
        status: DeliveryStatus.pending,
      ));
    }
    final route = RouteDetail(
      id: _nextId('r'),
      date: date,
      status: RouteStatus.created,
      driverId: driverId,
      driverFullName: driver?.fullName ?? '',
      completedCount: 0,
      totalCustomers: stops.length,
      stops: stops,
    );
    _routes.add(route);
    return route;
  }

  @override
  Future<void> deleteRoute(String id) async {
    await _tick();
    _routes.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> cancelRoute(String id) async {
    await _tick();
    _replaceRoute(id, (r) => _copyRoute(r, status: RouteStatus.cancelled));
  }

  @override
  Future<void> completeDelivery({
    required String stopId,
    required int capsules,
    required int amount,
  }) async {
    await _tick();
    _updateStop(
      stopId,
      (s) => RouteStop(
        id: s.id,
        customerId: s.customerId,
        customerName: s.customerName,
        customerAddress: s.customerAddress,
        customerPhone: s.customerPhone,
        status: DeliveryStatus.paid,
        deliveredCapsules: capsules,
        paymentAmount: amount,
        completedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> updateDeliveryStatus({
    required String stopId,
    required DeliveryStatus status,
  }) async {
    await _tick();
    _updateStop(
      stopId,
      (s) => RouteStop(
        id: s.id,
        customerId: s.customerId,
        customerName: s.customerName,
        customerAddress: s.customerAddress,
        customerPhone: s.customerPhone,
        status: status,
        deliveredCapsules: s.deliveredCapsules,
        paymentAmount: s.paymentAmount,
        paymentPhoto: s.paymentPhoto,
        completedAt: s.completedAt,
      ),
    );
  }

  RouteDetail _copyRoute(
    RouteDetail r, {
    RouteStatus? status,
    List<RouteStop>? stops,
  }) {
    final newStops = stops ?? r.stops;
    return RouteDetail(
      id: r.id,
      date: r.date,
      status: status ?? r.status,
      completedCount: newStops.where((s) => s.isCompleted).length,
      totalCustomers: newStops.length,
      driverId: r.driverId,
      driverFullName: r.driverFullName,
      stops: newStops,
    );
  }

  void _replaceRoute(String id, RouteDetail Function(RouteDetail) update) {
    final i = _routes.indexWhere((r) => r.id == id);
    if (i != -1) _routes[i] = update(_routes[i]);
  }

  /// Находит остановку по id и заменяет её, пересчитывая статус маршрута.
  void _updateStop(String stopId, RouteStop Function(RouteStop) update) {
    for (var i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      final si = route.stops.indexWhere((s) => s.id == stopId);
      if (si == -1) continue;
      final stops = route.stops.toList();
      stops[si] = update(stops[si]);
      final allDone = stops.every((s) => s.isCompleted);
      _routes[i] = _copyRoute(
        route,
        stops: stops,
        status: allDone ? RouteStatus.completed : RouteStatus.inProgress,
      );
      return;
    }
  }

  // ---- Отчёты ----
  @override
  Future<ReportsSummary> getReportsSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    await _tick();
    final stops = _routes.expand((r) => r.stops).toList();
    final done = stops.where((s) => s.isCompleted).length;
    final revenue =
        stops.fold<int>(0, (sum, s) => sum + (s.paymentAmount ?? 0));

    final debtors = _customers.where((c) => c.debt > 0).toList()
      ..sort((a, b) => b.debt.compareTo(a.debt));
    final debtTotal = debtors.fold<int>(0, (sum, c) => sum + c.debt);
    final capsulesActive =
        _customers.fold<int>(0, (sum, c) => sum + c.capsuleBalance);
    final weeklyTotal =
        SeedData.weekly.fold<int>(0, (sum, b) => sum + b.value);

    return ReportsSummary(
      revenueToday: revenue,
      revenueChangePct: 12,
      deliveriesDone: done,
      deliveriesTotal: stops.length,
      debtTotal: debtTotal,
      debtorsCount: debtors.length,
      capsulesActive: capsulesActive,
      capsulesTotal: SeedData.capsulesTotal,
      weekly: SeedData.weekly,
      weeklyTotal: weeklyTotal,
      weeklyChangePct: 18,
      debtors: debtors
          .map((c) => Debtor(
                name: c.name,
                district: c.comment ?? c.address,
                amount: c.debt,
              ))
          .toList(),
    );
  }
}

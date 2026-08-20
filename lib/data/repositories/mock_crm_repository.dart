import 'dart:typed_data';

import '../../core/utils/day.dart';
import '../mock/mock_store.dart';
import '../mock/seed_data.dart';
import '../models/result_page.dart';
import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/price_settings.dart';
import '../models/report_export.dart';
import '../models/reports_summary.dart';
import '../models/route_models.dart';
import 'crm_repository.dart';

/// In-memory реализация админской части (демо-режим без сервера).
///
/// Состояние живёт в [MockStore] — тот же экземпляр можно отдать
/// `MockDriverRepository`, чтобы завершённые водителем доставки были видны
/// в админских списках.
class MockCrmRepository implements CrmRepository {
  MockCrmRepository({MockStore? store}) : store = store ?? MockStore();

  final MockStore store;

  List<Driver> get _drivers => store.drivers;
  List<Customer> get _customers => store.customers;
  List<RouteDetail> get _routes => store.routes;

  /// Ответы уже принятых create-запросов: ключ идемпотентности → созданное.
  ///
  /// Повторять поведение сервера здесь важно, иначе тесты форм не отличат
  /// защищённый повтор от дубля.
  final Map<String, Object> _accepted = {};

  /// Ранее созданный объект для этого ключа, если запрос уже принимали.
  T? _replay<T extends Object>(String? key) =>
      key == null ? null : _accepted[key] as T?;

  /// Запоминает результат — повтор с тем же ключом вернёт его же.
  T _remember<T extends Object>(String? key, T created) {
    if (key != null) _accepted[key] = created;
    return created;
  }

  /// Небольшая задержка, чтобы UI показывал состояние загрузки.
  Future<void> _tick() =>
      Future<void>.delayed(const Duration(milliseconds: 150));

  bool _matches(String query, List<String> fields) {
    final q = query.toLowerCase().trim();
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  // ---- Цены ----
  /// Заведённые прайсы, новые первыми. Как на сервере, новая цена не правит
  /// старую запись, а добавляется: действующей считается первая в списке.
  final List<PriceSettings> _prices = [
    PriceSettings(
      id: 'price-seed-2',
      capsulePrice: SeedData.capsulePrice,
      depositPrice: SeedData.depositPrice,
      createdAt: SeedData.today,
    ),
    PriceSettings(
      id: 'price-seed-1',
      capsulePrice: 18000,
      depositPrice: 45000,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<PriceSettings> getPrices() async {
    await _tick();
    return _prices.first;
  }

  @override
  Future<List<PriceSettings>> getPriceHistory() async {
    await _tick();
    return List.unmodifiable(_prices);
  }

  @override
  Future<PriceSettings> setPrices({
    required int capsulePrice,
    required int depositPrice,
    String? idempotencyKey,
  }) async {
    await _tick();
    final replayed = _replay<PriceSettings>(idempotencyKey);
    if (replayed != null) return replayed;

    final created = PriceSettings(
      id: store.nextId('price'),
      capsulePrice: capsulePrice,
      depositPrice: depositPrice,
      createdAt: DateTime.now(),
    );
    _prices.insert(0, created);
    return _remember(idempotencyKey, created);
  }

  /// Размер страницы. Меньше боевой сотни намеренно: с сидом из шести
  /// заказчиков сотня никогда не дала бы второй страницы, и догрузку было бы
  /// нечем проверить.
  static const int pageSize = 4;

  /// Отрезает страницу [page] (считая с единицы) от полной выдачи.
  ResultPage<T> _slice<T>(List<T> all, int page) {
    final start = (page - 1) * pageSize;
    if (start >= all.length) {
      return ResultPage(items: const [], page: page, hasMore: false, total: all.length);
    }
    final end = start + pageSize;
    return ResultPage(
      items: all.sublist(start, end > all.length ? all.length : end),
      page: page,
      hasMore: end < all.length,
      total: all.length,
    );
  }

  // ---- Водители ----
  @override
  Future<List<Driver>> getDrivers({String? search}) async {
    await _tick();
    if (search == null || search.trim().isEmpty) {
      return List.unmodifiable(_drivers);
    }
    return _drivers
        .where((d) => _matches(search, [d.fullName, d.phone]))
        .toList();
  }

  @override
  Future<ResultPage<Driver>> getDriversPage({int page = 1, String? search}) async {
    final all = await getDrivers(search: search);
    return _slice(all, page);
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
    required String password,
    String? idempotencyKey,
  }) async {
    await _tick();
    final replayed = _replay<Driver>(idempotencyKey);
    if (replayed != null) return replayed;

    final driver = Driver(
      id: store.nextId('d'),
      fullName: fullName,
      phone: phone,
      createdAt: DateTime.now(),
    );
    _drivers.add(driver);
    return _remember(idempotencyKey, driver);
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
  Future<ResultPage<Customer>> getCustomersPage({
    int page = 1,
    String? search,
    bool? hasDebt,
  }) async {
    final all = await getCustomers(search: search, hasDebt: hasDebt);
    return _slice(all, page);
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
    bool hasCooler = false,
    String? idempotencyKey,
  }) async {
    await _tick();
    final replayed = _replay<Customer>(idempotencyKey);
    if (replayed != null) return replayed;

    final customer = Customer(
      id: store.nextId('c'),
      name: name,
      phone: phone,
      address: address,
      comment: comment,
      hasCooler: hasCooler,
      createdAt: DateTime.now(),
    );
    _customers.add(customer);
    return _remember(idempotencyKey, customer);
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
    var result = _inRange(_routes, dateFrom, dateTo);
    if (driverId != null) {
      result = result.where((r) => r.driverId == driverId).toList();
    }
    if (status != null) {
      result = result.where((r) => r.status == status).toList();
    }
    return result.map(_toListItem).toList();
  }

  /// Маршруты, попавшие в диапазон дат; границы включаются.
  ///
  /// Сравниваем по календарному дню: у маршрута дата хранится с полуночью, а
  /// граница может прийти с любым временем, и `isBefore` тогда врёт.
  List<RouteDetail> _inRange(
    List<RouteDetail> routes,
    DateTime? from,
    DateTime? to,
  ) {
    if (from == null && to == null) return routes.toList();
    return routes.where((r) {
      final day = dayOnly(r.date);
      if (from != null && day.isBefore(dayOnly(from))) return false;
      if (to != null && day.isAfter(dayOnly(to))) return false;
      return true;
    }).toList();
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
    String? idempotencyKey,
  }) async {
    await _tick();
    final replayed = _replay<RouteDetail>(idempotencyKey);
    if (replayed != null) return replayed;

    final driver = _drivers.where((d) => d.id == driverId).firstOrNull;
    final stops = <RouteStop>[];
    for (final cid in customerIds) {
      final c = _customers.where((x) => x.id == cid).firstOrNull;
      if (c == null) continue;
      stops.add(RouteStop(
        id: store.nextId('s'),
        customerId: c.id,
        customerName: c.name,
        customerAddress: c.address,
        customerPhone: c.phone,
        status: DeliveryStatus.pending,
      ));
    }
    final route = RouteDetail(
      id: store.nextId('r'),
      date: date,
      status: RouteStatus.created,
      driverId: driverId,
      driverFullName: driver?.fullName ?? '',
      completedCount: 0,
      totalCustomers: stops.length,
      stops: stops,
    );
    _routes.add(route);
    return _remember(idempotencyKey, route);
  }

  @override
  Future<void> deleteRoute(String id) async {
    await _tick();
    _routes.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> cancelRoute(String id) async {
    await _tick();
    store.replaceRoute(
      id,
      (r) => store.copyRoute(r, status: RouteStatus.cancelled),
    );
  }

  @override
  Future<RouteDetail> updateRouteDate({
    required String routeId,
    required DateTime date,
  }) async {
    await _tick();
    store.replaceRoute(routeId, (r) => store.copyRoute(r, date: date));
    return _routes.firstWhere((r) => r.id == routeId);
  }

  @override
  Future<void> assignDriver({
    required String routeId,
    required String driverId,
  }) async {
    await _tick();
    final driver = _drivers.where((d) => d.id == driverId).firstOrNull;
    store.replaceRoute(
      routeId,
      (r) => store.copyRoute(
        r,
        driverId: driverId,
        driverFullName: driver?.fullName ?? '',
      ),
    );
  }

  @override
  Future<void> addRouteCustomer({
    required String routeId,
    required String customerId,
  }) async {
    await _tick();
    final customer = _customers.where((c) => c.id == customerId).firstOrNull;
    if (customer == null) return;

    store.replaceRoute(routeId, (r) {
      // Тот же заказчик дважды в одном маршруте — это одна точка, а не две.
      if (r.stops.any((s) => s.customerId == customerId)) return r;
      return store.copyRoute(r, stops: [
        ...r.stops,
        RouteStop(
          id: store.nextId('s'),
          customerId: customer.id,
          customerName: customer.name,
          customerAddress: customer.address,
          customerPhone: customer.phone,
          status: DeliveryStatus.pending,
        ),
      ]);
    });
  }

  @override
  Future<void> removeRouteCustomer({
    required String routeId,
    required String customerId,
  }) async {
    await _tick();
    store.replaceRoute(
      routeId,
      (r) => store.copyRoute(
        r,
        stops: r.stops.where((s) => s.customerId != customerId).toList(),
      ),
    );
  }

  // ---- Отчёты ----
  @override
  Future<SummaryReport> getSummaryReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    await _tick();
    // Сводка считается по тем же маршрутам, что вернул бы getRoutes за этот
    // период: экран маршрутов показывает её рядом со списком, и разойтись они
    // не должны.
    final routes = _inRange(_routes, dateFrom, dateTo);
    final stops = routes.expand((r) => r.stops).toList();
    final done = stops.where((s) => s.isCompleted).length;

    return SummaryReport(
      routesCount: routes.length,
      completedDeliveries: done,
      // Сервер считает «всего» как completed + failed, поэтому незавершённые
      // остановки сида попадают сюда — иначе итог разошёлся бы с боевым.
      failedDeliveries: stops.length - done,
      totalRevenue: stops.fold<int>(0, (sum, s) => sum + (s.paymentAmount ?? 0)),
      totalDebt: _customers.fold<int>(0, (sum, c) => sum + c.debt),
    );
  }

  @override
  Future<ReportExport> exportSummaryReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) async {
    await _tick();
    // Настоящий xlsx здесь не нужен: экран проверяет, что файл дошёл и ушёл
    // в «Поделиться», а не его содержимое. Первые байты — сигнатура ZIP,
    // с которой начинается любой xlsx.
    return ReportExport(
      bytes: Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, ...List.filled(60, 0)]),
      filename: 'millwater-report.xlsx',
    );
  }
}

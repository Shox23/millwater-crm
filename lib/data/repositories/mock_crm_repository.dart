import 'dart:typed_data';

import '../../core/utils/day.dart';
import '../mock/mock_store.dart';
import '../mock/seed_data.dart';
import '../models/result_page.dart';
import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/price_settings.dart';
import '../models/report_export.dart';
import '../models/report_rows.dart';
import '../models/route_expense.dart';
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
      damagedBottleFine: SeedData.damagedBottleFine,
      createdAt: SeedData.today,
    ),
    PriceSettings(
      id: 'price-seed-1',
      capsulePrice: 18000,
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
    required int damagedBottleFine,
    String? idempotencyKey,
  }) async {
    await _tick();
    final replayed = _replay<PriceSettings>(idempotencyKey);
    if (replayed != null) return replayed;

    final created = PriceSettings(
      id: store.nextId('price'),
      capsulePrice: capsulePrice,
      damagedBottleFine: damagedBottleFine,
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
  Future<List<Customer>> getCustomers({
    String? search,
    bool? hasDebt,
    bool? isActive,
  }) async {
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
    // Отбора по кулеру здесь нет намеренно: сервер его больше не делает, и
    // мок, который умеет больше живого API, спрятал бы клиентский фильтр от
    // тестов — а он теперь единственный.
    if (isActive != null) {
      result = result.where((c) => c.isActive == isActive).toList();
    }
    return result;
  }

  @override
  Future<ResultPage<Customer>> getCustomersPage({
    int page = 1,
    String? search,
    bool? hasDebt,
    bool? isActive,
  }) async {
    final all = await getCustomers(
      search: search,
      hasDebt: hasDebt,
      isActive: isActive,
    );
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
    int coolerCount = 0,
    int capsuleBalance = 0,
    int debt = 0,
    int prepayment = 0,
    int? customWaterPrice,
    DateTime? lastOrderDate,
    String? idempotencyKey,
  }) async {
    await _tick();
    final replayed = _replay<Customer>(idempotencyKey);
    if (replayed != null) return replayed;

    // Тот же отказ, что и у сервера (422 BOTH_BALANCES_SET): форма не должна
    // уметь собрать состояние, которое живой API отвергнет, а мок — это
    // единственное место, где такую форму проверяют тесты.
    if (debt > 0 && prepayment > 0) {
      throw StateError('BOTH_BALANCES_SET');
    }

    final customer = Customer(
      id: store.nextId('c'),
      name: name,
      phone: phone,
      address: address,
      comment: comment,
      coolerCount: coolerCount,
      capsuleBalance: capsuleBalance,
      debt: debt,
      prepayment: prepayment,
      customWaterPrice: customWaterPrice,
      lastOrderDate: lastOrderDate,
      createdAt: DateTime.now(),
    );
    _customers.add(customer);
    return _remember(idempotencyKey, customer);
  }

  @override
  Future<Customer> updateCustomer(
    Customer customer, {
    bool balanceChanged = false,
    bool capsulesChanged = false,
    bool lastOrderDateChanged = false,
  }) async {
    await _tick();
    if (balanceChanged && customer.debt > 0 && customer.prepayment > 0) {
      throw StateError('BOTH_BALANCES_SET');
    }
    final i = _customers.indexWhere((c) => c.id == customer.id);
    if (i == -1) return customer;

    // Баланс без явного признака не трогаем — ровно как сервер, который
    // непереданные поля оставляет прежними. Иначе форма правки названия
    // откатывала бы оплату, принятую водителем, пока она была открыта.
    //
    // С остатком капсул то же самое: его ведёт водитель на завершении
    // доставки, и без признака правки он остаётся тем, что лежит в сторе.
    final stored = _customers[i];
    var saved = balanceChanged
        ? customer
        : customer.copyWith(debt: stored.debt, prepayment: stored.prepayment);
    if (!capsulesChanged) {
      saved = saved.copyWith(capsuleBalance: stored.capsuleBalance);
    }
    // И дата последнего заказа: её ставит закрытие доставки. `null` сервер
    // из PATCH выбрасывает — стереть дату нельзя, только заменить.
    if (!lastOrderDateChanged || customer.lastOrderDate == null) {
      saved = saved.copyWith(lastOrderDate: stored.lastOrderDate);
    }
    _customers[i] = saved;
    return saved;
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
    required DateTime date,
    required List<RouteOrderInput> orders,
    String? driverId,
    OrderPurpose purpose = OrderPurpose.delivery19l,
    String? idempotencyKey,
  }) async {
    await _tick();
    final replayed = _replay<RouteDetail>(idempotencyKey);
    if (replayed != null) return replayed;

    final driver = _drivers.where((d) => d.id == driverId).firstOrNull;
    final stops = <RouteStop>[];
    for (final (i, order) in orders.indexed) {
      final c = _customers.where((x) => x.id == order.customerId).firstOrNull;
      if (c == null) continue;
      stops.add(RouteStop(
        id: store.nextId('s'),
        customerId: c.id,
        customerName: c.name,
        customerAddress: c.address,
        customerPhone: c.phone,
        status: DeliveryStatus.pending,
        // Своя цель точки перебивает цель маршрута — как на сервере.
        purpose: order.purpose ?? purpose,
        sequence: order.sequence ?? i + 1,
        customerCoolerCount: c.coolerCount,
        bottleSellCount: order.bottleSellCount,
        customPrice: order.customPrice,
      ));
    }
    final route = RouteDetail(
      id: store.nextId('r'),
      date: date,
      status: RouteStatus.created,
      // Водителя может не быть: маршрут-заготовку собирают заранее. Пустая
      // строка вместо `null` рисовалась бы как безымянный водитель.
      driverId: driverId,
      driverFullName: driver?.fullName,
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
    OrderPurpose purpose = OrderPurpose.delivery19l,
    int? bottleSellCount,
    int? customPrice,
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
          purpose: purpose,
          bottleSellCount: bottleSellCount,
          customPrice: customPrice,
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

  // ---- Заказы ----
  @override
  Future<ResultPage<Order>> getOrdersPage({
    int page = 1,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? customerId,
    String? driverId,
    String? routeId,
    DeliveryStatus? status,
    OrderPurpose? purpose,
    PaymentMethod? paymentMethod,
    String? search,
  }) async {
    await _tick();
    final all = store.orders(
      dateFrom: dateFrom,
      dateTo: dateTo,
      customerId: customerId,
      driverId: driverId,
      routeId: routeId,
      status: status,
      purpose: purpose,
      paymentMethod: paymentMethod,
      search: search,
    );
    return _slice(all, page);
  }

  @override
  Future<Order?> getOrder(String id) async {
    await _tick();
    return store.orders().where((o) => o.id == id).firstOrNull;
  }

  @override
  Future<void> moveOrderToRoute({
    required String orderId,
    required String targetRouteId,
  }) async {
    await _tick();
    store.moveStop(stopId: orderId, targetRouteId: targetRouteId);
  }

  @override
  Future<void> moveOrderToDate({
    required String orderId,
    required DateTime date,
    String? driverId,
  }) async {
    await _tick();
    // Как сервер: маршрут этой даты у этого водителя, а не найдя — новый и
    // без водителя.
    final existing = _routes
        .where((r) =>
            r.date == dayOnly(date) &&
            (driverId == null ? r.driverId == null : r.driverId == driverId))
        .firstOrNull;

    final target = existing ??
        store.copyRoute(
          RouteDetail(
            id: store.nextId('r'),
            date: dayOnly(date),
            status: RouteStatus.created,
            completedCount: 0,
            totalCustomers: 0,
            stops: const [],
          ),
        );
    if (existing == null) _routes.add(target);

    store.moveStop(stopId: orderId, targetRouteId: target.id);
  }

  @override
  Future<void> updateOrderPayment({
    required String orderId,
    required int amount,
    required PaymentMethod method,
    String? note,
    String? photoPath,
  }) async {
    await _tick();
    final stop = _routes
        .expand((r) => r.stops)
        .where((s) => s.id == orderId)
        .firstOrNull;
    if (stop == null) return;
    // Как сервер: у незакрытого заказа править нечего (409).
    if (!stop.isCompleted) throw StateError('ORDER_NOT_COMPLETED');

    store.updateStop(
      orderId,
      (s) => s.copyWith(paymentAmount: amount, paymentMethod: method),
    );
  }

  @override
  Future<void> cancelOrder({required String orderId, String? reason}) async {
    await _tick();
    store.cancelStop(orderId, reason: reason);
  }

  // ---- Расходы ----
  @override
  Future<List<RouteExpense>> getRouteExpenses(String routeId) async {
    await _tick();
    return store.expenses.where((e) => e.routeId == routeId).toList();
  }

  @override
  Future<ResultPage<RouteExpense>> getExpensesPage({
    int page = 1,
    String? driverId,
    DateTime? dateFrom,
    DateTime? dateTo,
    ExpenseCategory? category,
  }) async {
    await _tick();
    var result = store.expenses.toList();
    if (driverId != null) {
      result = result.where((e) => e.driverId == driverId).toList();
    }
    if (category != null) {
      result = result.where((e) => e.category == category).toList();
    }
    // Границы включаются и сравниваются по календарному дню — как в
    // остальных списках мока.
    if (dateFrom != null) {
      final from = dayOnly(dateFrom);
      result = result
          .where((e) => !dayOnly(e.createdAt).isBefore(from))
          .toList();
    }
    if (dateTo != null) {
      final to = dayOnly(dateTo);
      result =
          result.where((e) => !dayOnly(e.createdAt).isAfter(to)).toList();
    }
    return ResultPage(
      items: result,
      page: page,
      hasMore: false,
      total: result.length,
    );
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    await _tick();
    store.expenses.removeWhere((e) => e.id == expenseId);
  }

  // ---- Отчёты ----
  //
  // Считаются по тем же маршрутам, что вернул бы getRoutes за этот период:
  // экран маршрутов показывает выручку рядом со списком, и разойтись они
  // не должны.

  @override
  Future<List<GeneralReportRow>> getGeneralReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) async {
    await _tick();
    return [
      for (final route in _reportRoutes(dateFrom, dateTo, driverId))
        for (final stop in route.stops)
          if (stop.isCompleted)
            GeneralReportRow(
              date: route.date,
              driverName: route.driverFullName ?? '',
              customer: stop.customerName,
              deliveredCapsules: stop.deliveredCapsules ?? 0,
              returnedCapsules: stop.returnedCapsules ?? 0,
              damagedCapsules: stop.damagedCapsules ?? 0,
              coolerCount: stop.customerCoolerCount,
              orderAmount: stop.paymentAmount ?? 0,
            ),
    ];
  }

  @override
  Future<List<CustomerReportRow>> getCustomersReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) async {
    await _tick();
    final routes = _reportRoutes(dateFrom, dateTo, driverId);
    // Сервер отдаёт строку на заказчика, а не на доставку, — сводим сами.
    final byCustomer = <String, List<RouteStop>>{};
    for (final route in routes) {
      for (final stop in route.stops) {
        if (!stop.isCompleted) continue;
        byCustomer.putIfAbsent(stop.customerId, () => []).add(stop);
      }
    }

    return [
      for (final entry in byCustomer.entries)
        if (_customers.where((c) => c.id == entry.key).firstOrNull
            case final Customer c)
          CustomerReportRow(
            customerId: c.id,
            name: c.name,
            address: c.address,
            phone: c.phone,
            capsulesPurchased: entry.value
                .fold<int>(0, (sum, s) => sum + (s.deliveredCapsules ?? 0)),
            bulkLiters: entry.value.fold<int>(
                0,
                (sum, s) =>
                    sum + (s.bulk5lCount ?? 0) * 5 + (s.bulk10lCount ?? 0) * 10),
            damagedCapsules: entry.value
                .fold<int>(0, (sum, s) => sum + (s.damagedCapsules ?? 0)),
            // Остаток, кулеры и баланс — на момент выгрузки, как на сервере.
            capsuleBalance: c.capsuleBalance,
            coolerCount: c.coolerCount,
            debt: c.debt,
            prepayment: c.prepayment,
            total: entry.value
                .fold<int>(0, (sum, s) => sum + (s.paymentAmount ?? 0)),
          ),
    ];
  }

  @override
  Future<List<DriverReportRow>> getDriversReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) async {
    await _tick();
    return [
      for (final route in _reportRoutes(dateFrom, dateTo, driverId))
        for (final stop in route.stops)
          if (stop.isCompleted)
            DriverReportRow(
              routeId: route.id,
              date: route.date,
              driverId: route.driverId ?? '',
              driverName: route.driverFullName ?? '',
              customer: stop.customerName,
              purpose: stop.purpose,
              deliveredCapsules: stop.deliveredCapsules ?? 0,
              returnedCapsules: stop.returnedCapsules ?? 0,
              capsuleBalanceAfter: stop.capsuleBalanceAfter,
              paymentMethod: stop.paymentMethod,
              orderAmount: stop.paymentAmount ?? 0,
              bulkLiters:
                  (stop.bulk5lCount ?? 0) * 5 + (stop.bulk10lCount ?? 0) * 10,
              bulkAmount: (stop.bulk5lCount ?? 0) * (stop.bulk5lPrice ?? 0) +
                  (stop.bulk10lCount ?? 0) * (stop.bulk10lPrice ?? 0),
              // Расход маршрута повторяется в каждой его строке — как у сервера.
              routeExpenses: store.expenses
                  .where((e) => e.routeId == route.id)
                  .fold<int>(0, (sum, e) => sum + e.amount),
            ),
    ];
  }

  /// Маршруты периода, при необходимости суженные до одного водителя.
  List<RouteDetail> _reportRoutes(
    DateTime dateFrom,
    DateTime dateTo,
    String? driverId,
  ) =>
      _inRange(_routes, dateFrom, dateTo)
          .where((r) => driverId == null || r.driverId == driverId)
          .toList();

  @override
  Future<ReportExport> exportGeneralReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) =>
      _export('general');

  @override
  Future<ReportExport> exportCustomersReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) =>
      _export('customers');

  @override
  Future<ReportExport> exportDriversReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) =>
      _export('drivers');

  /// Настоящий xlsx здесь не нужен: экран проверяет, что файл дошёл и ушёл
  /// в «Поделиться», а не его содержимое. Первые байты — сигнатура ZIP,
  /// с которой начинается любой xlsx.
  Future<ReportExport> _export(String kind) async {
    await _tick();
    return ReportExport(
      bytes: Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, ...List.filled(60, 0)]),
      filename: 'millwater-$kind.xlsx',
    );
  }
}

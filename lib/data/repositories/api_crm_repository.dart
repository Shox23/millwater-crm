import 'package:dio/dio.dart';

import '../../core/utils/money_parser.dart';
import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/reports_summary.dart';
import '../models/route_models.dart';
import '../network/api_envelope.dart';
import 'crm_repository.dart';

/// Реализация репозитория поверх Water CRM API (Dio).
///
/// Контракт сверен с боевым сервером: успешные ответы приходят «голыми»
/// (без конверта), списки — с пагинацией `{items,total,page,page_size,pages}`,
/// денежные значения — строками вида "20000.00".
class ApiCrmRepository implements CrmRepository {
  ApiCrmRepository(this._dio);

  final Dio _dio;

  /// Размер страницы для списочных запросов.
  static const int _pageSize = 100;

  /// Дата в формате `YYYY-MM-DD`, как ожидают query-параметры API.
  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Разбирает страницу списка в модели.
  List<T> _items<T>(Response res, T Function(Map<String, dynamic>) fromJson) {
    final data = unwrapData(res.data);
    final list = data is Map<String, dynamic> ? data['items'] as List : data as List;
    return list
        .map((e) => fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<int> getCapsulePrice() async {
    final res = await _dio.get('/admin/prices/current');
    return MoneyParser.toSum(asMap(res.data)['water_price']);
  }

  // ---- Водители ----
  @override
  Future<List<Driver>> getDrivers({String? search}) async {
    final res = await _dio.get('/admin/drivers', queryParameters: {
      'page': 1,
      'page_size': _pageSize,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
    return _items(res, Driver.fromJson);
  }

  @override
  Future<Driver?> getDriver(String id) async {
    final res = await _dio.get('/admin/drivers/$id');
    return Driver.fromJson(asMap(res.data));
  }

  @override
  Future<Driver> addDriver({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/admin/drivers', data: {
      'full_name': fullName,
      'phone': phone,
      // Почта необязательна: пустую строку сервер не принимает — не шлём ключ.
      if (email.trim().isNotEmpty) 'email': email.trim(),
      'password': password,
    });
    return Driver.fromJson(asMap(res.data));
  }

  @override
  Future<Driver> updateDriver(Driver driver) async {
    final res = await _dio.patch(
      '/admin/drivers/${driver.id}',
      data: driver.toUpdateJson(),
    );
    return Driver.fromJson(asMap(res.data));
  }

  @override
  Future<void> deleteDriver(String id) => _dio.delete('/admin/drivers/$id');

  // ---- Заказчики ----
  @override
  Future<List<Customer>> getCustomers({String? search, bool? hasDebt}) async {
    final res = await _dio.get('/admin/customers', queryParameters: {
      'page': 1,
      'page_size': _pageSize,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'has_debt': ?hasDebt,
    });
    return _items(res, Customer.fromJson);
  }

  @override
  Future<Customer?> getCustomer(String id) async {
    final res = await _dio.get('/admin/customers/$id');
    return Customer.fromJson(asMap(res.data));
  }

  @override
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    required String address,
    String? comment,
  }) async {
    final res = await _dio.post('/admin/customers', data: {
      'full_name': name,
      'phone': phone,
      'address': address,
      'comment': ?comment,
    });
    return Customer.fromJson(asMap(res.data));
  }

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    final res = await _dio.patch(
      '/admin/customers/${customer.id}',
      data: customer.toUpdateJson(),
    );
    return Customer.fromJson(asMap(res.data));
  }

  @override
  Future<void> deleteCustomer(String id) => _dio.delete('/admin/customers/$id');

  // ---- Маршруты ----
  @override
  Future<List<RouteListItem>> getRoutes({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? driverId,
    RouteStatus? status,
  }) async {
    final res = await _dio.get('/admin/routes', queryParameters: {
      'page': 1,
      'page_size': _pageSize,
      if (dateFrom != null) 'date_from': _formatDate(dateFrom),
      if (dateTo != null) 'date_to': _formatDate(dateTo),
      'driver_id': ?driverId,
      'status': ?status?.wire,
    });
    return _items(res, RouteListItem.fromJson);
  }

  @override
  Future<RouteDetail?> getRoute(String id) async {
    final res = await _dio.get('/admin/routes/$id');
    return RouteDetail.fromJson(asMap(res.data));
  }

  @override
  Future<RouteDetail> createRoute({
    required String driverId,
    required DateTime date,
    required List<String> customerIds,
  }) async {
    final res = await _dio.post('/admin/routes', data: {
      'driver_id': driverId,
      'date': _formatDate(date),
      'customer_ids': customerIds,
    });
    return RouteDetail.fromJson(asMap(res.data));
  }

  @override
  Future<void> deleteRoute(String id) => _dio.delete('/admin/routes/$id');

  @override
  Future<void> cancelRoute(String id) => _dio.post('/admin/routes/$id/cancel');

  @override
  Future<void> completeDelivery({
    required String stopId,
    required int capsules,
    required int amount,
  }) async {
    await _dio.post(
      '/driver/routes/customers/$stopId/complete',
      data: {
        'data': {
          'delivered_bottles': capsules,
          'payment_amount': MoneyParser.toApi(amount),
        },
      },
    );
  }

  @override
  Future<void> updateDeliveryStatus({
    required String stopId,
    required DeliveryStatus status,
  }) async {
    await _dio.patch(
      '/driver/routes/customers/$stopId/status',
      data: {'status': status.toJson()},
    );
  }

  // ---- Отчёты ----
  @override
  Future<ReportsSummary> getReportsSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final res = await _dio.get('/admin/reports/summary', queryParameters: {
      if (dateFrom != null) 'date_from': _formatDate(dateFrom),
      if (dateTo != null) 'date_to': _formatDate(dateTo),
    });
    final s = asMap(res.data);

    // Списка должников и остатка капсул в summary нет — считаем по заказчикам.
    final customers = await getCustomers();
    final debtors = customers.where((c) => c.debt > 0).toList()
      ..sort((a, b) => b.debt.compareTo(a.debt));

    final completed = s['completed_deliveries_count'] as int? ?? 0;
    final failed = s['failed_deliveries_count'] as int? ?? 0;
    final capsulesActive =
        customers.fold<int>(0, (sum, c) => sum + c.capsuleBalance);

    return ReportsSummary(
      revenueToday: MoneyParser.toSum(s['total_revenue']),
      revenueChangePct: 0,
      deliveriesDone: completed,
      deliveriesTotal: completed + failed,
      debtTotal: MoneyParser.toSum(s['total_debt']),
      debtorsCount: debtors.length,
      capsulesActive: capsulesActive,
      capsulesTotal: capsulesActive,
      // Недельного разреза в API нет — график скрывается пустым списком.
      weekly: const [],
      weeklyTotal: 0,
      weeklyChangePct: 0,
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

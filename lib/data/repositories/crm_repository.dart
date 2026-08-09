import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/price_settings.dart';
import '../models/reports_summary.dart';
import '../models/route_models.dart';

/// Контракт админской части API (`/admin/*`).
///
/// Водительские операции живут в отдельном `DriverRepository` — админ их
/// вызвать не может, сервер отвечает на них 403.
/// Реализации: [MockCrmRepository] и ApiCrmRepository.
abstract class CrmRepository {
  // ---- Цены ----
  /// Действующий прайс (`GET /admin/prices/current`).
  Future<PriceSettings> getPrices();

  /// Все заведённые прайсы, новые первыми (`GET /admin/prices/history`).
  Future<List<PriceSettings>> getPriceHistory();

  /// Заводит новый прайс (`POST /admin/prices`) и возвращает его.
  ///
  /// Обе цены отправляются вместе: `CreatePriceSettings` требует и ту,
  /// и другую — «поменять только капсулу» на стороне API не бывает.
  Future<PriceSettings> setPrices({
    required int capsulePrice,
    required int depositPrice,
    String? idempotencyKey,
  });

  // ---- Водители ----
  Future<List<Driver>> getDrivers({String? search});
  Future<Driver?> getDriver(String id);

  /// [idempotencyKey] один и тот же при повторной отправке формы: связь
  /// рвётся, и повтор не должен завести второго водителя.
  Future<Driver> addDriver({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    String? idempotencyKey,
  });
  Future<Driver> updateDriver(Driver driver);
  Future<void> deleteDriver(String id);

  // ---- Заказчики ----
  Future<List<Customer>> getCustomers({String? search, bool? hasDebt});
  Future<Customer?> getCustomer(String id);
  /// [idempotencyKey] — см. [addDriver].
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    required String address,
    String? comment,
    String? idempotencyKey,
  });
  Future<Customer> updateCustomer(Customer customer);
  Future<void> deleteCustomer(String id);

  // ---- Маршруты ----
  Future<List<RouteListItem>> getRoutes({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? driverId,
    RouteStatus? status,
  });
  Future<RouteDetail?> getRoute(String id);
  /// [idempotencyKey] — см. [addDriver].
  Future<RouteDetail> createRoute({
    required String driverId,
    required DateTime date,
    required List<String> customerIds,
    String? idempotencyKey,
  });
  Future<void> deleteRoute(String id);
  Future<void> cancelRoute(String id);

  // ---- Отчёты ----
  Future<ReportsSummary> getReportsSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  });
}

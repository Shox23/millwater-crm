import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/reports_summary.dart';
import '../models/route_models.dart';

/// Контракт доступа к данным. Реализации: [MockCrmRepository] и ApiCrmRepository.
abstract class CrmRepository {
  /// Объём капсулы, литров (в API не хранится, используется только для подписи).
  static const int capsuleVolumeLiters = 19;

  /// Текущая цена одной капсулы, сум (GET /admin/prices/current).
  Future<int> getCapsulePrice();

  // ---- Водители ----
  Future<List<Driver>> getDrivers({String? search});
  Future<Driver?> getDriver(String id);
  Future<Driver> addDriver({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  });
  Future<Driver> updateDriver(Driver driver);
  Future<void> deleteDriver(String id);

  // ---- Заказчики ----
  Future<List<Customer>> getCustomers({String? search, bool? hasDebt});
  Future<Customer?> getCustomer(String id);
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    required String address,
    String? comment,
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
  Future<RouteDetail> createRoute({
    required String driverId,
    required DateTime date,
    required List<String> customerIds,
  });
  Future<void> deleteRoute(String id);
  Future<void> cancelRoute(String id);

  /// Завершение доставки на остановке (driver-эндпоинт).
  Future<void> completeDelivery({
    required String stopId,
    required int capsules,
    required int amount,
  });

  /// Смена статуса доставки на остановке (driver-эндпоинт).
  Future<void> updateDeliveryStatus({
    required String stopId,
    required DeliveryStatus status,
  });

  // ---- Отчёты ----
  Future<ReportsSummary> getReportsSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  });
}

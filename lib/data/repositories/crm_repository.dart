import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/price_settings.dart';
import '../models/result_page.dart';
import '../models/report_export.dart';
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
  /// Все водители сразу.
  ///
  /// Обходит страницы внутри себя. Нужен там, где выбирают из полного
  /// списка, — в форме создания маршрута. Для списка, который листают,
  /// есть [getDriversPage].
  Future<List<Driver>> getDrivers({String? search});

  /// Одна страница списка водителей, считая с первой.
  Future<ResultPage<Driver>> getDriversPage({int page = 1, String? search});
  Future<Driver?> getDriver(String id);

  /// [idempotencyKey] один и тот же при повторной отправке формы: связь
  /// рвётся, и повтор не должен завести второго водителя.
  /// Заводит водителя вместе с паролем (`POST /admin/drivers`).
  ///
  /// Пароля «по умолчанию» на сервере нет, и сбросить его админ не может —
  /// эндпоинта для этого в API нет. Стартовый пароль генерирует форма
  /// ([DriverPassword.generate]) — свой на каждую учётку, — показывает его
  /// админу до отправки, а водитель меняет его сам после первого входа.
  Future<Driver> addDriver({
    required String fullName,
    required String phone,
    required String password,
    String? idempotencyKey,
  });
  Future<Driver> updateDriver(Driver driver);
  Future<void> deleteDriver(String id);

  // ---- Заказчики ----
  /// Все заказчики сразу.
  ///
  /// Обходит страницы внутри себя. Нужен форме создания маршрута и экрану
  /// отчётов: должников и остаток капсул сводка не отдаёт, и они выводятся
  /// из справочника (см. `ReportsSummary.from`). Для списка, который
  /// листают, есть [getCustomersPage].
  Future<List<Customer>> getCustomers({String? search, bool? hasDebt});

  /// Одна страница списка заказчиков, считая с первой.
  Future<ResultPage<Customer>> getCustomersPage({
    int page = 1,
    String? search,
    bool? hasDebt,
  });
  Future<Customer?> getCustomer(String id);
  /// [idempotencyKey] — см. [addDriver].
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    required String address,
    String? comment,
    bool hasCooler = false,
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

  /// Переносит маршрут на другую дату (`PATCH /admin/routes/{id}`).
  ///
  /// Статус этим же эндпоинтом не меняем: отмена живёт в [cancelRoute], а
  /// остальные статусы сервер выставляет сам по ходу доставок.
  Future<RouteDetail> updateRouteDate({
    required String routeId,
    required DateTime date,
  });

  /// Переназначает водителя (`PATCH /admin/routes/{id}/driver/{driverId}`).
  ///
  /// Сервер отвечает 204 без тела, поэтому обновлённый маршрут нужно
  /// перечитать через [getRoute] — достраивать его в памяти значит однажды
  /// показать состояние, которого на сервере нет.
  Future<void> assignDriver({
    required String routeId,
    required String driverId,
  });

  /// Добавляет заказчика в маршрут
  /// (`POST /admin/routes/{id}/customers/{customerId}`).
  /// Ответ 204 — см. оговорку у [assignDriver].
  Future<void> addRouteCustomer({
    required String routeId,
    required String customerId,
  });

  /// Убирает заказчика из маршрута
  /// (`DELETE /admin/routes/{id}/customers/{customerId}`).
  /// Ответ 204 — см. оговорку у [assignDriver].
  Future<void> removeRouteCustomer({
    required String routeId,
    required String customerId,
  });

  // ---- Отчёты ----
  /// Сводка за период (`GET /admin/reports/summary`) — как её отдал сервер.
  ///
  /// Должников и остаток капсул сводка не содержит; числа для экрана
  /// собирает [ReportsSummary.from] из этого ответа и списка заказчиков.
  Future<SummaryReport> getSummaryReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  });

  /// Выгружает отчёт за период в Excel (`GET /admin/reports/export`).
  ///
  /// Границы обязательны — сервер без них отвечает 422. [driverId] сужает
  /// выгрузку до одного водителя.
  Future<ReportExport> exportSummaryReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  });
}

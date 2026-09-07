import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/price_settings.dart';
import '../models/result_page.dart';
import '../models/report_export.dart';
import '../models/report_rows.dart';
import '../models/route_expense.dart';
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
  /// Все три значения отправляются вместе, хотя сервер теперь принимает и
  /// подмножество: экран прайса показывает три поля сразу, и отправлять
  /// «только изменённое» значило бы гадать, что именно админ считал
  /// изменением. Непереданное сервер переносит из действующего прайса.
  Future<PriceSettings> setPrices({
    required int capsulePrice,
    required int depositPrice,
    required int damagedBottleFine,
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
  /// Фильтра по кулеру здесь нет намеренно: сервер его больше не принимает,
  /// и отбор считается на клиенте — см. [CustomerFilter.filtersCoolerLocally].
  Future<List<Customer>> getCustomers({
    String? search,
    bool? hasDebt,
    bool? isActive,
  });

  /// Одна страница списка заказчиков, считая с первой.
  Future<ResultPage<Customer>> getCustomersPage({
    int page = 1,
    String? search,
    bool? hasDebt,
    bool? isActive,
  });
  Future<Customer?> getCustomer(String id);

  /// Заводит заказчика (`POST /admin/customers`).
  ///
  /// [debt] и [prepayment] — стартовый баланс. Оба ненулевыми быть не могут:
  /// сервер отвечает 422 `BOTH_BALANCES_SET`, и форма не должна давать
  /// собрать такое состояние.
  /// [customWaterPrice] — индивидуальная цена капсулы; `null` — по общему
  /// прайсу.
  /// [idempotencyKey] — см. [addDriver].
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    required String address,
    String? comment,
    int coolerCount = 0,
    int debt = 0,
    int prepayment = 0,
    int? customWaterPrice,
    String? idempotencyKey,
  });

  /// Сохраняет изменения заказчика (`PATCH /admin/customers/{id}`).
  ///
  /// [balanceChanged] — админ правил долг или предоплату вручную, и их надо
  /// отправить. По умолчанию баланс не отправляется: см. `toUpdateJson`.
  Future<Customer> updateCustomer(
    Customer customer, {
    bool balanceChanged = false,
  });
  Future<void> deleteCustomer(String id);

  // ---- Маршруты ----
  Future<List<RouteListItem>> getRoutes({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? driverId,
    RouteStatus? status,
  });
  Future<RouteDetail?> getRoute(String id);

  /// Создаёт маршрут (`POST /admin/routes`).
  ///
  /// [purpose] — цель маршрута и цель по умолчанию для его точек; своя цель
  /// точки живёт в [RouteOrderInput.purpose].
  /// [driverId] необязателен: маршрут-заготовку собирают заранее, а водителя
  /// назначают потом. Без водителя сервер оставляет маршрут в `created` —
  /// «в работе» маршрут, который некому везти, быть не может.
  /// Тело запроса — `customer_orders: [{customer_id, order_purpose}]`; прежний
  /// плоский `customer_ids` сервер молча игнорирует, и маршрут при этом
  /// создавался пустым.
  /// [idempotencyKey] — см. [addDriver].
  Future<RouteDetail> createRoute({
    required DateTime date,
    required List<RouteOrderInput> orders,
    String? driverId,
    OrderPurpose purpose = OrderPurpose.delivery19l,
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
  ///
  /// Заказчик теперь передаётся ещё и телом запроса вместе с целью заказа:
  /// сервер читает его оттуда, а не из пути. Ответ 204 — см. оговорку у
  /// [assignDriver].
  Future<void> addRouteCustomer({
    required String routeId,
    required String customerId,
    OrderPurpose purpose = OrderPurpose.delivery19l,
  });

  /// Убирает заказчика из маршрута
  /// (`DELETE /admin/routes/{id}/customers/{customerId}`).
  /// Ответ 204 — см. оговорку у [assignDriver].
  Future<void> removeRouteCustomer({
    required String routeId,
    required String customerId,
  });

  // ---- Заказы ----
  /// Страница списка заказов за всё время (`GET /admin/orders`).
  ///
  /// Отбор делает сервер целиком: период, заказчик, водитель, маршрут,
  /// статус, цель, способ оплаты и поиск по имени, телефону и адресу.
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
  });

  /// Один заказ (`GET /admin/orders/{id}`).
  Future<Order?> getOrder(String id);

  /// Переносит заказ в существующий маршрут
  /// (`POST /admin/orders/{id}/move`, вариант `target_route_id`).
  ///
  /// Только пока заказ не закрыт: у закрытого сервер отвечает 409
  /// `ORDER_ALREADY_COMPLETED`. Опустевший маршрут-источник сервер отменяет
  /// сам. Ответ 204 без тела — заказ надо перечитать.
  Future<void> moveOrderToRoute({
    required String orderId,
    required String targetRouteId,
  });

  /// Переносит заказ на дату (`POST /admin/orders/{id}/move`, вариант
  /// `order_date`).
  ///
  /// Сервер ищет маршрут этой даты у этого водителя, а не найдя — **создаёт
  /// маршрут без водителя**. Поэтому вызывающий обязан предупредить: заказ
  /// уедет в маршрут, который некому везти.
  /// Дата в прошлом отвергается (422 `DATE_IN_PAST`).
  Future<void> moveOrderToDate({
    required String orderId,
    required DateTime date,
    String? driverId,
  });

  /// Правит оплату закрытого заказа
  /// (`PATCH /admin/orders/{id}/payment`, multipart).
  ///
  /// [amount] — итоговая сумма заказа целиком, а не доплата: разницу с уже
  /// принятыми деньгами сервер посчитает сам и запишет отдельной строкой в
  /// историю платежей, а остаток уйдёт заказчику в долг или предоплату.
  /// Только у закрытого заказа: иначе 409 `ORDER_NOT_COMPLETED`.
  Future<void> updateOrderPayment({
    required String orderId,
    required int amount,
    required PaymentMethod method,
    String? note,
    String? photoPath,
  });

  // ---- Расходы ----
  /// Расходы по маршруту (`GET /admin/routes/{id}/expenses`).
  ///
  /// Нужны рядом с кассой: остаток наличных у водителя — это собранное минус
  /// расходы, и без списка непонятно, куда делись деньги.
  Future<List<RouteExpense>> getRouteExpenses(String routeId);

  /// Страница расходов за период (`GET /admin/expenses`).
  Future<ResultPage<RouteExpense>> getExpensesPage({
    int page,
    String? driverId,
    DateTime? dateFrom,
    DateTime? dateTo,
    ExpenseCategory? category,
  });

  /// Удаляет расход (`DELETE /admin/expenses/{id}`).
  Future<void> deleteExpense(String expenseId);

  // ---- Отчёты ----
  //
  // Сервер заменил `GET /admin/reports/summary` и `/export` тремя разрезами:
  // общий, по заказчикам и по водителям. У всех троих один набор параметров
  // и по паре путей — данные и выгрузка в xlsx. Готовой сводки больше нет:
  // числа для экрана считает [ReportsSummary.from] из строк общего отчёта и
  // отчёта по заказчикам.

  /// Общий отчёт (`GET /admin/reports/general`) — строка на доставку.
  ///
  /// Границы обязательны: сервер без них отвечает 422. [driverId] сужает
  /// отчёт до одного водителя.
  Future<List<GeneralReportRow>> getGeneralReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  });

  /// Отчёт по заказчикам (`GET /admin/reports/customers`) — строка на заказчика.
  ///
  /// Им же закрывается давняя проблема экрана отчётов: должников и остаток
  /// капсул больше не нужно выводить из полного справочника заказчиков —
  /// долг, предоплата и остаток приходят готовыми.
  Future<List<CustomerReportRow>> getCustomersReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  });

  /// Отчёт по водителям (`GET /admin/reports/drivers`) — строка на заказ.
  ///
  /// Сводку по водителю собирает экран: сервер отдаёт разрез по заказам, а не
  /// по людям. Внимание к `routeExpenses` — оно про маршрут целиком, см.
  /// [DriverReportRow.routeExpenses].
  Future<List<DriverReportRow>> getDriversReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  });

  /// Выгрузки тех же трёх отчётов в xlsx (`.../export`).
  Future<ReportExport> exportGeneralReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  });

  Future<ReportExport> exportCustomersReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  });

  Future<ReportExport> exportDriversReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  });
}

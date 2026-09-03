import '../../core/product_config.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/result_page.dart';
import '../models/route_expense.dart';
import '../models/route_models.dart';

/// Контракт водительской части API (`/driver/*`).
///
/// Отделён от [CrmRepository] намеренно: водительское дерево виджетов не
/// получает админский репозиторий, поэтому «доступ по ролям» держится
/// архитектурой, а не аккуратностью вызовов.
abstract class DriverRepository {
  /// Маршруты текущего водителя (`GET /driver/routes`).
  Future<List<RouteListItem>> getMyRoutes();

  /// Один маршрут со списком точек (`GET /driver/routes/{id}`).
  Future<RouteDetail?> getMyRoute(String id);

  /// Страница своих заказов за всё время (`GET /driver/orders`).
  ///
  /// `driver_id` не параметр: сервер подставляет водителя из токена и чужой
  /// заказ не отдаст. Ради этого списка водитель наконец видит историю, а не
  /// только сегодняшний маршрут.
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
  });

  /// Один свой заказ (`GET /driver/orders/{id}`). Чужой — 403.
  Future<Order?> getMyOrder(String id);

  /// Смена статуса доставки на точке.
  Future<void> updateDeliveryStatus({
    required String stopId,
    required DeliveryStatus status,
  });

  /// Завершение доставки.
  ///
  /// [purpose] — цель заказа; от неё зависит, какие поля сервер вообще
  /// принимает: доставке нужны капсулы и остаток, вывозу — забранные кулеры
  /// и капсулы, опту — количество и **цена** пятилитровых и десятилитровых
  /// бутылей (цена договорная, её вводит водитель).
  /// [bottleBalance] — сколько капсул остаётся у заказчика после доставки.
  /// В OpenAPI поле помечено необязательным, но без него сервер отвечает 500,
  /// а полученным значением он **перезаписывает** остаток заказчика.
  /// [method] — способ оплаты; поле обязательное, без него сервер отвечает 422.
  /// [photoPath] — фото подтверждения. Осмысленно только при оплате картой
  /// ([PaymentMethod.needsPhoto]), у остальных способов подтверждать нечего.
  /// [idempotencyKey] один и тот же при повторной отправке: связь у водителя
  /// плохая, и повтор не должен провести доставку дважды.
  /// [latitude]/[longitude] — где стоял телефон в момент доставки; сервер
  /// сохраняет их у заказчика, чтобы следующий маршрут строился по точке,
  /// а не по геокодингу текстового адреса. Отправляются только вдвоём и
  /// только при включённом [ProductConfig.captureDeliveryCoordinates].
  Future<void> completeDelivery({
    required String stopId,
    required OrderPurpose purpose,
    required int amount,
    required PaymentMethod method,
    int capsules = 0,
    int returnedCapsules = 0,
    int damagedCapsules = 0,
    int? bottleBalance,
    int bulk5lCount = 0,
    int? bulk5lPrice,
    int bulk10lCount = 0,
    int? bulk10lPrice,
    int pickedCoolers = 0,
    int pickedBottles = 0,
    String? photoPath,
    String? idempotencyKey,
    double? latitude,
    double? longitude,
  });

  // ---- Расходы маршрута ----
  /// Расходы по маршруту (`GET /driver/routes/{id}/expenses`).
  Future<List<RouteExpense>> getRouteExpenses(String routeId);

  /// Заносит расход (`POST /driver/routes/{id}/expenses`, multipart).
  ///
  /// [idempotencyKey] обязателен по смыслу: связь у водителя рвётся, а
  /// повторная отправка — это второе списание из кассы. Сервер ключ пока
  /// **не соблюдает** (сохраняет его под шаблоном пути, а ищет по
  /// фактическому), поэтому вслепую повторять запрос нельзя даже с ключом.
  Future<RouteExpense> addExpense({
    required String routeId,
    required int amount,
    required ExpenseCategory category,
    String? comment,
    String? photoPath,
    String? idempotencyKey,
  });

  /// Удаляет свой расход (`DELETE /driver/expenses/{id}`).
  Future<void> deleteExpense(String expenseId);
}

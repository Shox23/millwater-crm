import '../../core/product_config.dart';
import '../models/enums.dart';
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

  /// Смена статуса доставки на точке.
  Future<void> updateDeliveryStatus({
    required String stopId,
    required DeliveryStatus status,
  });

  /// Завершение доставки.
  ///
  /// [bottleBalance] — сколько капсул остаётся у заказчика после доставки.
  /// В OpenAPI поле помечено необязательным, но без него сервер отвечает 500,
  /// а полученным значением он **перезаписывает** остаток заказчика.
  /// [photoPath] — файл фото оплаты, если водитель его приложил.
  /// [idempotencyKey] один и тот же при повторной отправке: связь у водителя
  /// плохая, и повтор не должен провести доставку дважды.
  /// [latitude]/[longitude] — где стоял телефон в момент доставки; сервер
  /// сохраняет их у заказчика, чтобы следующий маршрут строился по точке,
  /// а не по геокодингу текстового адреса. Отправляются только вдвоём и
  /// только при включённом [ProductConfig.captureDeliveryCoordinates].
  Future<void> completeDelivery({
    required String stopId,
    required int capsules,
    required int amount,
    required int bottleBalance,
    String? photoPath,
    String? idempotencyKey,
    double? latitude,
    double? longitude,
  });
}

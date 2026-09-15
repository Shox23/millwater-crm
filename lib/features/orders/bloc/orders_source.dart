import '../../../data/models/enums.dart';
import '../../../data/models/order.dart';
import '../../../data/models/result_page.dart';
import '../../../data/repositories/crm_repository.dart';
import '../../../data/repositories/driver_repository.dart';

/// Откуда экран заказов берёт страницы и куда шлёт отмену.
///
/// Узкий интерфейс на чтение и одно действие, потому что репозитории у ролей
/// разные и общего предка у них нет — и не должно быть: доступ по ролям
/// держится тем, что админского репозитория в дереве водителя физически нет
/// (см. `app.dart`). Блок один на обе роли, а какой источник ему достался —
/// решает экран, который его создаёт, там же, где нужный репозиторий и лежит.
///
/// Отмена здесь же, а не в карточке заказа: это единственное действие над
/// заказом, которое есть у обеих ролей, и ручки у них разные
/// (`/admin/orders/{id}/cancel` и `/driver/orders/{id}/cancel`).
abstract class OrdersSource {
  Future<ResultPage<Order>> load({
    required int page,
    DeliveryStatus? status,
    OrderPurpose? purpose,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
  });

  /// Отменяет заказ с необязательной причиной.
  Future<void> cancel({required String orderId, String? reason});
}

/// Все заказы компании (`GET /admin/orders`).
class AdminOrdersSource implements OrdersSource {
  const AdminOrdersSource(this._repository);

  final CrmRepository _repository;

  @override
  Future<ResultPage<Order>> load({
    required int page,
    DeliveryStatus? status,
    OrderPurpose? purpose,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) =>
      _repository.getOrdersPage(
        page: page,
        status: status,
        purpose: purpose,
        search: search,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

  @override
  Future<void> cancel({required String orderId, String? reason}) =>
      _repository.cancelOrder(orderId: orderId, reason: reason);
}

/// Свои заказы за всё время (`GET /driver/orders`).
///
/// Водителя сервер подставляет из токена — фильтра `driver_id` здесь нет и
/// быть не может: чужой заказ он всё равно не отдаст.
class DriverOrdersSource implements OrdersSource {
  const DriverOrdersSource(this._repository);

  final DriverRepository _repository;

  @override
  Future<ResultPage<Order>> load({
    required int page,
    DeliveryStatus? status,
    OrderPurpose? purpose,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) =>
      _repository.getMyOrders(
        page: page,
        status: status,
        purpose: purpose,
        search: search,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

  @override
  Future<void> cancel({required String orderId, String? reason}) =>
      _repository.cancelOrder(orderId: orderId, reason: reason);
}

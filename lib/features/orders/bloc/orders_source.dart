import '../../../data/models/enums.dart';
import '../../../data/models/order.dart';
import '../../../data/models/result_page.dart';
import '../../../data/repositories/crm_repository.dart';
import '../../../data/repositories/driver_repository.dart';

/// Откуда экран заказов берёт страницы.
///
/// Узкий интерфейс на одно чтение, потому что репозитории у ролей разные и
/// общего предка у них нет — и не должно быть: доступ по ролям держится тем,
/// что админского репозитория в дереве водителя физически нет (см. `app.dart`).
/// Блок один на обе роли, а какой источник ему достался — решает экран,
/// который его создаёт, там же, где нужный репозиторий и лежит.
abstract class OrdersSource {
  Future<ResultPage<Order>> load({
    required int page,
    DeliveryStatus? status,
    OrderPurpose? purpose,
    String? search,
  });
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
  }) =>
      _repository.getOrdersPage(
        page: page,
        status: status,
        purpose: purpose,
        search: search,
      );
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
  }) =>
      _repository.getMyOrders(
        page: page,
        status: status,
        purpose: purpose,
        search: search,
      );
}

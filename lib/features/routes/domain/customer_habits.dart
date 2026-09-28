import '../../../core/utils/day.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/crm_repository.dart';

/// Обычный объём заказа — сколько капсул этому заказчику везут обычно.
///
/// В API такого поля нет, и вывести его дешёвым способом не из чего:
/// `CustomerResponse` объёма не отдаёт, отчёт по заказчикам даёт капсулы за
/// период **без числа заказов** (среднее из него не получить), а общий отчёт
/// даёт строку на доставку, но заказчика в ней называет текстом
/// `customer_name_or_address` — без `id`, сопоставлять нечем.
///
/// TODO(api): убрать этот класс, когда сервер добавит заказчику
/// `usual_bottle_count` (мода или среднее по последним доставкам 19 л). Тогда
/// объём приедет вместе со списком заказчиков, и запрос на точку не
/// понадобится вовсе — а вместе с ним уйдёт и подмена «обычного» последним.
///
/// Пока берём количество из **последнего** заказа заказчика: это не «обычно»,
/// а «как в прошлый раз», но в подавляющем большинстве точек одно и то же
/// число, и оператору всё равно остаётся его проверить.
class CustomerHabits {
  CustomerHabits(this._repo);

  final CrmRepository _repo;

  /// Ответы по заказчикам: `null` — спрашивали, истории нет. Отсутствие
  /// ключа — ещё не спрашивали.
  final Map<String, int?> _known = {};

  /// Спрашивали ли уже про этого заказчика (в том числе безрезультатно).
  bool knows(String customerId) => _known.containsKey(customerId);

  /// Известный объём; `null` — не спрашивали или истории нет.
  int? cached(String customerId) => _known[customerId];

  /// Узнаёт объём одного заказчика — один запрос на точку, и только когда
  /// точку добавляют: список заказчиков открывается без запросов вообще.
  ///
  /// Окно запроса — день последнего заказа, а не «первая страница»:
  /// сортировка `/admin/orders` в схеме не описана, и у заказчика с историей
  /// больше сотни заказов первая страница могла бы оказаться самой старой.
  /// День известен из самого заказчика (`last_order_date`), так что ответ от
  /// сортировки не зависит.
  Future<int?> load(Customer customer) async {
    final id = customer.id;
    if (_known.containsKey(id)) return _known[id];

    final since = customer.lastOrderDate;
    // Ни одной доставки — спрашивать нечего, и повторно не спросим.
    if (since == null) {
      _known[id] = null;
      return null;
    }

    try {
      final page = await _repo.getOrdersPage(
        customerId: id,
        dateFrom: dayOnly(since),
        status: DeliveryStatus.delivered,
        purpose: OrderPurpose.delivery19l,
      );
      final qty = _lastQty(page.items);
      _known[id] = qty;
      return qty;
    } catch (_) {
      // Отказ не запоминаем: связь вернётся, и следующая точка спросит снова.
      // Точка при этом остаётся с количеством по умолчанию — форма не встаёт
      // из-за того, что не удалось подсмотреть историю.
      return null;
    }
  }

  /// Количество из самой свежей доставки списка.
  ///
  /// Сначала то, что действительно привезли, и лишь потом задание от админа:
  /// расходится это редко, но правда — в доставленном.
  static int? _lastQty(List<Order> orders) {
    Order? latest;
    for (final order in orders) {
      if (_qtyOf(order) == null) continue;
      if (latest == null || _dateOf(order).isAfter(_dateOf(latest))) {
        latest = order;
      }
    }
    return latest == null ? null : _qtyOf(latest);
  }

  static int? _qtyOf(Order order) {
    final delivered = order.deliveredCapsules ?? 0;
    if (delivered > 0) return delivered;
    final planned = order.bottleSellCount ?? 0;
    return planned > 0 ? planned : null;
  }

  static DateTime _dateOf(Order order) =>
      order.completedAt ?? order.routeDate ?? order.createdAt;
}

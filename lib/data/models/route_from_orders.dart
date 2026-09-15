/// Сборка маршрута из его заказов.
///
/// Нужна из-за одного пробела на сервере: `GET /driver/routes` отдаёт только
/// маршруты в статусе `in_progress`, а `GET /driver/routes/{id}` отвечает 404
/// на всё остальное. Стоит водителю закрыть последнюю точку — и весь его день
/// вместе с кассой исчезает с экрана; свести деньги вечером не по чему.
///
/// Заказы при этом видны за всё время (`GET /driver/orders`), и маршрут по ним
/// восстанавливается почти полностью. «Почти» — это статус: у заказа нет поля
/// «маршрут отменён», и отменённый маршрут с незакрытыми заказами здесь
/// выглядит как начатый. Ошибка осознанная и односторонняя: показать закрытым
/// то, что не закрыто, эта сборка не может, а невидимый день — хуже.
///
/// Убрать целиком, когда `/driver/routes` перестанет фильтровать по статусу.
library;

import 'enums.dart';
import 'order.dart';
import 'route_expense.dart';
import 'route_models.dart';



/// Статус маршрута по его заказам.
///
/// Незакрытый заказ означает, что маршрут ещё везут; все закрытые — что день
/// по нему закончен. `cancelled` отсюда не выводится (см. заметку выше).
RouteStatus _statusOf(List<Order> orders) {
  final open = orders.any((o) => o.status.isOpen);
  return open ? RouteStatus.inProgress : RouteStatus.completed;
}

/// Касса маршрута по его заказам.
///
/// Сервер считает её сам и отдаёт в ответе маршрута; здесь тот же расчёт по
/// доступным данным — для маршрутов, ответа по которым уже не получить.
/// Кассой считаются только наличные: карта и перевод уходят на счёт компании.
({int cash, int cashless, int debt}) _money(List<Order> orders) {
  var cash = 0;
  var cashless = 0;
  var debt = 0;

  for (final order in orders) {
    final paid = order.paidAmount ?? 0;
    switch (order.paymentMethod) {
      case PaymentMethod.cash:
        cash += paid;
      case PaymentMethod.card:
      case PaymentMethod.transfer:
        cashless += paid;
      case PaymentMethod.debt:
      case null:
        break;
    }
    // Недоплата — начисленный долг заказчика, независимо от способа оплаты.
    debt += order.unpaid;
  }

  return (cash: cash, cashless: cashless, debt: debt);
}

/// Строка списка маршрутов из заказов одного маршрута.
///
/// [orders] обязан быть непустым и принадлежать одному маршруту — группировку
/// делает вызывающий.
RouteListItem routeListItemFromOrders(List<Order> orders) {
  final first = orders.first;
  final money = _money(orders);

  return RouteListItem(
    id: first.routeId ?? '',
    date: first.routeDate ?? first.createdAt,
    status: _statusOf(orders),
    completedCount: orders.where((o) => o.isCompleted).length,
    totalCustomers: orders.length,
    driverId: first.driverId,
    driverFullName: first.driverFullName,
    cashCollected: money.cash,
    cashlessCollected: money.cashless,
    debtAmount: money.debt,
    // Расходы в списке не показываем: ради них пришлось бы делать запрос на
    // каждый маршрут страницы. Они появляются в карточке, где запрос один.
  );
}

/// Карточка маршрута из его заказов и расходов.
RouteDetail routeDetailFromOrders(
  List<Order> orders, {
  List<RouteExpense> expenses = const [],
}) {
  final first = orders.first;
  final money = _money(orders);
  final spent = expenses.fold<int>(0, (sum, e) => sum + e.amount);

  return RouteDetail(
    id: first.routeId ?? '',
    date: first.routeDate ?? first.createdAt,
    status: _statusOf(orders),
    completedCount: orders.where((o) => o.isCompleted).length,
    totalCustomers: orders.length,
    driverId: first.driverId,
    driverFullName: first.driverFullName,
    stops: [for (final order in orders) stopFromOrder(order)],
    cashCollected: money.cash,
    cashlessCollected: money.cashless,
    debtAmount: money.debt,
    expensesTotal: spent,
    cashBalance: money.cash - spent,
  );
}

/// Точка маршрута из заказа: это одна и та же запись, разные представления.
RouteStop stopFromOrder(Order order) => RouteStop(
      id: order.id,
      customerId: order.customerId,
      customerName: order.customerName,
      customerAddress: order.customerAddress,
      customerPhone: order.customerPhone,
      status: order.status,
      deliveredCapsules: order.deliveredCapsules,
      returnedCapsules: order.returnedCapsules,
      returnedFullCapsules: order.returnedFullCapsules,
      damagedCapsules: order.damagedCapsules,
      cancelReason: order.cancelReason,
      cancelledAt: order.cancelledAt,
      customPrice: order.customPrice,
      pickedCoolers: order.pickedCoolers,
      pickedBottles: order.pickedBottles,
      bulk5lCount: order.bulk5lCount,
      bulk5lPrice: order.bulk5lPrice,
      bulk10lCount: order.bulk10lCount,
      bulk10lPrice: order.bulk10lPrice,
      capsuleBalanceAfter: order.capsuleBalanceAfter,
      paymentAmount: order.paidAmount,
      paymentMethod: order.paymentMethod,
      // Фото живёт у платежа, а не у заказа: берём первое приложенное.
      paymentPhoto: order.payments
          .map((p) => p.photoUrl)
          .where((url) => url != null && url.isNotEmpty)
          .firstOrNull,
      completedAt: order.completedAt,
      customerCoolerCount: order.customerCoolerCount,
      sequence: order.sequence,
      purpose: order.purpose,
      effectiveWaterPrice: order.effectiveWaterPrice,
      damagedBottleFine: order.damagedBottleFine,
    );

/// Группирует заказы по маршрутам, новые дни первыми.
List<List<Order>> groupByRoute(List<Order> orders) {
  final byRoute = <String, List<Order>>{};
  for (final order in orders) {
    final routeId = order.routeId;
    // Заказ без маршрута собрать не во что: `route_id` на сервере NOT NULL,
    // и его отсутствие означает неполный ответ, а не «заказ сам по себе».
    if (routeId == null || routeId.isEmpty) continue;
    byRoute.putIfAbsent(routeId, () => []).add(order);
  }

  final groups = byRoute.values.toList()
    ..sort((a, b) {
      final dateA = a.first.routeDate ?? a.first.createdAt;
      final dateB = b.first.routeDate ?? b.first.createdAt;
      return dateB.compareTo(dateA);
    });

  // Внутри маршрута — по порядку объезда, как отдал бы сервер.
  for (final group in groups) {
    group.sort((a, b) => (a.sequence ?? 0).compareTo(b.sequence ?? 0));
  }

  return groups;
}

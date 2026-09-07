import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/route_expense.dart';
import 'package:crm_millwater/data/models/route_from_orders.dart';
import 'package:flutter_test/flutter_test.dart';

/// Восстановление маршрута из заказов.
///
/// `GET /driver/routes` отдаёт только `in_progress`, а `/driver/routes/{id}`
/// на остальное отвечает 404 — закрыв последнюю точку, водитель терял весь
/// день вместе с кассой. Здесь проверяется сборка, которая эту дыру закрывает.
void main() {
  Order order({
    required String id,
    String routeId = 'r-1',
    String date = '2026-09-04',
    DeliveryStatus status = DeliveryStatus.delivered,
    String? method = 'cash',
    String amount = '20000.00',
    String? paid,
    int sequence = 1,
  }) =>
      Order.fromJson({
        'id': id,
        'number': 1,
        'sequence': sequence,
        'status': status.toJson(),
        'purpose': 'delivery_19l',
        'payment_method': method,
        'order_amount': amount,
        'paid_amount': paid ?? amount,
        'created_at': '2026-09-04T08:00:00Z',
        'customer': {'customer_id': 'c-1', 'customer_full_name': 'Кафе'},
        'route': {
          'route_id': routeId,
          'route_date': date,
          'driver_id': 'd-1',
          'driver_full_name': 'Тест Флоу',
        },
      });

  group('Статус маршрута выводится по заказам', () {
    test('все заказы закрыты — маршрут завершён', () {
      final route = routeDetailFromOrders([
        order(id: 'o-1'),
        order(id: 'o-2', sequence: 2),
      ]);

      expect(route.status, RouteStatus.completed);
      expect(route.completedCount, 2);
      expect(route.totalCustomers, 2);
    });

    test('есть незакрытый заказ — маршрут в работе', () {
      final route = routeDetailFromOrders([
        order(id: 'o-1'),
        order(id: 'o-2', status: DeliveryStatus.pending, method: null),
      ]);

      expect(route.status, RouteStatus.inProgress);
      expect(route.completedCount, 1);
    });
  });

  group('Касса собирается из заказов', () {
    test('наличные, безнал и долг разведены', () {
      final route = routeDetailFromOrders(
        [
          order(id: 'o-1', amount: '20000.00'),
          order(id: 'o-2', method: 'card', amount: '30000.00', sequence: 2),
          // В долг: начислено, но не получено.
          order(
            id: 'o-3',
            method: 'debt',
            amount: '15000.00',
            paid: '0.00',
            sequence: 3,
          ),
        ],
        expenses: [
          RouteExpense(
            id: 'e-1',
            routeId: 'r-1',
            driverId: 'd-1',
            amount: 5000,
            category: ExpenseCategory.fuel,
            createdAt: DateTime(2026, 9, 4),
          ),
        ],
      );

      // Кассой считаются только наличные: карта уходит на счёт компании.
      expect(route.cashCollected, 20000);
      expect(route.cashlessCollected, 30000);
      expect(route.debtAmount, 15000);
      expect(route.expensesTotal, 5000);
      expect(route.cashBalance, 15000);
    });

    test('расход больше наличных уводит остаток в минус', () {
      // Рабочее состояние: водитель заправился на свои до первой оплаты.
      final route = routeDetailFromOrders(
        [order(id: 'o-1', amount: '10000.00')],
        expenses: [
          RouteExpense(
            id: 'e-1',
            routeId: 'r-1',
            driverId: 'd-1',
            amount: 42000,
            category: ExpenseCategory.fuel,
            createdAt: DateTime(2026, 9, 4),
          ),
        ],
      );

      expect(route.cashBalance, -32000);
    });
  });

  group('Группировка по маршрутам', () {
    test('заказы разных дней расходятся по маршрутам, новые первыми', () {
      final groups = groupByRoute([
        order(id: 'o-1', routeId: 'r-old', date: '2026-09-01'),
        order(id: 'o-2', routeId: 'r-new', date: '2026-09-04'),
        order(id: 'o-3', routeId: 'r-old', date: '2026-09-01', sequence: 2),
      ]);

      expect(groups, hasLength(2));
      expect(groups.first.first.routeId, 'r-new');
      expect(groups.last, hasLength(2));
    });

    test('внутри маршрута порядок объезда сохраняется', () {
      final groups = groupByRoute([
        order(id: 'o-2', sequence: 2),
        order(id: 'o-1', sequence: 1),
      ]);

      expect(groups.single.map((o) => o.id), ['o-1', 'o-2']);
    });
  });

  test('точка собирается из заказа без потери состава', () {
    final stop = stopFromOrder(Order.fromJson({
      'id': 'o-1',
      'status': 'delivered',
      'purpose': 'pickup',
      'picked_coolers': 2,
      'picked_bottles': 3,
      'damaged_bottles': 1,
      'created_at': '2026-09-04T08:00:00Z',
      'customer': {'customer_full_name': 'Кафе', 'customer_cooler_count': 2},
    }));

    expect(stop.purpose, OrderPurpose.pickup);
    expect(stop.pickedCoolers, 2);
    expect(stop.pickedBottles, 3);
    expect(stop.damagedCapsules, 1);
    expect(stop.customerCoolerCount, 2);
  });
}

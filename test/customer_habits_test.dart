import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/result_page.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/routes/domain/customer_habits.dart';
import 'package:flutter_test/flutter_test.dart';

/// Отвечает заготовленной страницей заказов и запоминает, о чём спросили.
class _OrdersRepository extends MockCrmRepository {
  _OrdersRepository({this.orders = const [], this.fails = false});

  List<Order> orders;
  bool fails;

  /// Запросы истории: заказчик и левая граница периода.
  final List<(String?, DateTime?)> asked = [];

  @override
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
  }) async {
    asked.add((customerId, dateFrom));
    if (fails) throw Exception('нет связи');
    return ResultPage(
      items: orders,
      page: page,
      hasMore: false,
      total: orders.length,
    );
  }
}

Customer customerWith({DateTime? lastOrderDate}) => Customer(
      id: 'c1',
      name: 'Кафе «Nasiba»',
      phone: '+998 71 200 11 22',
      address: 'ул. Амир Темур, 12',
      lastOrderDate: lastOrderDate,
      createdAt: DateTime(2026, 1, 1),
    );

Order orderWith({
  required String id,
  required DateTime completedAt,
  int? delivered,
  int? planned,
}) =>
    Order(
      id: id,
      number: 1,
      status: DeliveryStatus.delivered,
      purpose: OrderPurpose.delivery19l,
      deliveredCapsules: delivered,
      bottleSellCount: planned,
      completedAt: completedAt,
      createdAt: completedAt,
      customerId: 'c1',
      customerName: 'Кафе «Nasiba»',
    );

void main() {
  group('Обычный объём заказчика', () {
    test('берётся из самой свежей доставки, а не из первой в ответе', () async {
      // Сортировка `/admin/orders` в схеме не описана — порядок в ответе
      // ничего не значит, и класс обязан выбрать свежее сам.
      final repo = _OrdersRepository(orders: [
        orderWith(
          id: 'o1',
          completedAt: DateTime(2026, 9, 10),
          delivered: 3,
        ),
        orderWith(
          id: 'o2',
          completedAt: DateTime(2026, 9, 18),
          delivered: 8,
        ),
      ]);

      final qty = await CustomerHabits(repo)
          .load(customerWith(lastOrderDate: DateTime(2026, 9, 18)));

      expect(qty, 8);
    });

    test('окно запроса — день последней доставки', () async {
      final repo = _OrdersRepository(orders: [
        orderWith(id: 'o1', completedAt: DateTime(2026, 9, 18), delivered: 6),
      ]);

      await CustomerHabits(repo).load(
        customerWith(lastOrderDate: DateTime(2026, 9, 18, 23, 50)),
      );

      // Заказчик и календарный день без времени: так ответ не зависит от
      // сортировки и не утыкается в потолок страницы.
      expect(repo.asked, [('c1', DateTime(2026, 9, 18))]);
    });

    test('без доставленных берётся задание админа', () async {
      final repo = _OrdersRepository(orders: [
        orderWith(id: 'o1', completedAt: DateTime(2026, 9, 18), planned: 4),
      ]);

      final qty = await CustomerHabits(repo)
          .load(customerWith(lastOrderDate: DateTime(2026, 9, 18)));

      expect(qty, 4);
    });

    test('ответ кэшируется — второй раз в сеть не идём', () async {
      final repo = _OrdersRepository(orders: [
        orderWith(id: 'o1', completedAt: DateTime(2026, 9, 18), delivered: 6),
      ]);
      final habits = CustomerHabits(repo);
      final customer = customerWith(lastOrderDate: DateTime(2026, 9, 18));

      await habits.load(customer);
      await habits.load(customer);

      expect(repo.asked.length, 1);
      expect(habits.knows('c1'), isTrue);
      expect(habits.cached('c1'), 6);
    });

    test('заказчика без доставок не спрашиваем вовсе', () async {
      final repo = _OrdersRepository();
      final habits = CustomerHabits(repo);

      final qty = await habits.load(customerWith());

      expect(qty, isNull);
      expect(repo.asked, isEmpty);
      // Спросили и выяснили, что истории нет: подпись «обычно» не покажем,
      // но и второй раз не полезем.
      expect(habits.knows('c1'), isTrue);
    });

    test('отказ сети не запоминается', () async {
      final repo = _OrdersRepository(fails: true);
      final habits = CustomerHabits(repo);
      final customer = customerWith(lastOrderDate: DateTime(2026, 9, 18));

      expect(await habits.load(customer), isNull);
      expect(habits.knows('c1'), isFalse);

      repo
        ..fails = false
        ..orders = [
          orderWith(id: 'o1', completedAt: DateTime(2026, 9, 18), delivered: 5),
        ];

      expect(await habits.load(customer), 5);
    });

    test('пустая история — ни объёма, ни повторного запроса', () async {
      final repo = _OrdersRepository();
      final habits = CustomerHabits(repo);
      final customer = customerWith(lastOrderDate: DateTime(2026, 9, 18));

      expect(await habits.load(customer), isNull);
      await habits.load(customer);

      expect(repo.asked.length, 1);
    });
  });
}

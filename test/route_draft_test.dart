import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/features/routes/domain/route_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// Черновик маршрута: состояние точек и производные от него итоги.
///
/// Тесты без виджетов: считать деньги и порядок объезда должно быть можно,
/// не поднимая экран, — иначе расчёт проверяется только через тапы.
void main() {
  const pricing = DraftPricing(
    capsulePrice: 20000,
    // У этого заказчика своя цена — как `custom_water_price` у сервера.
    customerPrices: {'c9': 15000},
  );

  RouteDraft draftOf(List<RouteDraftStop> stops) => RouteDraft(stops);

  group('Итоги', () {
    test('капсулы и деньги считаются по прайсу', () {
      final draft = draftOf(const [
        RouteDraftStop(customerId: 'c1', qty: 6),
        RouteDraftStop(customerId: 'c2', qty: 4),
      ]);

      final totals = draft.totals(pricing);

      expect(totals.stops, 2);
      expect(totals.capsules, 10);
      expect(totals.money, 10 * 20000);
    });

    test('индивидуальная цена заказчика перебивает общий прайс', () {
      final draft = draftOf(const [RouteDraftStop(customerId: 'c9', qty: 3)]);

      expect(draft.totals(pricing).money, 3 * 15000);
    });

    test('договорная сумма заменяет расчёт по прайсу целиком', () {
      // Не цена капсулы: сервер запишет её в стоимость заказа как есть,
      // сколько бы капсул ни привезли.
      final draft = draftOf(const [
        RouteDraftStop(customerId: 'c1', qty: 6, price: 100000),
      ]);

      final totals = draft.totals(pricing);
      expect(totals.money, 100000);
      // Капсулы своя цена не отменяет: их всё равно грузить.
      expect(totals.capsules, 6);
    });

    test('вывоз без своей цены денег не добавляет, со своей — добавляет', () {
      final free = draftOf(const [
        RouteDraftStop(
          customerId: 'c1',
          purpose: OrderPurpose.pickup,
          qty: 5,
        ),
      ]);
      expect(free.totals(pricing).money, 0);
      // И капсул тоже: вывоз ничего не везёт, машину он не занимает.
      expect(free.totals(pricing).capsules, 0);

      final paid = free.patch('c1', price: 50000);
      expect(paid.totals(pricing).money, 50000);
    });

    test('опт по прайсу не считается: цены на 5/10 л в прайсе нет', () {
      final draft = draftOf(const [
        RouteDraftStop(
          customerId: 'c1',
          purpose: OrderPurpose.bulkWater,
          qty: 12,
        ),
      ]);

      expect(draft.totals(pricing).money, 0);
      expect(draft.totals(pricing).capsules, 0);
      expect(draft.patch('c1', price: 80000).totals(pricing).money, 80000);
    });

    test('перегруз машины видно по итогам, но он не запрещён', () {
      final draft = draftOf(const [
        RouteDraftStop(customerId: 'c1', qty: 40),
        RouteDraftStop(customerId: 'c2', qty: 25),
      ]);

      final totals = draft.totals(pricing);
      expect(totals.capsules, 65);
      expect(totals.exceedsCapacity(60), isTrue);
      expect(totals.exceedsCapacity(80), isFalse);
    });
  });

  group('Состав и порядок', () {
    final base = draftOf(const [
      RouteDraftStop(customerId: 'c1', qty: 1),
      RouteDraftStop(customerId: 'c2', qty: 2),
      RouteDraftStop(customerId: 'c3', qty: 3),
    ]);

    test('тот же заказчик дважды не добавляется', () {
      final same = base.add(const RouteDraftStop(customerId: 'c2', qty: 9));

      expect(same.length, 3);
      expect(same.stopOf('c2')!.qty, 2);
    });

    test('точка добавляется в конец объезда', () {
      final grown = base.add(const RouteDraftStop(customerId: 'c4', qty: 4));

      expect(grown.stops.last.customerId, 'c4');
      expect(grown.numberOf('c4'), 4);
    });

    test('reorder переставляет на конечное место', () {
      // Индексы как у `onReorderItem`: список уже без вынутой точки.
      final moved = base.reorder(0, 2);

      expect(moved.stops.map((s) => s.customerId), ['c2', 'c3', 'c1']);
    });

    test('reorder за границами списка ничего не меняет', () {
      expect(base.reorder(0, 3), base);
      expect(base.reorder(5, 0), base);
      expect(base.reorder(1, 1), base);
    });

    test('стрелки сдвигают на шаг и не выходят за края', () {
      expect(base.shift('c3', -1).stops.map((s) => s.customerId),
          ['c1', 'c3', 'c2']);
      expect(base.shift('c1', -1), base);
      expect(base.shift('c3', 1), base);
    });

    test('удаление точки не трогает остальные', () {
      final smaller = base.remove('c2');

      expect(smaller.stops.map((s) => s.customerId), ['c1', 'c3']);
      expect(smaller.numberOf('c3'), 2);
    });

    test('смена цели не теряет набранное количество', () {
      // Вернувшись к доставке, оператор не должен набирать число заново.
      final pickup = base.patch('c2', purpose: OrderPurpose.pickup);
      final back = pickup.patch('c2', purpose: OrderPurpose.delivery19l);

      expect(back.stopOf('c2')!.qty, 2);
    });

    test('сброс цены на прайс отличим от «не меняем»', () {
      final priced = base.patch('c1', price: 90000);
      expect(priced.stopOf('c1')!.price, 90000);

      // Без маркера «не передавали» обычный `??` потерял бы этот сброс.
      final reset = priced.patch('c1', price: null);
      expect(reset.stopOf('c1')!.price, isNull);

      final touched = priced.patch('c1', qty: 7);
      expect(touched.stopOf('c1')!.price, 90000);
    });
  });

  group('Отправка на сервер', () {
    test('порядок объезда уходит номерами sequence', () {
      final draft = draftOf(const [
        RouteDraftStop(customerId: 'c3', qty: 3),
        RouteDraftStop(customerId: 'c1', qty: 1),
      ]);

      final orders = draft.toOrders();

      expect(orders.map((o) => o.customerId), ['c3', 'c1']);
      expect(orders.map((o) => o.sequence), [1, 2]);
    });

    test('задание в капсулах — у доставки и вывоза, у опта нет', () {
      final draft = draftOf(const [
        RouteDraftStop(customerId: 'c1', qty: 6),
        RouteDraftStop(
          customerId: 'c2',
          purpose: OrderPurpose.pickup,
          qty: 4,
        ),
        RouteDraftStop(
          customerId: 'c3',
          purpose: OrderPurpose.bulkWater,
          qty: 8,
        ),
      ]);

      final orders = draft.toOrders();

      // Поле на сервере одно и ни в один расчёт не входит: у доставки оно
      // значит «сколько везти», у вывоза — «сколько забрать». У опта
      // передавать нечего: бутыли 5/10 л считает водитель на месте.
      expect(orders[0].bottleSellCount, 6);
      expect(orders[1].bottleSellCount, 4);
      expect(orders[2].bottleSellCount, isNull);
    });

    test('договорная сумма уходит при любой цели', () {
      // Валидаторов по цели у `order_custom_price` нет, и при закрытии сервер
      // берёт `custom_price or order_cost` одинаково для всех целей.
      final draft = draftOf(const [
        RouteDraftStop(customerId: 'c1', qty: 6, price: 150000),
        RouteDraftStop(
          customerId: 'c2',
          purpose: OrderPurpose.pickup,
          qty: 1,
          price: 50000,
        ),
        RouteDraftStop(
          customerId: 'c3',
          purpose: OrderPurpose.bulkWater,
          qty: 1,
          price: 80000,
        ),
        RouteDraftStop(customerId: 'c4', qty: 2),
      ]);

      final orders = draft.toOrders();

      expect(orders.map((o) => o.customPrice), [150000, 50000, 80000, null]);
      expect(orders.map((o) => o.purpose), [
        OrderPurpose.delivery19l,
        OrderPurpose.pickup,
        OrderPurpose.bulkWater,
        OrderPurpose.delivery19l,
      ]);
    });
  });
}

import 'package:crm_millwater/core/maps/route_plan.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/route_from_orders.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Порядок объезда точек.
///
/// Сервер отдаёт точки в порядке создания и по `sequence` их не сортирует, хотя
/// номер проставляет и умеет менять. Раньше порядок восстанавливали только на
/// построении маршрута в картах — то есть заданный админом объезд до списка
/// точек у водителя не доходил.
void main() {
  Map<String, dynamic> stop(String id, {int? sequence, String status = 'pending'}) => {
        'id': id,
        'customer_id': 'c-$id',
        'customer_full_name': 'Заказчик $id',
        'customer_address': 'Адрес $id',
        'status': status,
        'sequence': ?sequence,
      };

  Map<String, dynamic> routeJson(List<Map<String, dynamic>> stops) => {
        'id': 'r-1',
        'date': '2026-09-25',
        'status': 'created',
        'completed_count': 0,
        'total_customers': stops.length,
        'orders': stops,
      };

  List<String> idsOf(RouteDetail route) =>
      [for (final s in route.stops) s.id];

  group('Точки маршрута', () {
    test('ставятся по sequence, а не в порядке ответа', () {
      final route = RouteDetail.fromJson(routeJson([
        stop('c', sequence: 3),
        stop('a', sequence: 1),
        stop('b', sequence: 2),
      ]));

      expect(idsOf(route), ['a', 'b', 'c']);
    });

    test('без номера — в конец, порядком ответа', () {
      // Точка, добавленная в маршрут старым стендом, номера не имеет: её
      // место — после тех, у кого порядок задан, а не первым.
      final route = RouteDetail.fromJson(routeJson([
        stop('x'),
        stop('b', sequence: 2),
        stop('y'),
        stop('a', sequence: 1),
      ]));

      expect(idsOf(route), ['a', 'b', 'x', 'y']);
    });

    test('равные номера сохраняют порядок ответа', () {
      // Номера дублируются после правок состава — порядок тогда решает сервер,
      // и переставлять такие точки между собой нельзя.
      final route = RouteDetail.fromJson(routeJson([
        stop('first', sequence: 1),
        stop('second', sequence: 1),
      ]));

      expect(idsOf(route), ['first', 'second']);
    });

    test('старое имя поля `order` тоже задаёт порядок', () {
      final route = RouteDetail.fromJson(routeJson([
        {...stop('late'), 'order': 9},
        {...stop('early'), 'order': 1},
      ]));

      expect(idsOf(route), ['early', 'late']);
    });

    test('построение маршрута в картах берёт тот же порядок', () {
      final stops = RouteDetail.fromJson(routeJson([
        stop('done', sequence: 1, status: 'delivered'),
        stop('third', sequence: 4),
        stop('second', sequence: 3),
      ])).stops;

      // Закрытые точки отбрасываются, остальные — по номеру.
      expect(
        [for (final s in RoutePlanner.pendingStops(stops)) s.id],
        ['second', 'third'],
      );
    });
  });

  group('Маршрут, собранный из заказов', () {
    Order order(String id, {int? sequence}) => Order.fromJson({
          'id': id,
          'order_number': 1,
          'status': 'delivered',
          'created_at': '2026-09-25T08:00:00Z',
          'customer_id': 'c-$id',
          'customer_full_name': 'Заказчик $id',
          'route_id': 'r-1',
          'route_date': '2026-09-25',
          'sequence': ?sequence,
        });

    test('заказы внутри маршрута идут по порядку объезда', () {
      final groups = groupByRoute([
        order('b', sequence: 2),
        order('a', sequence: 1),
      ]);

      expect([for (final o in groups.single) o.id], ['a', 'b']);
    });

    test('заказ без номера уходит в конец, а не в начало', () {
      // Прежний `sequence ?? 0` ставил безномерные первыми, и день водителя
      // начинался не с той точки.
      final groups = groupByRoute([
        order('unknown'),
        order('second', sequence: 2),
        order('first', sequence: 1),
      ]);

      expect(
        [for (final o in groups.single) o.id],
        ['first', 'second', 'unknown'],
      );
    });
  });
}

import 'package:crm_millwater/core/utils/day.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Перенос заказа и правка оплаты — то, что сервер делает молча (204 без
/// тела), а увидеть последствия можно только перечитав данные.
///
/// Мок повторяет его правила: опустевший маршрут отменяется, точка встаёт в
/// конец очереди целевого маршрута, а править оплату можно только у
/// закрытого заказа.
void main() {
  group('Перенос заказа', () {
    late MockCrmRepository repo;

    setUp(() => repo = MockCrmRepository());

    test('точка уходит в другой маршрут и встаёт в конец', () async {
      final source = repo.store.routes.first;
      final target = repo.store.routes[1];
      final stop = source.stops.first;
      final targetSizeBefore = target.stops.length;

      await repo.moveOrderToRoute(orderId: stop.id, targetRouteId: target.id);

      final movedTo = (await repo.getRoute(target.id))!;
      final left = (await repo.getRoute(source.id))!;
      expect(movedTo.stops.last.id, stop.id);
      expect(movedTo.stops, hasLength(targetSizeBefore + 1));
      expect(left.stops.any((s) => s.id == stop.id), isFalse);
    });

    test('опустевший маршрут отменяется, а не остаётся пустым', () async {
      final source = repo.store.routes.first;
      final target = repo.store.routes[1];

      for (final stop in source.stops.toList()) {
        await repo.moveOrderToRoute(orderId: stop.id, targetRouteId: target.id);
      }

      final empty = (await repo.getRoute(source.id))!;
      expect(empty.stops, isEmpty);
      // Иначе в списке остался бы маршрут на ноль точек, который водителю
      // нечего везти.
      expect(empty.status, RouteStatus.cancelled);
    });

    test('перенос на дату без маршрута заводит маршрут без водителя',
        () async {
      final stop = repo.store.routes.first.stops.first;
      final date = dayOnly(DateTime.now()).add(const Duration(days: 30));
      final routesBefore = repo.store.routes.length;

      await repo.moveOrderToDate(orderId: stop.id, date: date);

      expect(repo.store.routes, hasLength(routesBefore + 1));
      final created =
          repo.store.routes.firstWhere((r) => r.date == date);
      expect(created.stops.single.id, stop.id);
      // Ровно то, о чём экран предупреждает до отправки: заказ уехал в
      // маршрут, который некому везти.
      expect(created.driverId, isNull);
    });

    test('на дату с существующим маршрутом нового не заводит', () async {
      final target = repo.store.routes[1];
      final stop = repo.store.routes.first.stops.first;
      final routesBefore = repo.store.routes.length;

      await repo.moveOrderToDate(
        orderId: stop.id,
        date: target.date,
        driverId: target.driverId,
      );

      expect(repo.store.routes, hasLength(routesBefore));
      final moved = (await repo.getRoute(target.id))!;
      expect(moved.stops.any((s) => s.id == stop.id), isTrue);
    });
  });

  group('Правка оплаты', () {
    late MockCrmRepository repo;

    setUp(() => repo = MockCrmRepository());

    test('меняет сумму и способ у закрытого заказа', () async {
      final stop = repo.store.routes
          .expand((r) => r.stops)
          .firstWhere((s) => s.isCompleted);

      await repo.updateOrderPayment(
        orderId: stop.id,
        amount: 115000,
        method: PaymentMethod.transfer,
      );

      final updated = repo.store.routes
          .expand((r) => r.stops)
          .firstWhere((s) => s.id == stop.id);
      expect(updated.paymentAmount, 115000);
      expect(updated.paymentMethod, PaymentMethod.transfer);
    });

    test('у незакрытого заказа править нечего', () async {
      final stop = repo.store.routes
          .expand((r) => r.stops)
          .firstWhere((s) => !s.isCompleted);

      // Сервер отвечает 409 ORDER_NOT_COMPLETED — кнопка у такого заказа и
      // не показывается, но правило должно держаться и ниже экрана.
      expect(
        () => repo.updateOrderPayment(
          orderId: stop.id,
          amount: 1000,
          method: PaymentMethod.cash,
        ),
        throwsStateError,
      );
    });
  });
}

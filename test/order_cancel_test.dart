import 'dart:typed_data';

import 'package:crm_millwater/data/mock/mock_store.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:crm_millwater/data/repositories/api_driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/orders/bloc/orders_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Отмена заказа с причиной и возврат полных капсул — модели, запросы, мок.
///
/// Контракт написан вперёд сервера (`docs/tz/04-cancel-and-full-return.md`),
/// поэтому здесь закреплено то, что бэкенд получит от клиента и что клиент
/// обязан понять в ответ. Разъехаться им нельзя: имена полей и пути — это и
/// есть договор.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    // Обе ручки отвечают 204 без тела.
    return ResponseBody.fromString('', 204);
  }
}

void main() {
  group('Разбор заказа', () {
    Map<String, dynamic> json([Map<String, dynamic> extra = const {}]) => {
          'id': 'o-1',
          'number': 7,
          'status': 'cancelled',
          'purpose': 'delivery_19l',
          'created_at': '2026-09-14T08:00:00Z',
          'customer': {'id': 'c-1', 'full_name': 'Кафе'},
          ...extra,
        };

    test('статус cancelled, причина и время читаются', () {
      final order = Order.fromJson(json({
        'cancel_reason': 'Заказчик не открыл дверь',
        'cancelled_at': '2026-09-14T10:15:00Z',
        'returned_full_bottles': 2,
      }));

      expect(order.status, DeliveryStatus.cancelled);
      expect(order.isCancelled, isTrue);
      expect(order.canCancel, isFalse);
      expect(order.cancelReason, 'Заказчик не открыл дверь');
      // Даты приходят в UTC и разбираются в локальное время.
      expect(order.cancelledAt, DateTime.utc(2026, 9, 14, 10, 15).toLocal());
      expect(order.returnedFullCapsules, 2);
    });

    test('пустая причина — это отсутствие причины, а не пустая строка', () {
      expect(Order.fromJson(json({'cancel_reason': ''})).cancelReason, isNull);
      expect(Order.fromJson(json({'cancel_reason': '  '})).cancelReason, isNull);
      expect(Order.fromJson(json({'cancel_reason': null})).cancelReason, isNull);
    });

    test('старый стенд без новых полей разбирается как раньше', () {
      final order = Order.fromJson(json({'status': 'pending'}));

      expect(order.status, DeliveryStatus.pending);
      expect(order.canCancel, isTrue);
      expect(order.cancelReason, isNull);
      expect(order.cancelledAt, isNull);
      expect(order.returnedFullCapsules, isNull);
    });

    test('точка маршрута читает те же поля', () {
      final stop = RouteStop.fromJson({
        'id': 's-1',
        'status': 'cancelled',
        'cancel_reason': 'Переехал',
        'cancelled_at': '2026-09-14T10:15:00Z',
        'returned_full_bottles': 1,
        'customer': {'id': 'c-1', 'full_name': 'Кафе'},
      });

      expect(stop.isCancelled, isTrue);
      expect(stop.cancelReason, 'Переехал');
      expect(stop.cancelledAt, isNotNull);
      expect(stop.returnedFullCapsules, 1);
      // Отменённая точка закрыта: сумма у неё есть (ноль), а не «ещё нет».
      expect(stop.status.isOpen, isFalse);
    });
  });

  group('Статус доставки', () {
    test('открыты только pending и on_way', () {
      expect(DeliveryStatus.pending.isOpen, isTrue);
      expect(DeliveryStatus.onWay.isOpen, isTrue);
      expect(DeliveryStatus.delivered.isOpen, isFalse);
      expect(DeliveryStatus.failed.isOpen, isFalse);
      expect(DeliveryStatus.cancelled.isOpen, isFalse);
    });

    test('«не доставлено» и «отменён» — оба закрыты без доставки, но разные', () {
      expect(DeliveryStatus.failed.isClosedWithoutDelivery, isTrue);
      expect(DeliveryStatus.cancelled.isClosedWithoutDelivery, isTrue);
      expect(DeliveryStatus.delivered.isClosedWithoutDelivery, isFalse);
      expect(DeliveryStatus.fromJson('cancelled'), DeliveryStatus.cancelled);
      expect(DeliveryStatus.cancelled.toJson(), 'cancelled');
    });
  });

  group('Тело отмены', () {
    test('причина обрезается по краям', () {
      expect(cancelOrderBody('  не открыл  '), {'reason': 'не открыл'});
    });

    test('без причины поле не отправляется вовсе', () {
      expect(cancelOrderBody(null), isEmpty);
      expect(cancelOrderBody(''), isEmpty);
      expect(cancelOrderBody('   '), isEmpty);
    });
  });

  group('Запросы', () {
    late _RecordingAdapter adapter;
    Dio dio() => Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;

    setUp(() => adapter = _RecordingAdapter());

    test('админ отменяет через /admin/orders/{id}/cancel', () async {
      await ApiCrmRepository(dio())
          .cancelOrder(orderId: 'o-1', reason: 'Не открыл дверь');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/admin/orders/o-1/cancel');
      expect(request.data, {'reason': 'Не открыл дверь'});
    });

    test('водитель отменяет через /driver/orders/{id}/cancel', () async {
      await ApiDriverRepository(dio()).cancelOrder(orderId: 'o-1');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/driver/orders/o-1/cancel');
      // Без причины — пустое тело, а не `reason: null`.
      expect(request.data, isEmpty);
    });

    test('полные капсулы уходят в /complete только когда вернули', () async {
      final repo = ApiDriverRepository(dio());

      await repo.completeDelivery(
        stopId: 's-1',
        purpose: OrderPurpose.delivery19l,
        amount: 20000,
        method: PaymentMethod.cash,
        capsules: 2,
        returnedFullCapsules: 1,
        bottleBalance: 4,
      );
      var fields = {
        for (final f in (adapter.requests.last.data as FormData).fields)
          f.key: f.value
      };
      expect(fields['returned_full_bottles'], '1');
      expect(fields['returned_bottles'], '0');
      expect(fields['bottle_balance'], '4');

      await repo.completeDelivery(
        stopId: 's-1',
        purpose: OrderPurpose.delivery19l,
        amount: 20000,
        method: PaymentMethod.cash,
        capsules: 1,
      );
      fields = {
        for (final f in (adapter.requests.last.data as FormData).fields)
          f.key: f.value
      };
      // Старый стенд поля не знает — лишний ноль ему не отправляем.
      expect(fields.containsKey('returned_full_bottles'), isFalse);
    });
  });

  group('Источник заказов', () {
    // Отмена идёт через источник экрана заказов: у каждой роли своя ручка,
    // а карточка заказа о репозиториях не знает.
    test('админский источник отменяет через админский репозиторий', () async {
      final store = MockStore();
      final open = store.routes
          .expand((r) => r.stops)
          .firstWhere((s) => s.status.isOpen);

      await AdminOrdersSource(MockCrmRepository(store: store))
          .cancel(orderId: open.id, reason: 'Дубль');

      final stop = store.routes
          .expand((r) => r.stops)
          .firstWhere((s) => s.id == open.id);
      expect(stop.isCancelled, isTrue);
      expect(stop.cancelReason, 'Дубль');
    });

    test('водительский источник отменяет через водительский репозиторий',
        () async {
      final store = MockStore();
      final repo = MockDriverRepository(store: store, driverId: 'd1');
      final open = store.routes
          .firstWhere((r) => r.id == 'r1')
          .stops
          .firstWhere((s) => s.status.isOpen);

      await DriverOrdersSource(repo).cancel(orderId: open.id);

      expect(repo.lastCancelReason, isNull);
      expect(
        store.routes
            .expand((r) => r.stops)
            .firstWhere((s) => s.id == open.id)
            .isCancelled,
        isTrue,
      );
    });
  });

  group('Мок', () {
    test('отмена меняет статус и пишет причину, видна обеим ролям', () async {
      final store = MockStore();
      final admin = MockCrmRepository(store: store);
      final driver = MockDriverRepository(store: store, driverId: 'd1');
      final route = store.routes.firstWhere((r) => r.id == 'r1');
      final open = route.stops.firstWhere((s) => s.status.isOpen);

      await admin.cancelOrder(orderId: open.id, reason: 'Переехал');

      final asOrder = (await admin.getOrder(open.id))!;
      expect(asOrder.status, DeliveryStatus.cancelled);
      expect(asOrder.cancelReason, 'Переехал');
      expect(asOrder.cancelledAt, isNotNull);

      final asStop = (await driver.getMyRoute('r1'))!
          .stops
          .firstWhere((s) => s.id == open.id);
      expect(asStop.isCancelled, isTrue);
      expect(asStop.cancelReason, 'Переехал');
    });

    test('пустая причина хранится как отсутствие', () async {
      final store = MockStore();
      final route = store.routes.firstWhere((r) => r.id == 'r1');
      final open = route.stops.firstWhere((s) => s.status.isOpen);

      store.cancelStop(open.id, reason: '   ');

      final stop = store.routes
          .expand((r) => r.stops)
          .firstWhere((s) => s.id == open.id);
      expect(stop.isCancelled, isTrue);
      expect(stop.cancelReason, isNull);
    });

    test('закрытый заказ отменить нельзя — как 409 у сервера', () async {
      final store = MockStore();
      final route = store.routes.firstWhere((r) => r.id == 'r1');
      final done = route.stops.firstWhere((s) => s.isCompleted);

      expect(
        () => MockCrmRepository(store: store).cancelOrder(orderId: done.id),
        throwsStateError,
      );
    });

    test('маршрут закрывается, когда открытых точек не осталось', () async {
      final store = MockStore();
      final repo = MockCrmRepository(store: store);
      final route = store.routes.firstWhere((r) => r.id == 'r1');

      for (final stop in route.stops.where((s) => s.status.isOpen)) {
        await repo.cancelOrder(orderId: stop.id);
      }

      expect(
        store.routes.firstWhere((r) => r.id == 'r1').status,
        RouteStatus.completed,
      );
    });

    test('возврат полных капсул запоминается и уменьшает остаток', () async {
      final store = MockStore();
      final driver = MockDriverRepository(store: store, driverId: 'd1');
      final route = store.routes.firstWhere((r) => r.id == 'r1');
      final open = route.stops.firstWhere((s) => s.status.isOpen);

      await driver.completeDelivery(
        stopId: open.id,
        purpose: OrderPurpose.delivery19l,
        amount: 20000,
        method: PaymentMethod.cash,
        capsules: 2,
        returnedFullCapsules: 1,
        bottleBalance: 4,
      );

      expect(driver.lastReturnedFullCapsules, 1);
      final order = (await MockCrmRepository(store: store).getOrder(open.id))!;
      expect(order.returnedFullCapsules, 1);
      expect(order.capsuleBalanceAfter, 4);
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:crm_millwater/data/repositories/api_driver_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Запросы к новым эндпоинтам заказов.
///
/// Между репозиторием и сервером есть сборка запроса, и потерять параметр
/// может именно она: список молча покажет не то, что просили, и заметить это
/// можно будет только по жалобе.
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

    const order = {
      'id': 'o-1',
      'number': 1,
      'status': 'delivered',
      'purpose': 'pickup',
      'created_at': '2026-08-25T08:00:00Z',
      'customer': {'id': 'c-1', 'full_name': 'Кафе'},
      'route': {'id': 'r-1', 'date': '2026-08-25', 'driver_id': 'd-1'},
    };

    // Карточка заказа приходит объектом, список — конвертом с пагинацией.
    if (options.path.endsWith('/o-1')) {
      return ResponseBody.fromString(
        jsonEncode(order),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({
        'items': [
          {
            'id': 'o-1',
            'number': 1,
            'status': 'delivered',
            'purpose': 'pickup',
            'created_at': '2026-08-25T08:00:00Z',
            'customer': {'id': 'c-1', 'full_name': 'Кафе'},
            'route': {'id': 'r-1', 'date': '2026-08-25', 'driver_id': 'd-1'},
          },
        ],
        'total': 42,
        'page': 1,
        'page_size': 100,
        'pages': 3,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late _RecordingAdapter adapter;
  Dio dio() => Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter;

  setUp(() => adapter = _RecordingAdapter());

  group('Админский список заказов', () {
    test('идёт на /admin/orders со всеми заданными фильтрами', () async {
      final page = await ApiCrmRepository(dio()).getOrdersPage(
        page: 2,
        dateFrom: DateTime(2026, 8, 1),
        dateTo: DateTime(2026, 8, 31),
        customerId: 'c-1',
        driverId: 'd-1',
        routeId: 'r-1',
        status: DeliveryStatus.delivered,
        purpose: OrderPurpose.pickup,
        paymentMethod: PaymentMethod.debt,
        search: '  Кафе  ',
      );

      final request = adapter.requests.single;
      expect(request.path, '/admin/orders');
      expect(request.queryParameters, {
        'date_from': '2026-08-01',
        'date_to': '2026-08-31',
        'customer_id': 'c-1',
        'driver_id': 'd-1',
        'route_id': 'r-1',
        'status': 'delivered',
        'purpose': 'pickup',
        'payment_method': 'debt',
        // Пробелы по краям обрезаются: сервер ищет подстрокой, и « Кафе »
        // не нашёл бы ничего.
        'search': 'Кафе',
        'page': 2,
        'page_size': 100,
      });
      expect(page.total, 42);
      expect(page.items.single.purpose, OrderPurpose.pickup);
    });

    test('пустые фильтры не отправляются вовсе', () async {
      await ApiCrmRepository(dio()).getOrdersPage();

      // У сервера «не фильтровать» — это отсутствие параметра, а не его
      // пустое значение.
      expect(adapter.requests.single.queryParameters, {
        'page': 1,
        'page_size': 100,
      });
    });

    test('карточка заказа берётся по id', () async {
      await ApiCrmRepository(dio()).getOrder('o-1');
      expect(adapter.requests.single.path, '/admin/orders/o-1');
    });
  });

  group('Водительский список заказов', () {
    test('идёт на /driver/orders и водителя не задаёт', () async {
      final page = await ApiDriverRepository(dio()).getMyOrders(
        status: DeliveryStatus.failed,
        search: 'Кафе',
      );

      final request = adapter.requests.single;
      expect(request.path, '/driver/orders');
      // Водителя сервер подставляет из токена: чужой заказ он не отдаст, а
      // параметр `driver_id` у этой ручки не предусмотрен вовсе.
      expect(request.queryParameters.containsKey('driver_id'), isFalse);
      expect(request.queryParameters['status'], 'failed');
      expect(request.queryParameters['page_size'], 100);
      expect(page.items, hasLength(1));
      // Сервер обещает три страницы — значит, есть что догружать.
      expect(page.hasMore, isTrue);
    });

    test('свой заказ берётся по id', () async {
      await ApiDriverRepository(dio()).getMyOrder('o-1');
      expect(adapter.requests.single.path, '/driver/orders/o-1');
    });
  });

  group('Перенос заказа', () {
    test('в существующий маршрут уходит одним полем', () async {
      await ApiCrmRepository(dio()).moveOrderToRoute(
        orderId: 'o-1',
        targetRouteId: 'r-2',
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/admin/orders/o-1/move');
      // Ровно один вариант: тело с маршрутом и датой сразу сервер отвергает.
      expect(request.data, {'target_route_id': 'r-2'});
    });

    test('на дату — датой, и водитель необязателен', () async {
      final repo = ApiCrmRepository(dio());

      await repo.moveOrderToDate(orderId: 'o-1', date: DateTime(2026, 9, 3));
      expect(adapter.requests.last.data, {'order_date': '2026-09-03'});

      await repo.moveOrderToDate(
        orderId: 'o-1',
        date: DateTime(2026, 9, 3),
        driverId: 'd-1',
      );
      // С водителем сервер ищет его маршрут, без него — маршрут вообще без
      // водителя; пустой ключ означал бы третий, несуществующий случай.
      expect(adapter.requests.last.data, {
        'order_date': '2026-09-03',
        'driver_id': 'd-1',
      });
    });
  });

  group('Правка оплаты', () {
    test('уходит multipart-ом со всей суммой заказа', () async {
      await ApiCrmRepository(dio()).updateOrderPayment(
        orderId: 'o-1',
        amount: 115000,
        method: PaymentMethod.cash,
        note: '  доплата наличными  ',
      );

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/admin/orders/o-1/payment');

      final form = request.data as FormData;
      final fields = {for (final f in form.fields) f.key: f.value};
      // Сумма — вся стоимость заказа, а не доплата: разницу с принятыми
      // деньгами сервер считает сам.
      expect(fields['amount'], '115000');
      expect(fields['payment_method'], 'cash');
      // Пробелы по краям в журнал платежей не идут.
      expect(fields['note'], 'доплата наличными');
    });

    test('пустой комментарий не отправляется вовсе', () async {
      await ApiCrmRepository(dio()).updateOrderPayment(
        orderId: 'o-1',
        amount: 0,
        method: PaymentMethod.debt,
        note: '   ',
      );

      final form = adapter.requests.single.data as FormData;
      expect(form.fields.map((f) => f.key), isNot(contains('note')));
    });
  });
}

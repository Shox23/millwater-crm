import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:crm_millwater/data/repositories/api_driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Запросы к эндпоинтам расходов и путь завершения доставки.
///
/// Расход — это деньги из кассы водителя, и ошибка сборки запроса стоит
/// дороже обычной: не тот путь — расход не сохранится, потерянный ключ
/// идемпотентности — спишется дважды.
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

    const expense = {
      'id': 'e-1',
      'route_id': 'r-1',
      'driver_id': 'd-1',
      'amount': '35000.00',
      'category': 'fuel',
      'comment': null,
      'photo_url': null,
      'created_at': '2026-09-02T09:30:00Z',
    };

    // Список админа приходит конвертом с пагинацией, водительский — голым
    // массивом; создание расхода отвечает объектом.
    final Object body = switch (options) {
      _ when options.method == 'POST' => expense,
      _ when options.path.startsWith('/admin/expenses') => {
          'items': [expense],
          'total': 1,
          'page': 1,
          'page_size': 100,
          'pages': 1,
        },
      _ => [expense],
    };

    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://crm.millwater.uz'))
      ..httpClientAdapter = adapter;
  });

  group('Водитель', () {
    test('расход уходит multipart с ключом идемпотентности', () async {
      await ApiDriverRepository(dio).addExpense(
        routeId: 'r-1',
        amount: 35000,
        category: ExpenseCategory.fuel,
        comment: '  АЗС  ',
        idempotencyKey: 'key-1',
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/driver/routes/r-1/expenses');
      // Dio дописывает к типу свой boundary — сверяем начало строки.
      expect(request.contentType, startsWith('multipart/form-data'));
      // Без ключа повтор после обрыва списал бы деньги второй раз.
      expect(request.headers['Idempotency-Key'], 'key-1');

      final form = request.data as FormData;
      final fields = {for (final f in form.fields) f.key: f.value};
      expect(fields['amount'], '35000');
      expect(fields['category'], 'fuel');
      // Комментарий уходит без окружающих пробелов, пустой — не уходит вовсе.
      expect(fields['comment'], 'АЗС');
    });

    test('пустой комментарий не отправляется', () async {
      await ApiDriverRepository(dio).addExpense(
        routeId: 'r-1',
        amount: 1000,
        category: ExpenseCategory.other,
        comment: '   ',
      );

      final form = adapter.requests.single.data as FormData;
      expect(form.fields.any((f) => f.key == 'comment'), isFalse);
    });

    test('свои расходы и удаление ходят по водительским путям', () async {
      final repo = ApiDriverRepository(dio);
      await repo.getRouteExpenses('r-1');
      await repo.deleteExpense('e-1');

      expect(adapter.requests.first.path, '/driver/routes/r-1/expenses');
      expect(adapter.requests.last.method, 'DELETE');
      expect(adapter.requests.last.path, '/driver/expenses/e-1');
    });

    test('завершение доставки уходит на путь заказов, а не точек', () async {
      await ApiDriverRepository(dio).completeDelivery(
        stopId: 'o-1',
        purpose: OrderPurpose.delivery19l,
        capsules: 3,
        amount: 60000,
        bottleBalance: 3,
        method: PaymentMethod.cash,
      );

      // Прежний `/driver/routes/customers/{id}/complete` сервер больше не
      // знает: точки переименованы в заказы, и старый путь отвечает 404.
      expect(adapter.requests.single.path, '/driver/routes/orders/o-1/complete');
    });
  });

  group('Админ', () {
    test('отбор расходов уходит на сервер, а не режет загруженное', () async {
      await ApiCrmRepository(dio).getExpensesPage(
        driverId: 'd-1',
        dateFrom: DateTime(2026, 9, 1),
        dateTo: DateTime(2026, 9, 30),
        category: ExpenseCategory.fuel,
      );

      final query = adapter.requests.single.queryParameters;
      expect(query['driver_id'], 'd-1');
      expect(query['date_from'], '2026-09-01');
      expect(query['date_to'], '2026-09-30');
      expect(query['category'], 'fuel');
    });

    test('расходы маршрута и удаление ходят по админским путям', () async {
      final repo = ApiCrmRepository(dio);
      final expenses = await repo.getRouteExpenses('r-1');
      await repo.deleteExpense('e-1');

      expect(expenses.single.amount, 35000);
      expect(adapter.requests.first.path, '/admin/routes/r-1/expenses');
      expect(adapter.requests.last.path, '/admin/expenses/e-1');
    });
  });

  group('Идемпотентность расхода держится ниже экрана', () {
    test('повтор с тем же ключом не заводит второй расход', () async {
      final repo = MockDriverRepository(driverId: 'd1');
      final first = await repo.addExpense(
        routeId: 'r-1',
        amount: 35000,
        category: ExpenseCategory.fuel,
        idempotencyKey: 'key-1',
      );
      final second = await repo.addExpense(
        routeId: 'r-1',
        amount: 35000,
        category: ExpenseCategory.fuel,
        idempotencyKey: 'key-1',
      );

      // Второе списание из кассы — это потерянные деньги водителя.
      expect(second.id, first.id);
      expect(await repo.getRouteExpenses('r-1'), hasLength(1));
    });

    test('без ключа повтор заводит вторую запись', () async {
      final repo = MockDriverRepository(driverId: 'd1');
      await repo.addExpense(
        routeId: 'r-1',
        amount: 1000,
        category: ExpenseCategory.lunch,
      );
      await repo.addExpense(
        routeId: 'r-1',
        amount: 1000,
        category: ExpenseCategory.lunch,
      );

      expect(await repo.getRouteExpenses('r-1'), hasLength(2));
    });
  });
}

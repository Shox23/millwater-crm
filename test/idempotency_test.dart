import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/models/driver.dart';
import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/drivers/presentation/driver_form_page.dart';
import 'package:dio/dio.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Отдаёт заранее заданный ответ и запоминает заголовки запросов.
class _HeaderSpyAdapter implements HttpClientAdapter {
  _HeaderSpyAdapter(this.bodyFor);

  /// path → тело ответа.
  final Object Function(String path) bodyFor;

  /// Значения `Idempotency-Key` по путям запросов.
  final Map<String, Object?> keys = {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    keys[options.path] = options.headers['Idempotency-Key'];
    return ResponseBody.fromString(
      jsonEncode(bodyFor(options.path)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Первая запись падает, вторая проходит — как обрыв связи и повтор.
class _FlakyRepository extends MockCrmRepository {
  final List<String?> keys = [];
  bool _failNext = true;

  @override
  Future<Driver> addDriver({
    required String fullName,
    required String phone,
    required String password,
    String? idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (_failNext) {
      _failNext = false;
      throw Exception('нет связи');
    }
    return super.addDriver(
      fullName: fullName,
      phone: phone,
      password: password,
      idempotencyKey: idempotencyKey,
    );
  }
}

void main() {
  group('Ключ идемпотентности уходит на сервер', () {
    ApiCrmRepository repositoryWith(_HeaderSpyAdapter adapter) {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      return ApiCrmRepository(dio);
    }

    test('создание заказчика', () async {
      final adapter = _HeaderSpyAdapter(
        (_) => const {
          'id': 'c1',
          'full_name': 'Чайхана',
          'phone': '+998901234567',
          'address': 'Чиланзар, 5',
          'bottle_balance': 0,
          'prepayment': '0.00',
          'debt': '0.00',
          'last_order_date': null,
          'is_active': true,
          'comment': null,
          'created_at': '2026-08-08T10:00:00',
        },
      );

      await repositoryWith(adapter).addCustomer(
        name: 'Чайхана',
        phone: '+998901234567',
        address: 'Чиланзар, 5',
        idempotencyKey: 'customer-1',
      );

      expect(adapter.keys['/admin/customers'], 'customer-1');
    });

    test('создание маршрута', () async {
      final adapter = _HeaderSpyAdapter(
        (_) => const {
          'id': 'r1',
          'date': '2026-08-08',
          'status': 'created',
          'completed_count': 0,
          'total_customers': 0,
          'route_customers': <Object>[],
          'driver_id': 'd1',
          'driver_full_name': 'Азиз Каримов',
        },
      );

      await repositoryWith(adapter).createRoute(
        driverId: 'd1',
        date: DateTime(2026, 8, 8),
        customerIds: const ['c1'],
        idempotencyKey: 'route-1',
      );

      expect(adapter.keys['/admin/routes'], 'route-1');
    });

    test('создание водителя — ключ только на самом создании', () async {
      final adapter = _HeaderSpyAdapter(
        (path) => path == '/admin/drivers'
            ? const {
                'id': 'd9',
                'user_id': 'u9',
                'phone': '+998901234567',
                'email': 'new@aqua.uz',
                'full_name': 'Новый Водитель',
                'trip_count': 0,
                'today_trip_count': 0,
                'created_at': '2026-08-08T10:00:00',
                'updated_at': '2026-08-08T10:00:00',
              }
            : const <String, Object>{},
      );

      await repositoryWith(adapter).addDriver(
        fullName: 'Новый Водитель',
        phone: '+998901234567',
        password: 'secret1',
        idempotencyKey: 'driver-1',
      );

      expect(adapter.keys['/admin/drivers'], 'driver-1');
      // Пароль уходит внутри того же запроса: второго шага больше нет, и
      // `/auth/set-password` на сервере тоже не осталось.
      expect(adapter.keys.containsKey('/auth/set-password'), isFalse);
    });

    test('без ключа заголовок не отправляется', () async {
      final adapter = _HeaderSpyAdapter(
        (_) => const {
          'id': 'c2',
          'full_name': 'Кафе',
          'phone': '+998901234567',
          'address': 'Юнусабад, 1',
          'bottle_balance': 0,
          'prepayment': '0.00',
          'debt': '0.00',
          'last_order_date': null,
          'is_active': true,
          'comment': null,
          'created_at': '2026-08-08T10:00:00',
        },
      );

      await repositoryWith(adapter).addCustomer(
        name: 'Кафе',
        phone: '+998901234567',
        address: 'Юнусабад, 1',
      );

      expect(adapter.keys['/admin/customers'], isNull);
    });
  });

  group('Повтор с тем же ключом не создаёт дубль', () {
    test('водитель заводится один раз', () async {
      final repo = MockCrmRepository();
      final before = (await repo.getDrivers()).length;

      final first = await repo.addDriver(
        fullName: 'Тест Тестов',
        phone: '+998900000000',
        password: 'secret1',
        idempotencyKey: 'driver-42',
      );
      final second = await repo.addDriver(
        fullName: 'Тест Тестов',
        phone: '+998900000000',
        password: 'secret1',
        idempotencyKey: 'driver-42',
      );

      expect(second.id, first.id);
      expect((await repo.getDrivers()).length, before + 1);
    });

    test('другой ключ — другая запись', () async {
      final repo = MockCrmRepository();
      final before = (await repo.getCustomers()).length;

      await repo.addCustomer(
        name: 'Первый',
        phone: '+998900000001',
        address: 'Адрес 1',
        idempotencyKey: 'customer-1',
      );
      await repo.addCustomer(
        name: 'Второй',
        phone: '+998900000002',
        address: 'Адрес 2',
        idempotencyKey: 'customer-2',
      );

      expect((await repo.getCustomers()).length, before + 2);
    });
  });

  group('Форма повторяет отправку тем же ключом', () {
    testWidgets('после сбоя связи водитель не задваивается', (tester) async {
      // В тестах вместо Inter подставляется шрифт тестового рендерера с более
      // широкими глифами — на узком экране подписи кнопок в него не влезают.
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final repo = _FlakyRepository();
      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: MaterialApp(
            // Строки интерфейса берутся из локали: тесты идут на русской.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            theme: AppTheme.light(),
            home: const DriverFormPage(),
          ),
        ),
      );
      // Автофокус первого поля держит мигающий курсор — `pumpAndSettle`
      // такой экран никогда не досчитает.
      await tester.pump(const Duration(milliseconds: 400));

      Finder inputFor(String label) => find.descendant(
            of: find
                .ancestor(of: find.text(label), matching: find.byType(Column))
                .first,
            matching: find.byType(TextField),
          );

      await tester.enterText(inputFor('Имя водителя'), 'Тимур Юсупов');
      await tester.enterText(inputFor('Номер телефона'), '911234567');
      await tester.enterText(inputFor('Пароль для входа'), 'secret1');
      await tester.pump(const Duration(milliseconds: 400));

      // Первая попытка обрывается, экран остаётся с текстом ошибки.
      await tester.tap(find.text('Добавить'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Не удалось сохранить водителя.'), findsOneWidget);

      // Повтор с той же формы.
      await tester.tap(find.text('Добавить'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(repo.keys.length, 2);
      expect(repo.keys.first, isNotNull);
      expect(repo.keys[1], repo.keys.first);
    });
  });
}

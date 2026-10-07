import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/presentation/delivery_completion_page.dart';
import 'package:crm_millwater/features/orders/presentation/order_detail_page.dart';
import 'package:crm_millwater/features/routes/presentation/route_form_page.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/stop_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Договорная цена заказа (`custom_price`): фиксированная сумма за весь
/// заказ, которую админ задаёт при добавлении точки в маршрут.
///
/// Не цена капсулы: сервер при закрытии кладёт её в стоимость как есть,
/// сколько бы капсул ни привезли, и штраф с возвратом к ней не добавляет.
/// Как и задание капсул, ставится один раз — менять точку сервер не умеет.
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
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'r-1',
        'date': '2026-09-16',
        'status': 'created',
        'completed_count': 0,
        'total_customers': 0,
        'orders': <Object>[],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

RouteStop _stop({
  int? customPrice,
  DeliveryStatus status = DeliveryStatus.pending,
  OrderPurpose purpose = OrderPurpose.delivery19l,
}) =>
    RouteStop(
      id: 's-1',
      customerId: 'c-1',
      customerName: 'Кафе Тест',
      customerAddress: 'ул. Тестовая, 1',
      customerPhone: '+998900000002',
      status: status,
      purpose: purpose,
      customPrice: customPrice,
      customerBottleBalance: 3,
      effectiveWaterPrice: 20000,
      damagedBottleFine: 40000,
    );

void main() {
  group('Разбор', () {
    test('точка маршрута и заказ читают custom_price', () {
      final stop = RouteStop.fromJson({
        'id': 's-1',
        'status': 'pending',
        'custom_price': '150000.00',
        'customer': {'id': 'c-1', 'full_name': 'Кафе'},
      });
      expect(stop.customPrice, 150000);

      final order = Order.fromJson({
        'id': 'o-1',
        'number': 1,
        'status': 'delivered',
        'custom_price': '150000.00',
        'created_at': '2026-09-16T08:00:00Z',
        'customer': {'id': 'c-1', 'full_name': 'Кафе'},
      });
      expect(order.customPrice, 150000);
    });

    test('без поля — по прайсу, а не ноль', () {
      final stop = RouteStop.fromJson({
        'id': 's-1',
        'status': 'pending',
        'custom_price': null,
        'customer': {'id': 'c-1', 'full_name': 'Кафе'},
      });
      expect(stop.customPrice, isNull);
    });
  });

  group('Уходит на сервер', () {
    late _RecordingAdapter adapter;
    late ApiCrmRepository repo;

    setUp(() {
      adapter = _RecordingAdapter();
      repo = ApiCrmRepository(
        Dio(BaseOptions(baseUrl: 'https://crm.millwater.uz'))
          ..httpClientAdapter = adapter,
      );
    });

    test('при создании маршрута — только у точек, где задана', () async {
      await repo.createRoute(
        date: DateTime(2026, 9, 16),
        orders: const [
          RouteOrderInput(
              customerId: 'c-1', bottleSellCount: 6, customPrice: 150000),
          RouteOrderInput(customerId: 'c-2', bottleSellCount: 2),
        ],
      );

      final orders = (adapter.requests.single.data
          as Map<String, dynamic>)['customer_orders'] as List;
      expect(orders.first['order_custom_price'], '150000');
      // Без суммы ключа нет вовсе: `null` и отсутствие для сервера одно и
      // то же, а лишний ключ — лишний повод для 422 на старом стенде.
      expect((orders.last as Map).containsKey('order_custom_price'), isFalse);
    });

    test('при добавлении точки в маршрут', () async {
      await repo.addRouteCustomer(
        routeId: 'r-1',
        customerId: 'c-1',
        bottleSellCount: 3,
        customPrice: 90000,
      );

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['order_custom_price'], '90000');
    });
  });

  group('Форма маршрута', () {
    late MockCrmRepository repo;

    setUp(() => repo = MockCrmRepository());

    Future<void> pumpForm(WidgetTester tester, {RouteDetail? route}) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            home: RouteFormPage(route: route),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      final target = find.text(text).first;
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await tester.pump();
    }

    Future<void> addBottles(WidgetTester tester, int count) async {
      final plus = find.byIcon(Icons.add);
      for (var i = 0; i < count; i++) {
        await tester.ensureVisible(plus);
        await tester.pump();
        await tester.tap(plus);
        await tester.pump();
      }
    }

    Finder priceField() => find.descendant(
          of: find
              .ancestor(
                of: find.text('Цена заказа'),
                matching: find.byType(Column),
              )
              .first,
          matching: find.byType(TextField),
        );

    Future<void> enterPrice(WidgetTester tester, String text) async {
      await tester.ensureVisible(priceField());
      await tester.pump();
      await tester.enterText(priceField(), text);
      await tester.pump();
    }

    bool submitEnabled(WidgetTester tester) =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Создать'))
            .enabled;

    testWidgets('поле появляется у выбранной точки доставки', (tester) async {
      await pumpForm(tester);
      expect(find.text('Цена заказа'), findsNothing);

      await tapText(tester, repo.store.customers.first.name);

      expect(find.text('Цена заказа'), findsOneWidget);
    });

    testWidgets('у вывоза поле есть и подсказка про «без оплаты», у опта нет',
        (tester) async {
      await pumpForm(tester);
      await tapText(tester, repo.store.customers.first.name);

      // У вывоза прайса нет: пустое поле — не «по прайсу», а «бесплатно».
      await tapText(tester, 'Вывоз');
      expect(find.text('Цена заказа'), findsOneWidget);
      expect(find.textContaining('вывоз без оплаты'), findsOneWidget);
      expect(find.textContaining('по прайсу'), findsNothing);

      // Опт: цена договорная на бутыль, её вводит водитель на месте.
      await tapText(tester, 'Опт 5/10 л');
      expect(find.text('Цена заказа'), findsNothing);
    });

    testWidgets('у вывоза сумма уходит вместе с новым маршрутом',
        (tester) async {
      await pumpForm(tester);
      await tapText(tester, repo.store.customers.first.name);
      await tapText(tester, 'Вывоз');
      // Без количества вывоз не уходит — как на экране создания.
      await addBottles(tester, 1);
      await enterPrice(tester, '50000');

      await tapText(tester, 'Создать');
      await tester.pump(const Duration(milliseconds: 300));

      final stop = repo.store.routes.last.stops.single;
      expect(stop.purpose, OrderPurpose.pickup);
      expect(stop.customPrice, 50000);
      // У вывоза задание значит «сколько забрать» и уходит вместе с суммой.
      expect(stop.bottleSellCount, 1);
    });

    testWidgets('сумма, набранная у доставки, не держит форму после смены '
        'цели на опт', (tester) async {
      await pumpForm(tester);
      await tapText(tester, repo.store.customers.first.name);
      await addBottles(tester, 2);
      await enterPrice(tester, '0');
      expect(submitEnabled(tester), isFalse);

      // Поле скрылось вместе с ошибкой — и сумма на сервер не уйдёт.
      await tapText(tester, 'Опт 5/10 л');
      expect(submitEnabled(tester), isTrue);

      await tapText(tester, 'Создать');
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.store.routes.last.stops.single.customPrice, isNull);
    });

    testWidgets('пустое поле не мешает сохранить — считается по прайсу',
        (tester) async {
      await pumpForm(tester);
      await tapText(tester, repo.store.customers.first.name);
      await addBottles(tester, 2);

      expect(submitEnabled(tester), isTrue);

      await tapText(tester, 'Создать');
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.store.routes.last.stops.single.customPrice, isNull);
    });

    testWidgets('ноль не сохраняется — сумма должна быть больше нуля',
        (tester) async {
      await pumpForm(tester);
      await tapText(tester, repo.store.customers.first.name);
      await addBottles(tester, 2);

      await enterPrice(tester, '0');

      expect(submitEnabled(tester), isFalse);
      expect(find.text('Сумма должна быть больше нуля'), findsOneWidget);

      await enterPrice(tester, '');
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('сумма уходит вместе с новым маршрутом', (tester) async {
      await pumpForm(tester);
      await tapText(tester, repo.store.customers.first.name);
      await addBottles(tester, 2);
      await enterPrice(tester, '150000');

      await tapText(tester, 'Создать');
      await tester.pump(const Duration(milliseconds: 300));

      final stop = repo.store.routes.last.stops.single;
      expect(stop.customPrice, 150000);
      expect(stop.bottleSellCount, 2);
    });

    testWidgets('у точки, которая уже в маршруте, сумму только показывают',
        (tester) async {
      // Точка с договорной суммой и точка без неё: у второй строки нет
      // вовсе — «по прайсу» обычный случай, о нём не напоминают.
      // Берём точку, чей заказчик стоит в маршруте один раз: у форма один
      // блок на заказчика, и второй заказ того же заказчика перекрыл бы
      // первый.
      final route = repo.store.routes.first;
      final unique = route.stops.firstWhere((s) =>
          route.stops.where((o) => o.customerId == s.customerId).length == 1);
      repo.store.routes[0] = repo.store.copyRoute(
        route,
        stops: [
          for (final s in route.stops)
            s.id == unique.id ? s.copyWith(customPrice: 120000) : s,
        ],
      );

      await pumpForm(tester, route: repo.store.routes.first);

      expect(find.text('Цена заказа'), findsOneWidget);
      expect(find.text('120 000 сум'), findsOneWidget);
      // Поля ввода под подписью нет — только число и пояснение.
      expect(priceField(), findsNothing);
      expect(find.textContaining('сервер менять его не умеет'), findsWidgets);
    });
  });

  group('Показ', () {
    Future<void> pumpStopCard(WidgetTester tester, RouteStop stop) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          home: Scaffold(body: StopCard(stop: stop)),
        ),
      );
      await tester.pump();
    }

    testWidgets('карточка точки — пока точка открыта', (tester) async {
      await pumpStopCard(tester, _stop(customPrice: 150000));
      expect(find.text('Ожидаемая сумма: 150 000 сум'), findsOneWidget);

      await pumpStopCard(
        tester,
        _stop(customPrice: 150000, status: DeliveryStatus.delivered),
      );
      expect(find.text('Ожидаемая сумма: 150 000 сум'), findsNothing);
    });

    testWidgets('карточка заказа — вместо цены капсулы', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      // Сервер кладёт договорную сумму и в `water_price_applied` — строка
      // «цена капсулы 150 000» вводила бы в заблуждение.
      final order = Order(
        id: 'o-1',
        number: 7,
        status: DeliveryStatus.delivered,
        purpose: OrderPurpose.delivery19l,
        customPrice: 150000,
        waterPriceApplied: 150000,
        orderAmount: 150000,
        createdAt: DateTime(2026, 9, 16),
        customerId: 'c-1',
        customerName: 'Кафе',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          home: OrderDetailPage(order: order),
        ),
      );
      await tester.pump();

      expect(find.text('Цена заказа (договорная)'), findsOneWidget);
      expect(find.text('Цена капсулы в заказе'), findsNothing);
    });
  });

  group('Завершение доставки', () {
    late MockDriverRepository repo;

    setUp(() => repo = MockDriverRepository(driverId: 'd1'));

    Future<void> pumpPage(WidgetTester tester, RouteStop stop) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepositoryProvider<DriverRepository>.value(
          value: repo,
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            home: DeliveryCompletionPage(
              stop: stop,
              price: const BuildCapsulePrice(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> tapVisible(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await tester.pump();
    }

    String amountText(WidgetTester tester) => tester
        .widget<TextField>(find.byType(TextField).first)
        .controller!
        .text;

    testWidgets('водитель видит договорную сумму, и она стоит в поле',
        (tester) async {
      await pumpPage(tester, _stop(customPrice: 150000));

      expect(find.text('ЦЕНА ЗАКАЗА'), findsOneWidget);
      expect(find.textContaining('капсулы, брак и возврат её не меняют'),
          findsOneWidget);
      expect(amountText(tester), '150000');
      expect(find.text('По цене заказа: 150 000 сум'), findsOneWidget);
      // Формулы по прайсу нет: считать нечего.
      expect(find.textContaining('По прайсу'), findsNothing);
    });

    testWidgets('счётчики капсул, брака и возврата сумму не двигают',
        (tester) async {
      await pumpPage(tester, _stop(customPrice: 150000));

      // Привезено +2, возврат +1, брак +1 — по прайсу сумма изменилась бы.
      await tapVisible(tester, find.byIcon(Icons.add).at(0));
      await tapVisible(tester, find.byIcon(Icons.add).at(0));
      await tapVisible(tester, find.byIcon(Icons.add).at(2));
      await tapVisible(tester, find.byIcon(Icons.add).at(3));

      expect(amountText(tester), '150000');
    });

    testWidgets('«Вернуть расчёт» возвращает договорную сумму', (tester) async {
      await pumpPage(tester, _stop(customPrice: 150000));

      await tester.enterText(find.byType(TextField).first, '100000');
      await tester.pump();
      expect(find.text('Вернуть расчёт'), findsOneWidget);

      await tapVisible(tester, find.text('Вернуть расчёт'));
      expect(amountText(tester), '150000');
    });

    testWidgets('без договорной суммы блока нет, считается по прайсу',
        (tester) async {
      await pumpPage(tester, _stop());

      expect(find.text('ЦЕНА ЗАКАЗА'), findsNothing);
      expect(amountText(tester), '20000');
      expect(find.textContaining('По прайсу'), findsOneWidget);
    });

    testWidgets('сумма уходит на сервер как есть', (tester) async {
      await pumpPage(tester, _stop(customPrice: 150000));
      await tapVisible(tester, find.text('Завершить'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.lastAmount, 150000);
    });

    group('Вывоз', () {
      testWidgets('сумму видно, но в долг стартует с нуля', (tester) async {
        await pumpPage(
          tester,
          _stop(purpose: OrderPurpose.pickup, customPrice: 50000),
        );

        expect(find.text('ЦЕНА ЗАКАЗА'), findsOneWidget);
        expect(find.textContaining('кулеры, капсулы и брак её не меняют'),
            findsOneWidget);
        // Способ по умолчанию «в долг», а с ним сервер принимает только
        // ноль — сумма подставится, когда водитель уйдёт с долга.
        expect(amountText(tester), '0');
        expect(find.text('Уйдёт в долг'), findsOneWidget);
        expect(find.text('50 000 сум'), findsWidgets);
      });

      testWidgets('переход на наличные подставляет договорную сумму',
          (tester) async {
        await pumpPage(
          tester,
          _stop(purpose: OrderPurpose.pickup, customPrice: 50000),
        );

        // Кулер забран — иначе первой стоит блокирующая подсказка «Укажите,
        // что забрали», и до подсказки о сумме дело не доходит.
        await tapVisible(tester, find.byIcon(Icons.add).first);
        await tapVisible(tester, find.text('Наличные'));

        expect(amountText(tester), '50000');
        expect(find.text('По цене заказа: 50 000 сум'), findsOneWidget);
        // Подсказка про договорённость на месте — не для вывоза с ценой.
        expect(find.textContaining('по договорённости'), findsNothing);
        expect(find.text('Вернуть расчёт'), findsNothing);

        await tapVisible(tester, find.text('Завершить'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(repo.lastPurpose, OrderPurpose.pickup);
        expect(repo.lastAmount, 50000);
        expect(repo.lastMethod, PaymentMethod.cash);
      });

      testWidgets('счётчики кулеров, капсул и брака сумму не двигают',
          (tester) async {
        await pumpPage(
          tester,
          _stop(purpose: OrderPurpose.pickup, customPrice: 50000),
        );
        await tapVisible(tester, find.text('Наличные'));

        await tapVisible(tester, find.byIcon(Icons.add).at(0));
        await tapVisible(tester, find.byIcon(Icons.add).at(1));
        await tapVisible(tester, find.byIcon(Icons.add).at(2));

        expect(amountText(tester), '50000');
      });

      testWidgets('без цены водителю не велят оставлять ноль', (tester) async {
        await pumpPage(tester, _stop(purpose: OrderPurpose.pickup));

        expect(find.text('ЦЕНА ЗАКАЗА'), findsNothing);
        expect(amountText(tester), '0');

        // Взял деньги за вывоз по договорённости на месте — экран это не
        // оспаривает.
        await tapVisible(tester, find.byIcon(Icons.add).first);
        await tapVisible(tester, find.text('Наличные'));
        await tester.enterText(find.byType(TextField).first, '30000');
        await tester.pump();

        expect(find.textContaining('по договорённости'), findsOneWidget);
        expect(find.textContaining('оставьте сумму нулевой'), findsNothing);
      });
    });
  });
}

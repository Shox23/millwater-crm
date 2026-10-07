import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/core/widgets/quantity_stepper.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/presentation/delivery_completion_page.dart';
import 'package:crm_millwater/features/routes/presentation/route_form_page.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/stop_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Задание к доставке (`bottle_sell_count`): сколько капсул админ велел
/// привезти заказчику.
///
/// Это план, а не факт: сколько привезли на самом деле, водитель отмечает сам
/// при завершении. Поэтому число задаётся один раз — при добавлении точки в
/// маршрут: менять его у существующей точки сервер не умеет, у него есть
/// только создание, удаление и правка порядка объезда.
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
        'date': '2026-09-08',
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

void main() {
  group('Разбор', () {
    test('точка маршрута читает задание', () {
      final stop = RouteStop.fromJson({
        'id': 's-1',
        'status': 'pending',
        'purpose': 'delivery_19l',
        'bottle_sell_count': 6,
        'customer': {'customer_full_name': 'Кафе Тест'},
      });

      expect(stop.bottleSellCount, 6);
    });

    test('заказ читает задание', () {
      final order = Order.fromJson({
        'id': 'o-1',
        'number': 12,
        'status': 'pending',
        'purpose': 'delivery_19l',
        'created_at': '2026-09-08T08:00:00Z',
        'bottle_sell_count': 4,
        'customer': {'customer_full_name': 'Кафе Тест'},
        'route': {'route_id': 'r-1', 'route_date': '2026-09-08'},
      });

      expect(order.bottleSellCount, 4);
    });

    test('без поля задания нет — это не ноль', () {
      // У заказов, заведённых до появления поля, задания не ставили. Ноль
      // означал бы «привезти ноль капсул», а это другое.
      final stop = RouteStop.fromJson({'id': 's-1', 'status': 'pending'});

      expect(stop.bottleSellCount, isNull);
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

    test('при создании маршрута — вместе с точкой', () async {
      await repo.createRoute(
        date: DateTime(2026, 9, 8),
        orders: const [
          RouteOrderInput(customerId: 'c-1', bottleSellCount: 6),
          RouteOrderInput(
            customerId: 'c-2',
            purpose: OrderPurpose.pickup,
          ),
        ],
      );

      final orders = (adapter.requests.single.data
          as Map<String, dynamic>)['customer_orders'] as List;
      expect(orders.first['bottle_sell_count'], 6);
      // У вывоза везти нечего — ключа нет вовсе, иначе сервер получил бы
      // задание к доставке у заказа, где доставки не будет.
      expect((orders.last as Map).containsKey('bottle_sell_count'), isFalse);
    });

    test('при добавлении точки в маршрут', () async {
      await repo.addRouteCustomer(
        routeId: 'r-1',
        customerId: 'c-1',
        bottleSellCount: 3,
      );

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['bottle_sell_count'], 3);
    });
  });

  group('Остаток капсул заказчика уходит на сервер', () {
    late _RecordingAdapter adapter;
    late ApiCrmRepository repo;

    setUp(() {
      adapter = _RecordingAdapter();
      repo = ApiCrmRepository(
        Dio(BaseOptions(baseUrl: 'https://crm.millwater.uz'))
          ..httpClientAdapter = adapter,
      );
    });

    test('при создании заказчика', () async {
      await repo.addCustomer(
        name: 'Кафе Тест',
        phone: '998900000002',
        address: 'ул. Тестовая, 1',
        capsuleBalance: 4,
      );

      final body = adapter.requests.single.data as Map<String, dynamic>;
      // Новый заказчик приходит со своей тарой от прежнего поставщика.
      expect(body['bottle_balance'], 4);
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

    /// Прибавляет задание нажатиями «+» — счётчик тот же, что у водителя.
    Future<void> addBottles(WidgetTester tester, int count) async {
      final plus = find.descendant(
        of: find.byType(QuantityStepper),
        matching: find.byIcon(Icons.add),
      );
      for (var i = 0; i < count; i++) {
        await tester.ensureVisible(plus);
        await tester.pump();
        await tester.tap(plus);
        await tester.pump();
      }
    }

    bool submitEnabled(WidgetTester tester) =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Создать'))
            .enabled;

    testWidgets('поле появляется у выбранной точки доставки', (tester) async {
      await pumpForm(tester);
      expect(find.byType(QuantityStepper), findsNothing);

      await tapText(tester, repo.store.customers.first.name);

      expect(find.text('КАПСУЛ К ДОСТАВКЕ'), findsOneWidget);
      expect(find.byType(QuantityStepper), findsOneWidget);
    });

    testWidgets('доставка без задания не сохраняется', (tester) async {
      await pumpForm(tester);
      await tapText(tester, repo.store.customers.first.name);

      // Водитель иначе не узнает, сколько везти, а дописать число потом
      // сервер не даст.
      expect(submitEnabled(tester), isFalse);
      expect(find.textContaining('Укажите, сколько капсул'), findsOneWidget);

      await addBottles(tester, 1);

      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('у вывоза спрашивают, сколько забрать', (tester) async {
      await pumpForm(tester);
      await tapText(tester, repo.store.customers.first.name);
      await tapText(tester, 'Вывоз');

      // Поле то же, что у доставки, но подписи свои: число значит «забрать».
      // И, как на экране создания, без него точка не уходит.
      expect(find.text('КАПСУЛ К ВЫВОЗУ'), findsOneWidget);
      expect(find.byType(QuantityStepper), findsOneWidget);
      expect(find.text('Укажите, сколько капсул забрать'), findsOneWidget);
      expect(submitEnabled(tester), isFalse);

      await addBottles(tester, 2);

      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('у опта задания не спрашивают', (tester) async {
      await pumpForm(tester);
      await tapText(tester, repo.store.customers.first.name);
      await tapText(tester, 'Опт 5/10 л');

      // Бутыли 5/10 л считает водитель на месте — передать их нечем.
      expect(find.byType(QuantityStepper), findsNothing);
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('вывоз, добавленный в маршрут, уходит со своим количеством',
        (tester) async {
      final route = repo.store.routes.firstWhere(
        (r) => r.status.canAddCustomers,
      );
      final customer = repo.store.customers.firstWhere(
        (c) => !route.stops.any((s) => s.customerId == c.id),
      );
      await pumpForm(tester, route: route);

      await tapText(tester, customer.name);
      await tapText(tester, 'Вывоз');
      await addBottles(tester, 2);
      await tapText(tester, 'Сохранить');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Раньше форма правки отправляла количество только у доставки, и вывоз,
      // досыпанный в готовый маршрут, приходил к водителю без задания.
      final added = repo.store.routes
          .firstWhere((r) => r.id == route.id)
          .stops
          .singleWhere((s) => s.customerId == customer.id);
      expect(added.purpose, OrderPurpose.pickup);
      expect(added.bottleSellCount, 2);
    });

    testWidgets('задание уходит вместе с новым маршрутом', (tester) async {
      await pumpForm(tester);
      await tapText(tester, repo.store.customers.first.name);
      await addBottles(tester, 3);

      await tapText(tester, 'Создать');
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.store.routes.last.stops.single.bottleSellCount, 3);
    });

    testWidgets('у точки, которая уже в маршруте, задание только показывают',
        (tester) async {
      final route = repo.store.routes.first;
      await pumpForm(tester, route: route);

      // Менять `bottle_sell_count` сервер не умеет — вместо инпута строка с
      // пояснением, иначе экран обещал бы правку, которой нет.
      expect(find.textContaining('сервер менять его не умеет'), findsWidgets);
    });
  });

  group('Водитель видит задание', () {
    testWidgets('в карточке точки', (tester) async {
      final stop = RouteStop(
        id: 's-1',
        customerId: 'c-1',
        customerName: 'Кафе Тест',
        customerAddress: 'ул. Тестовая, 1',
        customerPhone: '+998900000002',
        status: DeliveryStatus.pending,
        bottleSellCount: 5,
      );

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

      expect(find.text('Ожидаемое кол-во капсул: 5'), findsOneWidget);
    });

    testWidgets('на экране завершения, над счётчиками', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final stop = RouteStop(
        id: 's-1',
        customerId: 'c-1',
        customerName: 'Кафе Тест',
        customerAddress: 'ул. Тестовая, 1',
        customerPhone: '+998900000002',
        status: DeliveryStatus.pending,
        bottleSellCount: 5,
        effectiveWaterPrice: 20000,
      );

      await tester.pumpWidget(
        RepositoryProvider<DriverRepository>.value(
          value: MockDriverRepository(driverId: 'd1'),
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            home: DeliveryCompletionPage(stop: stop),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('НАЗНАЧЕНО К ДОСТАВКЕ'), findsOneWidget);
      expect(find.text('5 капсул'), findsOneWidget);

      // Новых полей ввода у водителя не появилось: счётчики те же, что были.
      expect(find.text('КОЛИЧЕСТВО КАПСУЛ'), findsOneWidget);
    });

    testWidgets('без задания блок не показывается', (tester) async {
      final stop = RouteStop(
        id: 's-1',
        customerId: 'c-1',
        customerName: 'Кафе Тест',
        customerAddress: 'ул. Тестовая, 1',
        customerPhone: '+998900000002',
        status: DeliveryStatus.pending,
      );

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

      expect(find.textContaining('Ожидаемое кол-во капсул'), findsNothing);
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/mock/mock_store.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/network/api_envelope.dart';
import 'package:crm_millwater/data/repositories/api_driver_repository.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/presentation/my_route_detail_page.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/stop_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Водитель добавляет заказ в свой маршрут (сервер с 2026-10-11).
///
/// Две ручки: поиск заказчиков `GET /driver/customers` и добавление
/// `POST /driver/{routeId}/customers/{customerId}` — та же схема
/// `AddRouteCustomer`, что у админа. Статус маршрута сервер не проверяет,
/// поэтому кнопка есть только у маршрута в работе; ключа идемпотентности
/// нет, и повтор после обрыва связи упирается в 409.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter([this.body = '']);

  /// Тело ответа; пустое — 204, как у добавления.
  final String body;
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
    if (body.isEmpty) return ResponseBody.fromString('', 204);
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

/// Отказ сервера с кодом в конверте `{error: {code, message}}`.
DioException _apiError(int status, String code) {
  final options = RequestOptions(path: '/driver/r1/customers/c3');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: {
        'error': {'code': code, 'message': 'x'}
      },
    ),
  );
}

/// Мок, у которого добавление отвечает отказом сервера.
class _RejectingRepository extends MockDriverRepository {
  _RejectingRepository(this.error, {super.store});

  final DioException error;

  @override
  Future<void> addRouteOrder({
    required String routeId,
    required String customerId,
    required OrderPurpose purpose,
    int? bottleSellCount,
    int? customPrice,
    String? comment,
  }) async {
    throw error;
  }
}

void main() {
  group('Запросы', () {
    late _RecordingAdapter adapter;

    ApiDriverRepository repo([String body = '']) {
      adapter = _RecordingAdapter(body);
      return ApiDriverRepository(
        Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter,
      );
    }

    test('поиск — GET /driver/customers со страницей и обрезанным запросом',
        () async {
      final page = await repo(jsonEncode({
        'items': [
          {
            'id': 'c1',
            'full_name': 'Кафе «Nasiba»',
            'phone': '+998 71 200 11 22',
            'phone_secondary': null,
            'address': 'ул. Амир Темур, 12',
            'comment': 'Мирабад',
          },
        ],
        'total': 150,
        'page': 1,
        'page_size': 100,
        'pages': 2,
      })).getCustomersPage(search: '  Темур ');

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/driver/customers');
      expect(request.queryParameters,
          {'page': 1, 'page_size': 100, 'search': 'Темур'});

      final customer = page.items.single;
      expect(customer.name, 'Кафе «Nasiba»');
      expect(customer.address, 'ул. Амир Темур, 12');
      expect(customer.comment, 'Мирабад');
      expect(page.hasMore, isTrue);
      expect(page.total, 150);
    });

    test('пустой запрос сервер не получает', () async {
      await repo(jsonEncode({'items': [], 'total': 0, 'pages': 0}))
          .getCustomersPage(page: 2, search: '   ');

      expect(adapter.requests.single.queryParameters,
          {'page': 2, 'page_size': 100});
    });

    test('доставка — количество, договорная сумма и комментарий; номера нет',
        () async {
      await repo().addRouteOrder(
        routeId: 'r-1',
        customerId: 'c-1',
        purpose: OrderPurpose.delivery19l,
        bottleSellCount: 3,
        customPrice: 150000,
        comment: 'до обеда',
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/driver/r-1/customers/c-1');
      // Без `sequence`: точка без номера встаёт в конец объезда.
      expect(request.data, {
        'customer_id': 'c-1',
        'order_purpose': 'delivery_19l',
        'bottle_sell_count': 3,
        'order_custom_price': '150000',
        'comment': 'до обеда',
      });
    });

    test('опт без количества, суммы и комментария — лишних ключей нет',
        () async {
      await repo().addRouteOrder(
        routeId: 'r-1',
        customerId: 'c-1',
        purpose: OrderPurpose.bulkWater,
      );

      expect(adapter.requests.single.data, {
        'customer_id': 'c-1',
        'order_purpose': 'bulk_water',
      });
    });
  });

  group('Тексты ошибок', () {
    late AppLocalizations ru;

    setUpAll(() async {
      ru = await AppLocalizations.delegate.load(AppLocales.ru);
    });

    test('дубль, отключённый заказчик и пропавший маршрут — по коду', () {
      expect(
        apiErrorMessage(ru, _apiError(409, 'CUSTOMER_ALREADY_IN_ROUTE')),
        'Этот заказчик уже есть в маршруте',
      );
      expect(
        apiErrorMessage(ru, _apiError(404, 'CUSTOMER_NOT_FOUND')),
        'Заказчик не найден или отключён',
      );
      expect(
        apiErrorMessage(ru, _apiError(404, 'ROUTE_NOT_FOUND')),
        'Запись не найдена',
      );
    });
  });

  group('Мок', () {
    test('поиск — только активные, по адресу и второму телефону', () async {
      final store = MockStore();
      final repo = MockDriverRepository(store: store);

      final byAddress = await repo.getCustomersPage(search: 'чиланзар');
      expect(byAddress.items.map((c) => c.name), ['Дилноза Хамидова']);

      final bySecondPhone = await repo.getCustomersPage(search: '1002030');
      expect(bySecondPhone.items.map((c) => c.name), ['Офис «Baraka»']);

      final index = store.customers.indexWhere((c) => c.id == 'c3');
      store.customers[index] = store.customers[index].copyWith(isActive: false);
      final all = await repo.getCustomersPage();
      expect(all.items.map((c) => c.id), isNot(contains('c3')));
    });

    test('добавленный заказ встаёт в конец маршрута с заданием и суммой',
        () async {
      final store = MockStore();
      final repo = MockDriverRepository(store: store);

      await repo.addRouteOrder(
        routeId: 'r1',
        customerId: 'c3',
        purpose: OrderPurpose.pickup,
        bottleSellCount: 4,
        customPrice: 30000,
        comment: 'забрать кулер',
      );

      final stop = store.routes.firstWhere((r) => r.id == 'r1').stops.last;
      expect(stop.customerId, 'c3');
      expect(stop.status, DeliveryStatus.pending);
      expect(stop.purpose, OrderPurpose.pickup);
      expect(stop.bottleSellCount, 4);
      expect(stop.customPrice, 30000);
      expect(stop.comment, 'забрать кулер');
      expect(stop.sequence, isNull);
    });
  });

  group('Экран водителя', () {
    /// Третий шаг — ради закрытия экранов, начатого посреди второго: анимация
    /// отсчитывает время от первого кадра после старта, и без него уезжающие
    /// форма и выбор заказчика оставались бы в дереве — со своей копией
    /// сообщения в каждом `Scaffold`.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> pumpRoute(
      WidgetTester tester,
      DriverRepository repo, {
      String routeId = 'r1',
    }) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<DriverRepository>.value(value: repo),
            RepositoryProvider<CapsulePrice>.value(
              value: const BuildCapsulePrice(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            home: MyRouteDetailPage(routeId: routeId),
          ),
        ),
      );
      await settle(tester);
    }

    final addButton = find.widgetWithText(AppButton, 'Добавить заказ');
    final submitButton = find.widgetWithText(AppButton, 'Добавить в маршрут');

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
      await settle(tester);
    }

    testWidgets('кнопка есть только у маршрута в работе', (tester) async {
      final store = MockStore();
      await pumpRoute(tester, MockDriverRepository(store: store));
      expect(addButton, findsOneWidget);

      // Закрытый маршрут водитель видит как историю — добавлять в него нечего,
      // хотя сервер статус и не проверяет. Пустой кадр между — чтобы экран
      // собрался заново и перечитал маршрут, а не сохранил прежнее состояние.
      store.completeRoute('r1');
      await tester.pumpWidget(const SizedBox());
      await pumpRoute(tester, MockDriverRepository(store: store));
      expect(addButton, findsNothing);
    });

    testWidgets('кто уже в маршруте, помечен и не выбирается', (tester) async {
      await pumpRoute(tester, MockDriverRepository(store: MockStore()));
      await tap(tester, addButton);

      expect(find.text('Новый заказ'), findsOneWidget);
      // В r1 — «Nasiba» (дважды) и «Zebo».
      expect(find.text('Уже в маршруте'), findsNWidgets(2));

      await tap(tester, find.text('Кафе «Nasiba»'));
      expect(submitButton, findsNothing);
    });

    testWidgets('поиск уходит на сервер после паузы в наборе', (tester) async {
      await pumpRoute(tester, MockDriverRepository(store: MockStore()));
      await tap(tester, addButton);
      expect(find.text('Магазин «Osiyo»'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Чиланзар');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester);

      expect(find.text('Дилноза Хамидова'), findsOneWidget);
      expect(find.text('Магазин «Osiyo»'), findsNothing);
    });

    testWidgets('вывоз с количеством, суммой и комментарием — точка в конце',
        (tester) async {
      final store = MockStore();
      final repo = MockDriverRepository(store: store);
      await pumpRoute(tester, repo);
      await tap(tester, addButton);
      await tap(tester, find.text('Дилноза Хамидова'));

      // Форма открылась на доставке с одной капсулой; цены заказчика у
      // водителя нет — подсказка без числа.
      expect(submitButton, findsOneWidget);
      expect(find.text('по цене заказчика'), findsOneWidget);

      await tap(tester, find.text('Вывоз'));
      expect(find.text('Сколько капсул забрать'), findsOneWidget);
      await tap(tester, find.text('5'));

      final price = find.widgetWithText(TextField, 'Без оплаты');
      await tester.ensureVisible(price);
      await tester.enterText(price, '30000');
      await settle(tester);

      final comment =
          find.widgetWithText(TextField, 'Например: просили привезти до обеда');
      await tester.ensureVisible(comment);
      await tester.enterText(comment, '  забрать кулер ');
      await settle(tester);

      await tap(tester, submitButton);

      final sent = repo.lastAddedOrder!;
      expect(sent.routeId, 'r1');
      expect(sent.customerId, 'c3');
      expect(sent.purpose, OrderPurpose.pickup);
      expect(sent.qty, 5);
      expect(sent.price, 30000);
      expect(sent.comment, 'забрать кулер');

      // Вернулись на маршрут, он перечитан, точка — последней.
      expect(find.text('Заказ добавлен в маршрут'), findsOneWidget);
      expect(addButton, findsOneWidget);
      expect(find.widgetWithText(StopCard, 'Дилноза Хамидова'), findsOneWidget);
      expect(
        store.routes.firstWhere((r) => r.id == 'r1').stops.last.customerId,
        'c3',
      );
    });

    testWidgets('опт уходит без количества, ноль в сумме форму не отпускает',
        (tester) async {
      final repo = MockDriverRepository(store: MockStore());
      await pumpRoute(tester, repo);
      await tap(tester, addButton);
      await tap(tester, find.text('Магазин «Osiyo»'));

      await tap(tester, find.text('Опт 5/10 л'));
      expect(find.text('Сколько капсул везти'), findsNothing);

      final price = find.widgetWithText(TextField, 'цена на месте');
      await tester.ensureVisible(price);
      await tester.enterText(price, '0');
      await settle(tester);
      expect(tester.widget<AppButton>(submitButton).enabled, isFalse);

      await tester.enterText(price, '');
      await settle(tester);
      await tap(tester, submitButton);

      final sent = repo.lastAddedOrder!;
      expect(sent.purpose, OrderPurpose.bulkWater);
      expect(sent.qty, isNull);
      expect(sent.price, isNull);
    });

    testWidgets('409 «уже в маршруте» — не ошибка формы: назад к маршруту',
        (tester) async {
      final repo = _RejectingRepository(
        _apiError(409, 'CUSTOMER_ALREADY_IN_ROUTE'),
        store: MockStore(),
      );
      await pumpRoute(tester, repo);
      await tap(tester, addButton);
      await tap(tester, find.text('Дилноза Хамидова'));
      await tap(tester, submitButton);

      expect(submitButton, findsNothing);
      expect(addButton, findsOneWidget);
      expect(find.text('Этот заказчик уже есть в маршруте'), findsOneWidget);
    });

    testWidgets('иной отказ оставляет форму заполненной и объясняет причину',
        (tester) async {
      final repo = _RejectingRepository(
        _apiError(404, 'CUSTOMER_NOT_FOUND'),
        store: MockStore(),
      );
      await pumpRoute(tester, repo);
      await tap(tester, addButton);
      await tap(tester, find.text('Дилноза Хамидова'));
      await tap(tester, submitButton);

      expect(submitButton, findsOneWidget);
      expect(tester.widget<AppButton>(submitButton).enabled, isTrue);
      expect(find.text('Заказчик не найден или отключён'), findsOneWidget);
    });
  });
}

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/presentation/delivery_completion_page.dart';
import 'package:crm_millwater/features/routes/presentation/route_create_page.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_customer_row.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_stop_card.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/stop_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Комментарий к точке маршрута: админ пишет — водитель читает.
///
/// Поле необязательное и живёт у заказа (`comment`, колонка на 255 символов).
/// Задаётся только при добавлении точки: правки комментария у сервера нет,
/// как нет её у задания в капсулах и договорной цены.
void main() {
  group('Разбор ответа', () {
    Map<String, dynamic> stopJson(Object? comment) => {
          'id': 's-1',
          'customer_id': 'c-1',
          'customer_full_name': 'Кафе',
          'status': 'pending',
          'comment': comment,
        };

    test('комментарий точки читается', () {
      expect(RouteStop.fromJson(stopJson('Ключ у охраны')).comment,
          'Ключ у охраны');
    });

    test('пустой комментарий — это его отсутствие', () {
      // Иначе карточка показывала бы пустую плашку «Комментарий».
      expect(RouteStop.fromJson(stopJson('')).comment, isNull);
      expect(RouteStop.fromJson(stopJson('   ')).comment, isNull);
      expect(RouteStop.fromJson(stopJson(null)).comment, isNull);
    });

    test('пробелы по краям срезаются', () {
      expect(RouteStop.fromJson(stopJson('  позвонить  ')).comment,
          'позвонить');
    });

    test('заказ читает то же поле', () {
      final order = Order.fromJson({
        'id': 'o-1',
        'order_number': 3,
        'status': 'pending',
        'created_at': '2026-09-28T08:00:00Z',
        'customer_id': 'c-1',
        'customer_full_name': 'Кафе',
        'comment': 'Позвонить с парковки',
      });

      expect(order.comment, 'Позвонить с парковки');
    });

    test('копия точки комментарий не теряет', () {
      // Демо-режим пересобирает точку на каждом изменении статуса.
      final stop = RouteStop.fromJson(stopJson('Ключ у охраны'));

      expect(stop.copyWith(status: DeliveryStatus.delivered).comment,
          'Ключ у охраны');
    });
  });

  group('Админ пишет комментарий', () {
    testWidgets('комментарий уходит вместе с новым маршрутом', (tester) async {
      final repo = _CreatingRepository();
      tester.view.physicalSize = const Size(1440, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            home: const RouteCreatePage(),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      const name = 'Дилноза Хамидова';
      await tester.tap(find.widgetWithText(RouteCreateCustomerRow, name));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      // Раскрываем точку: комментарий — часть её редактирования.
      await tester.tap(find.descendant(
        of: find.widgetWithText(RouteCreateStopCard, name),
        matching: find.text(name),
      ));
      await tester.pump();

      final field = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Например: позвонить с парковки',
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, '  Позвонить с парковки  ');
      await tester.pump();

      // В свёрнутом виде комментарий тоже видно — исправить его после
      // создания нечем, и забывать о нём нельзя.
      await tester.tap(find.descendant(
        of: find.widgetWithText(RouteCreateStopCard, name),
        matching: find.text(name),
      ));
      await tester.pump();
      expect(
        find.descendant(
          of: find.widgetWithText(RouteCreateStopCard, name),
          matching: find.text('Позвонить с парковки'),
        ),
        findsOneWidget,
      );

      final button = find.widgetWithText(AppButton, 'Создать маршрут · 1');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Пробелы по краям на сервер не уходят.
      expect(repo.sent.single.comment, 'Позвонить с парковки');
    });

    testWidgets('без комментария поле ничего не отправляет', (tester) async {
      final repo = _CreatingRepository();
      tester.view.physicalSize = const Size(1440, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            home: const RouteCreatePage(),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      await tester.tap(
        find.widgetWithText(RouteCreateCustomerRow, 'Дилноза Хамидова'),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      final button = find.widgetWithText(AppButton, 'Создать маршрут · 1');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // `null`, а не пустая строка: пустой комментарий и отсутствие
      // комментария — разные вещи и для сервера, и для карточки.
      expect(repo.sent.single.comment, isNull);
    });

    test('комментарий уходит и при добавлении точки в готовый маршрут',
        () async {
      // Ручка добавления — единственный способ задать комментарий у точки,
      // которую досыпают в уже собранный маршрут.
      final repo = MockCrmRepository();
      final route = await repo.createRoute(
        date: DateTime(2026, 9, 29),
        orders: const [RouteOrderInput(customerId: 'c1', bottleSellCount: 3)],
      );

      await repo.addRouteCustomer(
        routeId: route.id,
        customerId: 'c2',
        bottleSellCount: 2,
        comment: 'Ключ у охраны',
      );

      final updated = await repo.getRoute(route.id);
      final added = updated!.stops.firstWhere((s) => s.customerId == 'c2');
      expect(added.comment, 'Ключ у охраны');
    });
  });

  group('Водитель читает комментарий', () {
    RouteStop stopWith(String? comment) => RouteStop(
          id: 's-1',
          customerId: 'c-1',
          customerName: 'Кафе «Nasiba»',
          customerAddress: 'ул. Амир Темур, 12',
          customerPhone: '+998 71 200 11 22',
          status: DeliveryStatus.pending,
          bottleSellCount: 3,
          comment: comment,
        );

    Future<void> pumpStopCard(WidgetTester tester, RouteStop stop) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

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

    testWidgets('в карточке точки — и у водителя, и у админа', (tester) async {
      // Карточка общая: один и тот же виджет стоит в списке точек у водителя
      // и в маршруте у админа.
      await pumpStopCard(tester, stopWith('Ключ у охраны'));

      expect(find.text('Ключ у охраны'), findsOneWidget);
    });

    testWidgets('без комментария плашки нет', (tester) async {
      await pumpStopCard(tester, stopWith(null));

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);
    });

    testWidgets('на экране завершения доставки — над счётчиками',
        (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepositoryProvider<DriverRepository>.value(
          value: MockDriverRepository(driverId: 'd1'),
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            home: DeliveryCompletionPage(
              stop: stopWith('Позвонить с парковки'),
              price: const BuildCapsulePrice(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Комментарий'), findsOneWidget);
      expect(find.text('Позвонить с парковки'), findsOneWidget);
    });
  });
}

/// Запоминает, с чем ушёл созданный маршрут.
class _CreatingRepository extends MockCrmRepository {
  List<RouteOrderInput> sent = const [];

  @override
  Future<RouteDetail> createRoute({
    required DateTime date,
    required List<RouteOrderInput> orders,
    String? driverId,
    OrderPurpose purpose = OrderPurpose.delivery19l,
    String? idempotencyKey,
  }) {
    sent = List.of(orders);
    return super.createRoute(
      date: date,
      orders: orders,
      driverId: driverId,
      purpose: purpose,
      idempotencyKey: idempotencyKey,
    );
  }
}

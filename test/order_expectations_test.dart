import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/features/desktop/bloc/day_deliveries_bloc.dart';
import 'package:crm_millwater/features/desktop/overlays/drawer_contents.dart';
import 'package:crm_millwater/features/desktop/theme/desktop_theme.dart';
import 'package:crm_millwater/features/orders/presentation/order_detail_page.dart';
import 'package:crm_millwater/features/orders/presentation/widgets/order_card.dart';
import 'package:crm_millwater/features/routes/presentation/stop_detail_page.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/stop_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Задание админа к заказу — «Ожидаемое кол-во капсул» и «Ожидаемая
/// сумма» — на всех карточках незакрытого заказа, у обеих ролей и на обеих
/// платформах. У закрытого заказа этих строк нет: его описывает факт.
RouteStop _stop({
  DeliveryStatus status = DeliveryStatus.pending,
  int? bottleSellCount = 5,
  int? customPrice = 150000,
}) =>
    RouteStop(
      id: 's-1',
      customerId: 'c-1',
      customerName: 'Кафе Тест',
      customerAddress: 'ул. Тестовая, 1',
      customerPhone: '+998900000002',
      status: status,
      bottleSellCount: bottleSellCount,
      customPrice: customPrice,
    );

Order _order({
  DeliveryStatus status = DeliveryStatus.pending,
  int? bottleSellCount = 5,
  int? customPrice = 150000,
}) =>
    Order(
      id: 'o-1',
      number: 7,
      status: status,
      purpose: OrderPurpose.delivery19l,
      bottleSellCount: bottleSellCount,
      customPrice: customPrice,
      createdAt: DateTime(2026, 9, 18),
      customerId: 'c-1',
      customerName: 'Кафе Тест',
    );

void main() {
  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocales.supported,
        locale: AppLocales.ru,
        home: page,
      ),
    );
    await tester.pump();
  }

  const capsules = 'Ожидаемое кол-во капсул: 5';
  const amount = 'Ожидаемая сумма: 150 000 сум';

  group('Карточка точки маршрута', () {
    testWidgets('обе строки у открытой точки', (tester) async {
      await pump(tester, Scaffold(body: StopCard(stop: _stop())));

      expect(find.text(capsules), findsOneWidget);
      expect(find.text(amount), findsOneWidget);
    });

    testWidgets('у закрытой и отменённой строк нет', (tester) async {
      await pump(
        tester,
        Scaffold(body: StopCard(stop: _stop(status: DeliveryStatus.delivered))),
      );
      expect(find.textContaining('Ожидаем'), findsNothing);

      await pump(
        tester,
        Scaffold(body: StopCard(stop: _stop(status: DeliveryStatus.cancelled))),
      );
      expect(find.textContaining('Ожидаем'), findsNothing);
    });

    testWidgets('без задания и суммы — ничего, ноль капсул тоже «нет»',
        (tester) async {
      await pump(
        tester,
        Scaffold(
          body: StopCard(stop: _stop(bottleSellCount: 0, customPrice: null)),
        ),
      );
      expect(find.textContaining('Ожидаем'), findsNothing);
    });
  });

  group('Запасная карточка точки у админа', () {
    testWidgets('у открытой точки — те же строки', (tester) async {
      await pump(tester, StopDetailPage(stop: _stop()));

      expect(find.text(capsules), findsOneWidget);
      expect(find.text(amount), findsOneWidget);
    });

    testWidgets('у закрытой — нет', (tester) async {
      await pump(
        tester,
        StopDetailPage(stop: _stop(status: DeliveryStatus.delivered)),
      );
      expect(find.textContaining('Ожидаем'), findsNothing);
    });
  });

  group('Карточка заказа в списке', () {
    testWidgets('у незакрытого — строки, у закрытого — нет', (tester) async {
      await pump(tester, Scaffold(body: OrderCard(order: _order())));
      expect(find.text(capsules), findsOneWidget);
      expect(find.text(amount), findsOneWidget);

      await pump(
        tester,
        Scaffold(
          body: OrderCard(order: _order(status: DeliveryStatus.delivered)),
        ),
      );
      expect(find.textContaining('Ожидаем'), findsNothing);
    });
  });

  group('Детали заказа', () {
    testWidgets('у незакрытого — раздел «Ожидается» вместо договорной цены',
        (tester) async {
      await pump(tester, OrderDetailPage(order: _order()));

      expect(find.text('ОЖИДАЕТСЯ'), findsOneWidget);
      expect(find.text('Ожидаемое кол-во капсул'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Ожидаемая сумма'), findsOneWidget);
      expect(find.text('150 000 сум'), findsOneWidget);
      // Ту же сумму в «Расчёте» второй раз не повторяем.
      expect(find.text('Цена заказа (договорная)'), findsNothing);
    });

    testWidgets('у закрытого — договорная цена в расчёте, раздела нет',
        (tester) async {
      await pump(
        tester,
        OrderDetailPage(order: _order(status: DeliveryStatus.delivered)),
      );

      expect(find.text('ОЖИДАЕТСЯ'), findsNothing);
      expect(find.textContaining('Ожидаем'), findsNothing);
      expect(find.text('Цена заказа (договорная)'), findsOneWidget);
    });

    testWidgets('без задания и суммы раздела нет', (tester) async {
      await pump(
        tester,
        OrderDetailPage(order: _order(bottleSellCount: null, customPrice: null)),
      );
      expect(find.text('ОЖИДАЕТСЯ'), findsNothing);
    });
  });

  group('Десктоп: панель доставки', () {
    Future<void> pumpDrawer(WidgetTester tester, RouteStop stop) async {
      final route = RouteDetail(
        id: 'r-1',
        date: DateTime(2026, 9, 18),
        status: RouteStatus.inProgress,
        completedCount: 0,
        totalCustomers: 1,
        driverFullName: 'Азиз Каримов',
        stops: [stop],
      );
      await pump(
        tester,
        DesktopTheme(
          child: Scaffold(
            body: SizedBox(
              width: 420,
              child: DeliveryDrawer(
                row: DeliveryRow(route: route, stop: stop),
                onEditRoute: () {},
                onCancelRoute: () {},
                onCancelOrder: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('у открытой точки — ожидаемые капсулы и сумма',
        (tester) async {
      await pumpDrawer(tester, _stop());

      expect(find.text('Ожидаемое кол-во капсул'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Ожидаемая сумма'), findsOneWidget);
      expect(find.text('150 000 сум'), findsOneWidget);
      expect(find.text('Цена заказа (договорная)'), findsNothing);
    });

    testWidgets('у закрытой — только договорная цена как справка',
        (tester) async {
      await pumpDrawer(tester, _stop(status: DeliveryStatus.delivered));

      expect(find.textContaining('Ожидаем'), findsNothing);
      expect(find.text('Цена заказа (договорная)'), findsOneWidget);
    });
  });
}

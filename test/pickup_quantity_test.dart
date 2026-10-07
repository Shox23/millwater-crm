import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/presentation/delivery_completion_page.dart';
import 'package:crm_millwater/features/routes/presentation/route_create_page.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_customer_row.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_stop_card.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_totals.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/stop_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Количество капсул у цели «Вывоз».
///
/// Поле на сервере одно — `bottle_sell_count`, и ни в один расчёт оно не
/// входит: у доставки значит «сколько везти», у вывоза — «сколько забрать».
/// Поэтому число отправляем, а подписи держим разными: одно и то же «3
/// капсулы» у вывоза читается наоборот.
///
/// В итоги маршрута капсулы вывоза не идут: машину он не занимает, и
/// «Капсул 19 л» должно означать погрузку.
void main() {
  const baraka = 'Офис «Baraka»';

  Future<void> settle(WidgetTester tester, {int steps = 4}) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  group('Админ задаёт, сколько забрать', () {
    late _CreatingRepository repo;

    Future<void> openPickupStop(WidgetTester tester) async {
      repo = _CreatingRepository();
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
      await settle(tester, steps: 8);

      await tester.tap(find.widgetWithText(RouteCreateCustomerRow, baraka));
      await settle(tester, steps: 3);
      await tester.tap(find.descendant(
        of: find.widgetWithText(RouteCreateStopCard, baraka),
        matching: find.text(baraka),
      ));
      await tester.pump();
      await tester.tap(find.descendant(
        of: find.widgetWithText(RouteCreateStopCard, baraka),
        matching: find.text('Вывоз'),
      ));
      await tester.pump();
    }

    testWidgets('у вывоза есть счётчик, и подпись у него своя',
        (tester) async {
      await openPickupStop(tester);

      expect(find.text('Сколько капсул забрать'), findsOneWidget);
      expect(find.text('Сколько капсул везти'), findsNothing);
    });

    testWidgets('в метастроке точки — «забрать», а не «везти»',
        (tester) async {
      await openPickupStop(tester);

      // У заказчика есть история на 3 капсулы, столько и подставилось.
      expect(
        find.descendant(
          of: find.widgetWithText(RouteCreateStopCard, baraka),
          matching: find.text('забрать 3 капсулы'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('в итоги маршрута капсулы вывоза не идут', (tester) async {
      await openPickupStop(tester);

      // Точка одна, в ней три капсулы к вывозу — а к погрузке ноль.
      final totals = find.byType(RouteCreateTotals);
      expect(find.descendant(of: totals, matching: find.text('1')),
          findsOneWidget);
      expect(find.descendant(of: totals, matching: find.text('0')),
          findsOneWidget);
    });

    testWidgets('количество уходит на сервер тем же полем', (tester) async {
      await openPickupStop(tester);

      // Ставим своё число пресетом: «забрать 10».
      await tester.tap(find.descendant(
        of: find.widgetWithText(RouteCreateStopCard, baraka),
        matching: find.text('10'),
      ));
      await tester.pump();

      final button = find.widgetWithText(AppButton, 'Создать маршрут · 1');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(repo.sent.single.purpose, OrderPurpose.pickup);
      expect(repo.sent.single.bottleSellCount, 10);
    });
  });

  group('Водитель видит, сколько забрать', () {
    RouteStop stopWith(OrderPurpose purpose) => RouteStop(
          id: 's-1',
          customerId: 'c-1',
          customerName: 'Кафе «Nasiba»',
          customerAddress: 'ул. Амир Темур, 12',
          customerPhone: '+998 71 200 11 22',
          status: DeliveryStatus.pending,
          purpose: purpose,
          bottleSellCount: 4,
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

    testWidgets('в карточке точки подпись зависит от цели', (tester) async {
      await pumpStopCard(tester, stopWith(OrderPurpose.pickup));
      expect(find.text('Ожидаемое кол-во к вывозу: 4'), findsOneWidget);

      await pumpStopCard(tester, stopWith(OrderPurpose.delivery19l));
      expect(find.text('Ожидаемое кол-во капсул: 4'), findsOneWidget);
    });

    testWidgets('на завершении вывоза видно, сколько ожидает админ',
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
              stop: stopWith(OrderPurpose.pickup),
              price: const BuildCapsulePrice(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Плашка та же, что у доставки, но своими словами: факт водитель
      // отмечает ниже счётчиком «капсул увозим».
      expect(find.text('НАЗНАЧЕНО К ВЫВОЗУ'), findsOneWidget);
      expect(find.text('НАЗНАЧЕНО К ДОСТАВКЕ'), findsNothing);
      expect(find.text('4 капсулы'), findsOneWidget);
    });
  });

  group('Сводка «ожидается» по маршруту', () {
    RouteStop stop(String id, OrderPurpose purpose, int count) => RouteStop(
          id: id,
          customerId: 'c-$id',
          customerName: 'Заказчик $id',
          customerAddress: 'ул. Тестовая, $id',
          customerPhone: '+998900000002',
          status: DeliveryStatus.pending,
          purpose: purpose,
          bottleSellCount: count,
        );

    test('капсулы вывоза в погрузку не идут', () {
      final route = RouteDetail(
        id: 'r-1',
        date: DateTime(2026, 10, 2),
        status: RouteStatus.inProgress,
        completedCount: 0,
        totalCustomers: 3,
        stops: [
          stop('1', OrderPurpose.delivery19l, 10),
          stop('2', OrderPurpose.pickup, 5),
          stop('3', OrderPurpose.bulkWater, 7),
        ],
      );

      // Сводку читают как «сколько грузить»: везти надо 10, а 5 — забрать.
      // Число у вывоза и опта уходит тем же полем, но к погрузке отношения
      // не имеет.
      expect(route.expected().capsules, 10);
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

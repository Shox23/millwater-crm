import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/desktop/bloc/day_deliveries_bloc.dart';
import 'package:crm_millwater/features/desktop/presentation/pages/routes_desktop_page.dart';
import 'package:crm_millwater/features/desktop/theme/desktop_theme.dart';
import 'package:crm_millwater/features/routes/bloc/routes_bloc.dart';
import 'package:crm_millwater/features/routes/presentation/route_detail_page.dart';
import 'package:crm_millwater/features/routes/presentation/routes_page.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Итоги ожиданий по маршруту: сколько капсул ещё везти и сколько денег
/// привезти — на карточке маршрута у админа на телефоне и в разбивке дня
/// на десктопе.
///
/// Считается по открытым точкам: договорная сумма как есть, доставка по
/// прайсу — задание × цена заказчика, вывоз без цены и опт — ноль. В
/// списочном ответе точек нет, поэтому телефон догружает детали маршрутов
/// вторым шагом, не задерживая список.
RouteStop _stop({
  String id = 's-1',
  DeliveryStatus status = DeliveryStatus.pending,
  OrderPurpose purpose = OrderPurpose.delivery19l,
  int? bottleSellCount,
  int? customPrice,
  int? effectiveWaterPrice,
}) =>
    RouteStop(
      id: id,
      customerId: 'c-1',
      customerName: 'Кафе Тест',
      customerAddress: 'ул. Тестовая, 1',
      customerPhone: '+998900000002',
      status: status,
      purpose: purpose,
      bottleSellCount: bottleSellCount,
      customPrice: customPrice,
      effectiveWaterPrice: effectiveWaterPrice,
    );

void main() {
  group('Ожидание точки', () {
    test('договорная сумма перекрывает расчёт по цене', () {
      final stop = _stop(
          bottleSellCount: 6, customPrice: 150000, effectiveWaterPrice: 20000);
      expect(stop.expectedAmount(), 150000);
      expect(stop.expectedCapsules, 6);
    });

    test('доставка по прайсу — задание на цену заказчика', () {
      expect(
        _stop(bottleSellCount: 4, effectiveWaterPrice: 25000).expectedAmount(),
        100000,
      );
    });

    test('без цены заказчика — по запасной; без запасной — не считается', () {
      final stop = _stop(bottleSellCount: 4);
      expect(stop.expectedAmount(fallbackPrice: 20000), 80000);
      expect(stop.expectedAmount(), 0);
    });

    test('вывоз без цены и опт денег не ждут, договорная у вывоза — ждёт', () {
      expect(_stop(purpose: OrderPurpose.pickup).expectedAmount(), 0);
      expect(
        _stop(purpose: OrderPurpose.pickup, customPrice: 50000).expectedAmount(),
        50000,
      );
      expect(
        _stop(purpose: OrderPurpose.bulkWater, effectiveWaterPrice: 20000)
            .expectedAmount(),
        0,
      );
    });

    test('у закрытой и отменённой точки ожидания нет', () {
      for (final status in [
        DeliveryStatus.delivered,
        DeliveryStatus.failed,
        DeliveryStatus.cancelled,
      ]) {
        final stop = _stop(
          status: status,
          bottleSellCount: 6,
          customPrice: 150000,
          effectiveWaterPrice: 20000,
        );
        expect(stop.expectedCapsules, 0, reason: '$status');
        expect(stop.expectedAmount(), 0, reason: '$status');
      }
    });
  });

  group('Ожидание маршрута', () {
    test('складывается по открытым точкам', () {
      final total = RouteExpectations.ofStops([
        _stop(id: 'a', bottleSellCount: 6, customPrice: 150000),
        _stop(id: 'b', bottleSellCount: 4, effectiveWaterPrice: 20000),
        _stop(
          id: 'c',
          status: DeliveryStatus.delivered,
          bottleSellCount: 9,
          effectiveWaterPrice: 20000,
        ),
        _stop(id: 'd', purpose: OrderPurpose.pickup),
      ]);

      expect(total, const RouteExpectations(capsules: 10, amount: 230000));
      expect(total.isEmpty, isFalse);
    });

    test('маршрут без заданий и цен — пустое ожидание', () {
      expect(RouteExpectations.ofStops([_stop(), _stop(id: 'x')]).isEmpty,
          isTrue);
      expect(RouteExpectations.ofStops(const []), RouteExpectations.none);
    });
  });

  group('Список маршрутов у админа', () {
    late MockCrmRepository repo;
    late DateTime today;

    setUp(() async {
      repo = MockCrmRepository();
      today = DateTime.now();
      // Свой маршрут на сегодня с известным заданием: две доставки — одна
      // по договорной цене, другая по прайсу мока (20 000 за капсулу).
      final customers = repo.store.customers;
      await repo.createRoute(
        driverId: 'd1',
        date: today,
        orders: [
          RouteOrderInput(
            customerId: customers[2].id,
            bottleSellCount: 6,
            customPrice: 150000,
          ),
          RouteOrderInput(customerId: customers[3].id, bottleSellCount: 4),
        ],
      );
    });

    test('блок догружает итоги вторым шагом, после списка', () async {
      final bloc = RoutesBloc(repo)..add(const RoutesRequested());
      addTearDown(bloc.close);

      final ready =
          await bloc.stream.firstWhere((s) => s.status == RoutesStatus.ready);
      // Список уже готов, итогов ещё нет — они не задерживают экран.
      expect(ready.routes, isNotEmpty);
      expect(ready.expectations, isEmpty);

      final withTotals =
          await bloc.stream.firstWhere((s) => s.expectations.isNotEmpty);
      final created = repo.store.routes.last;
      expect(
        withTotals.expectations[created.id],
        const RouteExpectations(capsules: 10, amount: 230000),
      );
      // Итоги есть у каждого маршрута дня, включая объеханные (пустые).
      expect(withTotals.expectations.keys.toSet(),
          withTotals.routes.map((r) => r.id).toSet());
    });

    testWidgets('карточка маршрута показывает итоги', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            theme: AppTheme.light(),
            home: const RoutesPage(),
          ),
        ),
      );
      // Список, потом детали каждого маршрута — два шага мока подряд.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Созданный маршрут — последний в списке и в кадр не попадает
      // (карточки строятся лениво), поэтому сверяем первый маршрут дня, у
      // которого есть что ждать: в сиде у открытых точек задание стоит.
      final state =
          tester.element(find.byType(RouteCard).first).read<RoutesBloc>().state;
      final first = state.routes.first;
      final expected = state.expectations[first.id]!;
      expect(expected.isEmpty, isFalse);
      expect(find.text('Ожидаемое кол-во капсул: ${expected.capsules}'),
          findsWidgets);
    });

    testWidgets('шапка маршрута показывает те же итоги', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            theme: AppTheme.light(),
            home: RouteDetailPage(routeId: repo.store.routes.last.id),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Один раз в шапке; у точек — по одной строке на точку (6 и 4).
      expect(find.text('Ожидаемое кол-во капсул: 10'), findsOneWidget);
      expect(find.text('Ожидаемая сумма: 230 000 сум'), findsOneWidget);
    });
  });

  group('Карточка маршрута', () {
    RouteListItem item() => RouteListItem(
          id: 'r-1',
          date: DateTime(2026, 9, 18),
          status: RouteStatus.created,
          completedCount: 0,
          totalCustomers: 27,
          driverId: 'd1',
          driverFullName: 'Ахмад',
        );

    Future<void> pump(WidgetTester tester, RouteExpectations? e) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: Scaffold(body: RouteCard(route: item(), expectations: e)),
        ),
      );
      await tester.pump();
    }

    testWidgets('без итогов и с пустыми — строк нет', (tester) async {
      await pump(tester, null);
      expect(find.textContaining('Ожидаем'), findsNothing);

      await pump(tester, RouteExpectations.none);
      expect(find.textContaining('Ожидаем'), findsNothing);
    });

    testWidgets('одни капсулы без денег — только капсулы', (tester) async {
      await pump(tester, const RouteExpectations(capsules: 54));
      expect(find.text('Ожидаемое кол-во капсул: 54'), findsOneWidget);
      expect(find.textContaining('Ожидаемая сумма'), findsNothing);
    });
  });

  group('Десктоп', () {
    late MockCrmRepository repo;

    setUp(() => repo = MockCrmRepository());

    Future<DayDeliveriesState> loadDay(DayDeliveriesBloc bloc) {
      final ready = bloc.stream
          .firstWhere((s) => s.status == DayDeliveriesStatus.ready);
      bloc.add(const DayDeliveriesRequested());
      return ready;
    }

    test('разбивка по маршрутам дня — без объеханных, итог суммой', () async {
      final bloc = DayDeliveriesBloc(repo);
      addTearDown(bloc.close);

      final state = await loadDay(bloc);
      final byRoute = state.expectedByRoute;

      // В сиде сегодня есть маршруты с открытыми точками и целиком
      // завершённые: у вторых ждать нечего, и плашки им не положено.
      expect(byRoute, isNotEmpty);
      expect(byRoute.every((e) => !e.$2.isEmpty), isTrue);
      expect(
        byRoute.any((e) => e.$1.status == RouteStatus.completed),
        isFalse,
      );
      expect(
        state.expected,
        byRoute.fold(RouteExpectations.none, (sum, e) => sum + e.$2),
      );
      // Сходится с прямым подсчётом по точкам.
      for (final (route, e) in byRoute) {
        expect(e, route.expected(fallbackPrice: state.capsulePrice));
      }
    });

    testWidgets('блок «Ожидается» — плашка на маршрут и итог за день',
        (tester) async {
      tester.view.physicalSize = const Size(1728, 1117);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final bloc = DayDeliveriesBloc(repo)..add(const DayDeliveriesRequested());
      addTearDown(bloc.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: bloc,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            theme: AppTheme.light(),
            home: DesktopTheme(
              child: Scaffold(body: RoutesDesktopPage(onRowTap: (_) {})),
            ),
          ),
        ),
      );
      // Часы в виджет-тесте фейковые: ждать поток блока нельзя, только
      // двигать время. Список дня, потом детали каждого маршрута.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      final state = bloc.state;
      expect(state.status, DayDeliveriesStatus.ready);

      expect(find.text('ОЖИДАЕТСЯ'), findsOneWidget);
      // Итог за день — только когда маршрутов несколько.
      expect(find.text('Весь день'),
          state.expectedByRoute.length > 1 ? findsOneWidget : findsNothing);
      for (final (route, _) in state.expectedByRoute) {
        expect(find.text(route.driverFullName!), findsWidgets);
      }
      expect(find.text('Ожидаемое кол-во капсул'),
          findsNWidgets(state.expectedByRoute.length + 1));
    });
  });
}

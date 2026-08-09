import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/mock/mock_store.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/bloc/my_routes_bloc.dart';
import 'package:crm_millwater/features/driver/presentation/delivery_completion_page.dart';
import 'package:crm_millwater/features/driver/presentation/my_route_detail_page.dart';
import 'package:crm_millwater/features/driver/presentation/my_routes_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Водитель, у которого маршрутов нет вообще.
class _EmptyDriverRepository extends MockDriverRepository {
  _EmptyDriverRepository() : super(driverId: 'нет-такого-водителя');
}

/// Репозиторий, падающий на чтении списка.
class _FailingDriverRepository extends MockDriverRepository {
  @override
  Future<List<RouteListItem>> getMyRoutes() async =>
      throw Exception('нет связи');
}

void main() {
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> pumpPage(
    WidgetTester tester,
    DriverRepository repo,
    Widget page,
  ) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      RepositoryProvider<DriverRepository>.value(
        value: repo,
        child: MaterialApp(
            // Строки интерфейса берутся из локали: тесты идут на русской.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,theme: AppTheme.light(), home: page),
      ),
    );
    await settle(tester);
  }

  group('MockDriverRepository', () {
    test('отдаёт только свои маршруты', () async {
      final repo = MockDriverRepository(driverId: 'd1');
      final routes = await repo.getMyRoutes();

      // В сиде у d1 один маршрут (r1) из пяти.
      expect(routes.length, 1);
      expect(routes.single.id, 'r1');
      // Водительские ответы полей водителя не содержат.
      expect(routes.single.driverId, isNull);
      expect(routes.single.driverFullName, isNull);
    });

    test('чужой маршрут по id не отдаётся', () async {
      final repo = MockDriverRepository(driverId: 'd1');

      expect(await repo.getMyRoute('r1'), isNotNull);
      // r2 принадлежит d2.
      expect(await repo.getMyRoute('r2'), isNull);
    });

    test('смена статуса точки видна в маршруте', () async {
      final repo = MockDriverRepository(driverId: 'd1');
      await repo.updateDeliveryStatus(
        stopId: 's3',
        status: DeliveryStatus.onWay,
      );

      final route = await repo.getMyRoute('r1');
      final stop = route!.stops.firstWhere((s) => s.id == 's3');
      expect(stop.status, DeliveryStatus.onWay);
    });

    test('завершение доставки проводит оплату и фото', () async {
      final repo = MockDriverRepository(driverId: 'd1');
      await repo.completeDelivery(
        stopId: 's2',
        capsules: 3,
        amount: 60000,
        bottleBalance: 3,
        photoPath: '/tmp/check.jpg',
      );

      final route = await repo.getMyRoute('r1');
      final stop = route!.stops.firstWhere((s) => s.id == 's2');
      expect(stop.status, DeliveryStatus.paid);
      expect(stop.deliveredCapsules, 3);
      expect(stop.paymentAmount, 60000);
      expect(stop.paymentPhoto, '/tmp/check.jpg');
      expect(route.completedCount, 2);
    });

    test('повтор с тем же ключом не проводит доставку дважды', () async {
      final repo = MockDriverRepository(driverId: 'd1');

      await repo.completeDelivery(
        stopId: 's2',
        capsules: 3,
        amount: 60000,
        bottleBalance: 3,
        idempotencyKey: 'key-1',
      );
      // Связь оборвалась, водитель нажал «Завершить» ещё раз.
      await repo.completeDelivery(
        stopId: 's2',
        capsules: 99,
        amount: 999999,
        bottleBalance: 99,
        idempotencyKey: 'key-1',
      );

      final route = await repo.getMyRoute('r1');
      final stop = route!.stops.firstWhere((s) => s.id == 's2');
      expect(stop.deliveredCapsules, 3);
      expect(stop.paymentAmount, 60000);
    });

    test('завершение водителем видно в админских данных', () async {
      // Общий стор — то же состояние, что видит админ.
      final store = MockStore();
      final driver = MockDriverRepository(store: store, driverId: 'd1');
      final admin = MockCrmRepository(store: store);

      await driver.completeDelivery(
          stopId: 's2', capsules: 3, amount: 60000, bottleBalance: 3);

      final route = await admin.getRoute('r1');
      expect(route!.completedCount, 2);
      expect(route.collected, 160000);
    });
  });

  group('Экран «Мои маршруты»', () {
    testWidgets('показывает сводку и список своих маршрутов', (tester) async {
      await pumpPage(
        tester,
        MockDriverRepository(driverId: 'd1'),
        const MyRoutesPage(),
      );

      expect(find.text('Мои маршруты'), findsOneWidget);
      expect(find.text('Доставлено доставок'), findsNothing);
      expect(find.text('мои маршруты'), findsOneWidget);
      expect(find.text('доставлено сегодня'), findsOneWidget);
      expect(find.text('заказов'), findsOneWidget);
      // Денежного показателя у водителя нет — сводный отчёт ему недоступен.
      expect(find.text('Собрано сегодня'), findsNothing);
      // Карточка маршрута вместо водителя показывает число точек.
      expect(find.text('3 точек'), findsOneWidget);
    });

    testWidgets('без маршрутов объясняет, что делать', (tester) async {
      await pumpPage(tester, _EmptyDriverRepository(), const MyRoutesPage());

      expect(find.text('Маршрутов пока нет'), findsOneWidget);
      expect(
        find.text('Когда диспетчер назначит маршрут, он появится здесь'),
        findsOneWidget,
      );
    });

    testWidgets('сетевая ошибка предлагает повторить', (tester) async {
      final repo = _FailingDriverRepository();
      await pumpPage(tester, repo, const MyRoutesPage());

      expect(find.text('Не удалось загрузить маршруты'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('фильтр отсекает маршруты не в этом статусе', (tester) async {
      await pumpPage(
        tester,
        MockDriverRepository(driverId: 'd1'),
        const MyRoutesPage(),
      );
      // Единственный маршрут d1 — «В пути».
      expect(find.text('3 точек'), findsOneWidget);

      await tester.tap(find.text('Завершены'));
      await settle(tester);

      expect(find.text('В этом фильтре пусто'), findsOneWidget);
    });
  });

  group('Карточка маршрута водителя', () {
    testWidgets('показывает точки и открывает завершение доставки',
        (tester) async {
      await pumpPage(
        tester,
        MockDriverRepository(driverId: 'd1'),
        const MyRouteDetailPage(routeId: 'r1'),
      );

      expect(find.text('ТОЧКИ МАРШРУТА'), findsOneWidget);
      expect(find.text('Салон «Zebo»'), findsOneWidget);

      await tester.tap(find.text('Салон «Zebo»'));
      await settle(tester);

      expect(find.byType(DeliveryCompletionPage), findsOneWidget);
      expect(find.text('КОЛИЧЕСТВО КАПСУЛ'), findsOneWidget);
      expect(find.text('Фото оплаты'), findsOneWidget);
      // Плитка фото больше не заглушка.
      expect(find.text('Скоро'), findsNothing);
      expect(find.text('Камера'), findsOneWidget);
    });

    testWidgets('завершённая точка на завершение не открывается',
        (tester) async {
      await pumpPage(
        tester,
        MockDriverRepository(driverId: 'd1'),
        const MyRouteDetailPage(routeId: 'r1'),
      );

      // Первая точка r1 — s1, она уже оплачена. Этот же заказчик стоит
      // в маршруте дважды, поэтому берём именно первую карточку.
      await tester.tap(find.text('Кафе «Nasiba»').first);
      await settle(tester);

      expect(find.byType(DeliveryCompletionPage), findsNothing);
    });

    testWidgets('статус точки меняется из меню', (tester) async {
      // Состояние читаем из стора, а не через await репозитория: внутри
      // testWidgets Future.delayed живёт по фейковым часам и без pump
      // никогда не завершится.
      final store = MockStore();
      await pumpPage(
        tester,
        MockDriverRepository(store: store, driverId: 'd1'),
        const MyRouteDetailPage(routeId: 'r1'),
      );

      // Меню есть только у незавершённых точек: их в r1 две.
      await tester.tap(find.byTooltip('Изменить статус').first);
      await settle(tester);

      await tester.tap(find.text('Не доставлено').last);
      // Успех подтверждается снек-баром, он живёт 4 секунды — если его не
      // дождаться, тест падает на «A Timer is still pending».
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      final route = store.routes.firstWhere((r) => r.id == 'r1');
      expect(
        route.stops.any((s) => s.status == DeliveryStatus.failed),
        isTrue,
      );
    });
  });

  group('Показатели дня на экране водителя', () {
    RouteListItem route(String id, DateTime date, int done, int total) =>
        RouteListItem(
          id: id,
          date: date,
          status: RouteStatus.inProgress,
          completedCount: done,
          totalCustomers: total,
        );

    test('«доставлено сегодня» считается только по сегодняшним маршрутам', () {
      final now = DateTime.now();
      final state = MyRoutesState(routes: [
        route('r1', now, 2, 5),
        route('r2', now.subtract(const Duration(days: 1)), 4, 4),
      ]);

      expect(state.deliveredToday, 2);
      expect(state.stopsToday, 5);
      // Общие показатели остаются по всем маршрутам — так их требует ТЗ.
      expect(state.routesCount, 2);
      expect(state.stopsTotal, 9);
    });

    test('без сегодняшних маршрутов показатели дня нулевые', () {
      final state = MyRoutesState(routes: [
        route('r1', DateTime.now().subtract(const Duration(days: 3)), 3, 3),
      ]);

      expect(state.deliveredToday, 0);
      expect(state.stopsToday, 0);
      expect(state.routesCount, 1);
    });
  });
}

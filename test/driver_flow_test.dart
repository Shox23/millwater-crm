import 'package:crm_millwater/app/locale_cubit.dart';
import 'package:crm_millwater/app/settings/settings_storage.dart';
import 'package:crm_millwater/app/theme/theme_cubit.dart';
import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/mock/mock_store.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/result_page.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/core/utils/day.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/bloc/my_routes_bloc.dart';
import 'package:crm_millwater/features/driver/presentation/delivery_completion_page.dart';
import 'package:crm_millwater/features/driver/presentation/driver_shell.dart';
import 'package:crm_millwater/features/driver/presentation/my_route_detail_page.dart';
import 'package:crm_millwater/features/driver/presentation/my_routes_page.dart';
import 'package:crm_millwater/features/orders/presentation/cancel_order_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// Водитель, у которого маршрутов нет вообще.
class _EmptyDriverRepository extends MockDriverRepository {
  _EmptyDriverRepository() : super(driverId: 'нет-такого-водителя');
}

/// Считает, ходил ли кто-нибудь за данными профиля.
class _CountingDriverRepository extends MockDriverRepository {
  _CountingDriverRepository() : super(driverId: 'd1');

  int orderPages = 0;

  /// Сколько раз читался список маршрутов.
  int routeCalls = 0;

  @override
  Future<List<RouteListItem>> getMyRoutes() {
    routeCalls++;
    return super.getMyRoutes();
  }

  @override
  Future<ResultPage<Order>> getMyOrders({
    int page = 1,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? customerId,
    String? routeId,
    DeliveryStatus? status,
    OrderPurpose? purpose,
    PaymentMethod? paymentMethod,
    String? search,
  }) {
    // Статистика профиля — единственное, что спрашивает заказы за период.
    if (dateFrom != null) orderPages++;
    return super.getMyOrders(
      page: page,
      dateFrom: dateFrom,
      dateTo: dateTo,
      customerId: customerId,
      routeId: routeId,
      status: status,
      purpose: purpose,
      paymentMethod: paymentMethod,
      search: search,
    );
  }
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
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<DriverRepository>.value(value: repo),
          // Карточка маршрута передаёт источник цены экрану завершения —
          // в дереве приложения его кладёт `app.dart`. Здесь сети нет,
          // поэтому цена берётся из сборки.
          RepositoryProvider<CapsulePrice>.value(
            value: const BuildCapsulePrice(),
          ),
        ],
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
        purpose: OrderPurpose.delivery19l,
        capsules: 3,
        amount: 60000,
        bottleBalance: 3,
        // Фото прикладывают только к оплате картой.
        method: PaymentMethod.card,
        photoPath: '/tmp/check.jpg',
      );

      final route = await repo.getMyRoute('r1');
      final stop = route!.stops.firstWhere((s) => s.id == 's2');
      expect(stop.status, DeliveryStatus.delivered);
      expect(stop.deliveredCapsules, 3);
      expect(stop.paymentAmount, 60000);
      expect(stop.paymentPhoto, '/tmp/check.jpg');
      expect(route.completedCount, 2);
    });

    test('повтор с тем же ключом не проводит доставку дважды', () async {
      final repo = MockDriverRepository(driverId: 'd1');

      await repo.completeDelivery(
        stopId: 's2',
        purpose: OrderPurpose.delivery19l,
        capsules: 3,
        amount: 60000,
        bottleBalance: 3,
        method: PaymentMethod.cash,
        idempotencyKey: 'key-1',
      );
      // Связь оборвалась, водитель нажал «Завершить» ещё раз.
      await repo.completeDelivery(
        stopId: 's2',
        purpose: OrderPurpose.delivery19l,
        capsules: 99,
        amount: 999999,
        bottleBalance: 99,
        method: PaymentMethod.cash,
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
        stopId: 's2',
        purpose: OrderPurpose.delivery19l,
        capsules: 3,
        amount: 60000,
        bottleBalance: 3,
        method: PaymentMethod.cash,
      );

      final route = await admin.getRoute('r1');
      expect(route!.completedCount, 2);
      expect(route.collected, 160000);
    });
  });

  /// Полоска «запрос в пути». Именно неопределённая: у карточек маршрутов и
  /// у hero-карточки свои LinearProgressIndicator, но с заданным value.
  final refreshBar = find.byWidgetPredicate(
    (w) => w is LinearProgressIndicator && w.value == null,
  );

  group('Экран «Мои маршруты»', () {
    testWidgets('показывает сводку и список своих маршрутов', (tester) async {
      await pumpPage(
        tester,
        MockDriverRepository(driverId: 'd1'),
        const MyRoutesPage(),
      );

      expect(find.text('Мои маршруты'), findsOneWidget);
      expect(find.text('Доставлено доставок'), findsNothing);
      // Все три показателя относятся к выбранному в ленте дню — подписи не
      // должны обещать ни «всего», ни «сегодня».
      expect(find.text('маршрутов за день'), findsOneWidget);
      expect(find.text('доставлено'), findsOneWidget);
      expect(find.text('заказов за день'), findsOneWidget);
      // Денежного показателя у водителя нет — сводный отчёт ему недоступен.
      expect(find.text('Собрано сегодня'), findsNothing);
      // Карточка маршрута вместо водителя показывает число точек.
      expect(find.text('3 точки'), findsOneWidget);
    });

    testWidgets('лента дат переключает день без похода в сеть', (tester) async {
      final repo = _CountingDriverRepository();
      await pumpPage(tester, repo, const MyRoutesPage());
      final loadsAfterOpen = repo.routeCalls;

      // Соседний день в ленте: сегодняшних маршрутов там нет, и шапка
      // переключается с «Сегодня · …» на «На …».
      final yesterday = dayOnly(DateTime.now()).subtract(
        const Duration(days: 1),
      );
      await tester.tap(find.text(DateFormat('dd.MM').format(yesterday)));
      await tester.pumpAndSettle();

      // Шапка рисует подпись капсом.
      expect(
        find.text('НА ${DateFormat('dd.MM.yy').format(yesterday)}'),
        findsOneWidget,
      );
      // Данные уже на клиенте — смена дня не должна дёргать репозиторий.
      expect(repo.routeCalls, loadsAfterOpen);
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

    testWidgets('на первой загрузке спиннер есть', (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        RepositoryProvider<DriverRepository>.value(
          value: MockDriverRepository(driverId: 'd1'),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            theme: AppTheme.light(),
            home: const MyRoutesPage(),
          ),
        ),
      );
      // Показывать ещё нечего — спиннер уместен.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await settle(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('обновление не стирает список', (tester) async {
      await pumpPage(
        tester,
        MockDriverRepository(driverId: 'd1'),
        const MyRoutesPage(),
      );
      expect(find.text('3 точки'), findsOneWidget);

      // Повторный запрос: список остаётся на месте, а «запрос в пути»
      // показывает тонкая полоска. Раньше здесь всё стирал спиннер, и
      // RefreshIndicator вылетал из дерева посреди жеста.
      // Контекст берём у потомка: сам MyRoutesPage стоит НАД своим
      // BlocProvider и блока не видит.
      final context = tester.element(find.byType(RefreshIndicator));
      BlocProvider.of<MyRoutesBloc>(context).add(const MyRoutesRequested());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(refreshBar, findsOneWidget);
      expect(find.text('3 точки'), findsOneWidget);

      await settle(tester);
      expect(refreshBar, findsNothing);
    });

    testWidgets('фильтр отсекает маршруты не в этом статусе', (tester) async {
      await pumpPage(
        tester,
        MockDriverRepository(driverId: 'd1'),
        const MyRoutesPage(),
      );
      // Единственный маршрут d1 — «В пути».
      expect(find.text('3 точки'), findsOneWidget);

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
      // По умолчанию оплата наличными — подтверждать снимком нечего.
      expect(find.text('Фото оплаты'), findsNothing);
    });

    testWidgets('фото просят только при оплате картой', (tester) async {
      await pumpPage(
        tester,
        MockDriverRepository(driverId: 'd1'),
        const MyRouteDetailPage(routeId: 'r1'),
      );
      await tester.tap(find.text('Салон «Zebo»'));
      await settle(tester);

      expect(find.text('Фото оплаты'), findsNothing);

      // Способ оплаты уехал ниже: у доставки теперь спрашивают ещё возврат
      // и брак, и до него нужно доскроллить.
      await tester.ensureVisible(find.text('Карта'));
      await settle(tester);
      await tester.tap(find.text('Карта'));
      await settle(tester);

      expect(find.text('Фото оплаты'), findsOneWidget);
      expect(find.text('Камера'), findsOneWidget);

      // Вернулись к наличным — тайл снова скрыт.
      await tester.ensureVisible(find.text('Наличные'));
      await settle(tester);
      await tester.tap(find.text('Наличные'));
      await settle(tester);

      expect(find.text('Фото оплаты'), findsNothing);
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

      // Меню есть только у незавершённых точек: их в r1 две. Последняя из
      // них ещё «Новый», поэтому пункт «В пути» доступен.
      await tester.tap(find.byTooltip('Изменить статус').last);
      await settle(tester);

      await tester.tap(find.text('В пути').last);
      // Успех подтверждается снек-баром, он живёт 4 секунды — если его не
      // дождаться, тест падает на «A Timer is still pending».
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      final route = store.routes.firstWhere((r) => r.id == 'r1');
      expect(
        route.stops.where((s) => s.status == DeliveryStatus.onWay).length,
        2,
      );
    });

    testWidgets('«Не доставлено» одним касанием из меню больше нет',
        (tester) async {
      await pumpPage(
        tester,
        MockDriverRepository(driverId: 'd1'),
        const MyRouteDetailPage(routeId: 'r1'),
      );

      await tester.tap(find.byTooltip('Изменить статус').first);
      await settle(tester);

      // Вместо него — отмена с причиной, отдельной формой.
      expect(find.text('Не доставлено'), findsNothing);
      expect(find.text('Отменить заказ'), findsOneWidget);
    });

    testWidgets('отмена из меню открывает форму и уходит с причиной',
        (tester) async {
      final store = MockStore();
      final repo = MockDriverRepository(store: store, driverId: 'd1');
      await pumpPage(
        tester,
        repo,
        const MyRouteDetailPage(routeId: 'r1'),
      );

      await tester.tap(find.byTooltip('Изменить статус').first);
      await settle(tester);
      await tester.tap(find.text('Отменить заказ').last);
      await settle(tester);

      expect(find.byType(CancelOrderPage), findsOneWidget);
      // Предупреждение о необратимости — до нажатия, а не после.
      expect(
        find.textContaining('Вернуть его в работу нельзя'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'Не открыл дверь');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Отменить заказ'));
      // Запрос в моке идёт 150 мс, затем форма закрывается, а маршрут
      // перечитывается; снек-бар живёт 4 секунды — его тоже дожидаемся.
      await settle(tester);
      await settle(tester);
      await tester.pump(const Duration(seconds: 5));

      expect(repo.lastCancelReason, 'Не открыл дверь');
      expect(find.byType(CancelOrderPage), findsNothing);

      final route = store.routes.firstWhere((r) => r.id == 'r1');
      final cancelled =
          route.stops.where((s) => s.status == DeliveryStatus.cancelled);
      expect(cancelled.length, 1);
      expect(cancelled.single.cancelReason, 'Не открыл дверь');
      expect(cancelled.single.cancelledAt, isNotNull);
      // Причина видна прямо в списке точек.
      expect(find.text('Не открыл дверь'), findsOneWidget);
    });

    testWidgets('отменённая точка на завершение не открывается и без меню',
        (tester) async {
      final store = MockStore();
      final route = store.routes.firstWhere((r) => r.id == 'r1');
      final open = route.stops.firstWhere((s) => s.status.isOpen);
      store.cancelStop(open.id, reason: 'Переехал');

      await pumpPage(
        tester,
        MockDriverRepository(store: store, driverId: 'd1'),
        const MyRouteDetailPage(routeId: 'r1'),
      );

      expect(find.text('Отменён'), findsOneWidget);
      expect(find.text('Переехал'), findsOneWidget);
      // В r1 было две открытые точки, одна отменена — меню осталось у одной.
      expect(find.byTooltip('Изменить статус'), findsOneWidget);

      await tester.tap(find.text('Переехал'));
      await settle(tester);
      expect(find.byType(DeliveryCompletionPage), findsNothing);
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

    test('показатели считаются по выбранному дню, а не по всем маршрутам', () {
      final today = dayOnly(DateTime.now());
      final state = MyRoutesState(date: today, routes: [
        route('r1', today, 2, 5),
        route('r2', today.subtract(const Duration(days: 1)), 4, 4),
      ]);

      expect(state.deliveredCount, 2);
      expect(state.stopsCount, 5);
      expect(state.routesCount, 1);
      expect(state.visible.map((r) => r.id), ['r1']);
    });

    test('выбор другого дня переводит на него и список, и показатели', () {
      final today = dayOnly(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));
      final state = MyRoutesState(date: today, routes: [
        route('r1', today, 2, 5),
        route('r2', yesterday, 4, 4),
      ]).copyWith(date: yesterday);

      expect(state.deliveredCount, 4);
      expect(state.stopsCount, 4);
      expect(state.routesCount, 1);
      expect(state.visible.map((r) => r.id), ['r2']);
    });

    test('день без маршрутов даёт нули и пустой список', () {
      final today = dayOnly(DateTime.now());
      final state = MyRoutesState(date: today, routes: [
        route('r1', today.subtract(const Duration(days: 3)), 3, 3),
      ]);

      expect(state.deliveredCount, 0);
      expect(state.stopsCount, 0);
      expect(state.routesCount, 0);
      expect(state.visible, isEmpty);
    });
  });

  group('Вкладки водителя строятся лениво', () {
    testWidgets('профиль не ходит в сеть, пока его не открыли', (tester) async {
      final repo = _CountingDriverRepository();
      // Профиль тянет за собой настройки темы и языка — в дереве приложения
      // их кладёт `app.dart`.
      await pumpPage(
        tester,
        repo,
        MultiBlocProvider(
          providers: [
            BlocProvider(
                create: (_) => ThemeCubit(storage: InMemorySettingsStorage())),
            BlocProvider(
                create: (_) => LocaleCubit(storage: InMemorySettingsStorage())),
          ],
          child: const DriverShell(),
        ),
      );

      // `IndexedStack` строит всех детей сразу — без заглушки профиль
      // тянул бы статистику при каждом входе водителя в приложение.
      expect(repo.orderPages, 0);

      await tester.tap(find.text('Профиль'));
      await settle(tester);

      expect(repo.orderPages, greaterThan(0));
    });
  });
}

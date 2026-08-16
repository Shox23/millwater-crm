import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/routes/presentation/route_form_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Записывает, какие операции правки и в каком порядке дошли до репозитория.
class _RecordingRepository extends MockCrmRepository {
  final List<String> calls = [];

  @override
  Future<RouteDetail> updateRouteDate({
    required String routeId,
    required DateTime date,
  }) {
    calls.add('date');
    return super.updateRouteDate(routeId: routeId, date: date);
  }

  @override
  Future<void> assignDriver({
    required String routeId,
    required String driverId,
  }) {
    calls.add('driver:$driverId');
    return super.assignDriver(routeId: routeId, driverId: driverId);
  }

  @override
  Future<void> addRouteCustomer({
    required String routeId,
    required String customerId,
  }) {
    calls.add('add:$customerId');
    return super.addRouteCustomer(routeId: routeId, customerId: customerId);
  }

  @override
  Future<void> removeRouteCustomer({
    required String routeId,
    required String customerId,
  }) {
    calls.add('remove:$customerId');
    return super.removeRouteCustomer(routeId: routeId, customerId: customerId);
  }
}

void main() {
  group('Правила правки по статусу', () {
    test('созданный маршрут открыт целиком', () {
      const status = RouteStatus.created;
      expect(status.canReschedule, isTrue);
      expect(status.canAddCustomers, isTrue);
      expect(status.canRemoveCustomers, isTrue);
      expect(status.isEditable, isTrue);
      expect(status.canCancel, isTrue);
    });

    test('в начатый можно только досыпать заказчиков', () {
      const status = RouteStatus.inProgress;
      // Водитель уже везёт: дату и водителя менять поздно, а удаление
      // точки стёрло бы выполненную доставку вместе с оплатой.
      expect(status.canReschedule, isFalse);
      expect(status.canRemoveCustomers, isFalse);
      expect(status.canAddCustomers, isTrue);
      expect(status.isEditable, isTrue);
      // Маршрут в пути ещё можно снять с рейса.
      expect(status.canCancel, isTrue);
    });

    test('завершённый и отменённый не редактируются', () {
      for (final status in [RouteStatus.completed, RouteStatus.cancelled]) {
        expect(status.isEditable, isFalse, reason: '$status');
        expect(status.canAddCustomers, isFalse, reason: '$status');
        // Завершённому отменять нечего: доставки выполнены, оплаты приняты.
        expect(status.canCancel, isFalse, reason: '$status');
      }
    });
  });

  group('Операции репозитория', () {
    late MockCrmRepository repo;

    setUp(() => repo = MockCrmRepository());

    Future<RouteDetail> freshRoute() => repo.createRoute(
          driverId: 'd1',
          date: DateTime(2026, 7, 6),
          customerIds: ['c1', 'c2'],
        );

    test('перенос даты не трогает состав точек', () async {
      final route = await freshRoute();

      final moved = await repo.updateRouteDate(
        routeId: route.id,
        date: DateTime(2026, 7, 9),
      );

      expect(moved.date, DateTime(2026, 7, 9));
      expect(moved.stops.length, 2);
    });

    test('смена водителя подтягивает и его имя', () async {
      final route = await freshRoute();
      final other = (await repo.getDrivers()).firstWhere((d) => d.id != 'd1');

      await repo.assignDriver(routeId: route.id, driverId: other.id);

      final updated = await repo.getRoute(route.id);
      expect(updated!.driverId, other.id);
      expect(updated.driverFullName, other.fullName);
    });

    test('добавление точки пересчитывает total_customers', () async {
      final route = await freshRoute();

      await repo.addRouteCustomer(routeId: route.id, customerId: 'c3');

      final updated = await repo.getRoute(route.id);
      expect(updated!.stops.length, 3);
      expect(updated.totalCustomers, 3);
    });

    test('тот же заказчик дважды не задваивает точку', () async {
      final route = await freshRoute();

      await repo.addRouteCustomer(routeId: route.id, customerId: 'c1');

      final updated = await repo.getRoute(route.id);
      expect(updated!.stops.length, 2);
    });

    test('удаление точки убирает её из маршрута', () async {
      final route = await freshRoute();

      await repo.removeRouteCustomer(routeId: route.id, customerId: 'c1');

      final updated = await repo.getRoute(route.id);
      expect(updated!.stops.length, 1);
      expect(updated.stops.single.customerId, 'c2');
      expect(updated.totalCustomers, 1);
    });
  });

  group('Форма правки', () {
    // Фикстуры берём прямо из стора и синхронно. Любой `await` по репозиторию
    // внутри testWidgets упёрся бы в таймер мока, а фейковые часы двигает
    // только pump — тест повис бы, не дойдя до первой проверки.
    RouteDetail routeWith(_RecordingRepository repo, RouteStatus status) =>
        repo.store.routes.firstWhere((r) => r.status == status);

    RouteDetail current(_RecordingRepository repo, String id) =>
        repo.store.routes.firstWhere((r) => r.id == id);

    Future<void> pumpForm(
      WidgetTester tester,
      CrmRepository repo,
      RouteDetail route,
    ) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: MaterialApp(
            // Без темы приложения нет ThemeExtension с токенами, и первый же
            // context.tokens валит сборку экрана.
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            home: RouteFormPage(route: route),
          ),
        ),
      );
      // Форма грузит водителей и заказчиков последовательно: второй таймер
      // ставится только после срабатывания первого, поэтому время двигаем
      // несколькими шагами, а не одним длинным.
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> tapRow(WidgetTester tester, String title) async {
      final finder = find.text(title);
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
      await tester.pump();
    }

    Future<void> save(WidgetTester tester) async {
      final button = find.widgetWithText(AppButton, 'Сохранить');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('без изменений кнопка сохранения заблокирована',
        (tester) async {
      final repo = _RecordingRepository();
      final route = routeWith(repo, RouteStatus.created);

      await pumpForm(tester, repo, route);

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Сохранить'),
      );
      expect(button.enabled, isFalse);
      expect(repo.calls, isEmpty);
    });

    testWidgets('правки уходят по одной: сначала удаление, потом добавление',
        (tester) async {
      final repo = _RecordingRepository();
      final route = routeWith(repo, RouteStatus.created);
      final inRoute = route.stops.map((s) => s.customerId).toSet();
      final removed = repo.store.customers
          .firstWhere((c) => c.id == route.stops.first.customerId);
      final added =
          repo.store.customers.firstWhere((c) => !inRoute.contains(c.id));

      await pumpForm(tester, repo, route);

      await tapRow(tester, removed.name);
      await tapRow(tester, added.name);
      await save(tester);

      // Ни даты, ни водителя не трогали — лишних запросов быть не должно,
      // и удаление обязано уйти раньше добавления.
      expect(repo.calls, ['remove:${removed.id}', 'add:${added.id}']);

      final updated = current(repo, route.id);
      expect(updated.stops.any((s) => s.customerId == removed.id), isFalse);
      expect(updated.stops.any((s) => s.customerId == added.id), isTrue);
    });

    testWidgets('в начатом маршруте точку снять нельзя, добавить можно',
        (tester) async {
      final repo = _RecordingRepository();
      final route = routeWith(repo, RouteStatus.inProgress);
      final inRoute = route.stops.map((s) => s.customerId).toSet();
      final existing = repo.store.customers
          .firstWhere((c) => c.id == route.stops.first.customerId);
      final added =
          repo.store.customers.firstWhere((c) => !inRoute.contains(c.id));

      await pumpForm(tester, repo, route);

      // Тап по уже входящей точке заблокирован правилом статуса.
      await tapRow(tester, existing.name);
      await tapRow(tester, added.name);
      await save(tester);

      expect(repo.calls, ['add:${added.id}']);

      final updated = current(repo, route.id);
      expect(updated.stops.any((s) => s.customerId == existing.id), isTrue);
    });
  });
}

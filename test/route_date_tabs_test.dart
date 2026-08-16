import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/utils/day.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/core/widgets/date_tabs.dart';
import 'package:crm_millwater/data/mock/seed_data.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/reports_summary.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/routes/bloc/routes_bloc.dart';
import 'package:crm_millwater/features/routes/presentation/route_detail_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Записывает периоды, с которыми экран ходил в репозиторий.
class _RecordingRepository extends MockCrmRepository {
  final List<(DateTime?, DateTime?)> routeRanges = [];
  final List<(DateTime?, DateTime?)> reportRanges = [];

  @override
  Future<List<RouteListItem>> getRoutes({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? driverId,
    RouteStatus? status,
  }) {
    routeRanges.add((dateFrom, dateTo));
    return super.getRoutes(
      dateFrom: dateFrom,
      dateTo: dateTo,
      driverId: driverId,
      status: status,
    );
  }

  @override
  Future<SummaryReport> getSummaryReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    reportRanges.add((dateFrom, dateTo));
    return super.getSummaryReport(dateFrom: dateFrom, dateTo: dateTo);
  }
}

/// Первый запрос списка падает, дальше репозиторий работает как обычно.
class _FlakyRepository extends MockCrmRepository {
  bool _failed = false;

  @override
  Future<List<RouteListItem>> getRoutes({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? driverId,
    RouteStatus? status,
  }) async {
    if (!_failed) {
      _failed = true;
      throw Exception('нет сети');
    }
    return super.getRoutes(
      dateFrom: dateFrom,
      dateTo: dateTo,
      driverId: driverId,
      status: status,
    );
  }
}

void main() {
  final today = dayOnly(DateTime.now());

  group('Лента дат', () {
    /// Поднимает только ленту: блок и репозиторий здесь ни при чём.
    Future<List<DateTime>> pumpTabs(
      WidgetTester tester, {
      required DateTime selected,
    }) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final picked = <DateTime>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          home: Scaffold(
            body: DateTabs(selected: selected, onSelected: picked.add),
          ),
        ),
      );
      // Лента после первого кадра подводит выбранный таб к центру — ждём,
      // иначе тап уедет вместе с анимацией.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return picked;
    }

    /// Табы за краем экрана лежат в горизонтальном скролле — сначала
    /// подкручиваем к ним, потом жмём.
    Future<void> tapTab(WidgetTester tester, String label) async {
      final finder = find.text(label);
      await tester.ensureVisible(finder);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(finder);
      await tester.pump();
    }

    testWidgets('окно — 15 дней вокруг выбранного', (tester) async {
      await pumpTabs(tester, selected: today);

      // Сегодняшний день подписан словом, соседние — числом.
      expect(find.text('Сегодня'), findsOneWidget);
      for (final offset in [-7, -1, 1, 7]) {
        final day = today.add(Duration(days: offset));
        final label =
            '${day.day.toString().padLeft(2, '0')}.'
            '${day.month.toString().padLeft(2, '0')}';
        expect(find.text(label), findsOneWidget, reason: 'смещение $offset');
      }
      // За границу окна не выходим.
      final beyond = today.add(const Duration(days: 8));
      final beyondLabel =
          '${beyond.day.toString().padLeft(2, '0')}.'
          '${beyond.month.toString().padLeft(2, '0')}';
      expect(find.text(beyondLabel), findsNothing);
    });

    testWidgets('тап отдаёт дату без времени', (tester) async {
      final picked = await pumpTabs(tester, selected: today);

      final tomorrow = today.add(const Duration(days: 1));
      final label =
          '${tomorrow.day.toString().padLeft(2, '0')}.'
          '${tomorrow.month.toString().padLeft(2, '0')}';
      await tapTab(tester, label);

      expect(picked, [tomorrow]);
      expect(picked.single.hour, 0);
      expect(picked.single.minute, 0);
    });

    testWidgets('когда сегодня вне окна — есть таб возврата', (tester) async {
      // Календарём можно уехать далеко; без отдельного таба вернуться нечем.
      final far = today.add(const Duration(days: 40));
      final picked = await pumpTabs(tester, selected: far);

      expect(find.text('Сегодня'), findsOneWidget);
      await tapTab(tester, 'Сегодня');

      expect(picked, [today]);
    });

    testWidgets('внутри окна отдельного таба возврата нет', (tester) async {
      await pumpTabs(tester, selected: today.add(const Duration(days: 3)));
      // «Сегодня» ровно одно — то, что в самом окне.
      expect(find.text('Сегодня'), findsOneWidget);
    });
  });

  group('Блок маршрутов и выбранный день', () {
    test('стартует с сегодняшнего дня и запрашивает его в обоих запросах',
        () async {
      final repo = _RecordingRepository();
      final bloc = RoutesBloc(repo)..add(const RoutesRequested());
      addTearDown(bloc.close);

      await bloc.stream.firstWhere((s) => s.status == RoutesStatus.ready);

      expect(bloc.state.date, today);
      expect(repo.routeRanges, [(today, today)]);
      expect(repo.reportRanges, [(today, today)]);
    });

    test('смена дня перезапрашивает список и сводку за этот день', () async {
      final repo = _RecordingRepository();
      final bloc = RoutesBloc(repo)..add(const RoutesRequested());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.status == RoutesStatus.ready);
      // Маршруты сида лежат на сегодня — с них и начинаем.
      expect(bloc.state.routes, isNotEmpty);

      // Уходим на пустой день…
      final tomorrow = today.add(const Duration(days: 1));
      bloc.add(RoutesDateChanged(tomorrow));
      await bloc.stream.firstWhere(
        (s) => s.status == RoutesStatus.ready && s.date == tomorrow,
      );

      expect(repo.routeRanges.last, (tomorrow, tomorrow));
      expect(repo.reportRanges.last, (tomorrow, tomorrow));
      expect(bloc.state.routes, isEmpty);
      expect(bloc.state.collected, 0);

      // …и возвращаемся — список снова наполняется.
      bloc.add(RoutesDateChanged(today));
      await bloc.stream.firstWhere(
        (s) => s.status == RoutesStatus.ready && s.date == today,
      );

      expect(repo.routeRanges.last, (today, today));
      expect(bloc.state.routes, isNotEmpty);
    });

    test('повторный выбор того же дня в сеть не ходит', () async {
      final repo = _RecordingRepository();
      final bloc = RoutesBloc(repo)..add(const RoutesRequested());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.status == RoutesStatus.ready);

      // Время внутри дня приходит разное — сравнение должно быть по дню.
      bloc.add(RoutesDateChanged(DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(repo.routeRanges, hasLength(1));
    });

    test('при смене дня список очищается сразу', () async {
      final repo = _RecordingRepository();
      final bloc = RoutesBloc(repo)..add(RoutesDateChanged(_anyDay));
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.status == RoutesStatus.ready);

      bloc.add(RoutesDateChanged(SeedData.today));
      // Первое же состояние после смены дня: вчерашних маршрутов в нём быть
      // не должно, иначе они мелькают под новой подписью.
      final next = await bloc.stream.first;
      expect(next.date, SeedData.today);
      expect(next.routes, isEmpty);
      expect(next.collected, 0);
    });

    test('после отказа и удачного повтора состояние чистое', () async {
      final bloc = RoutesBloc(_FlakyRepository())
        ..add(const RoutesRequested());
      addTearDown(bloc.close);

      await bloc.stream.firstWhere((s) => s.status == RoutesStatus.error);
      bloc.add(const RoutesRequested());
      final ready =
          await bloc.stream.firstWhere((s) => s.status == RoutesStatus.ready);

      expect(ready.status, RoutesStatus.ready);
    });
  });

  group('Фильтрация по датам в моке', () {
    test('getRoutes отдаёт только маршруты дня', () async {
      final repo = MockCrmRepository();

      final onSeedDay = await repo.getRoutes(
        dateFrom: SeedData.today,
        dateTo: SeedData.today,
      );
      final dayAfter = SeedData.today.add(const Duration(days: 1));
      final onEmptyDay =
          await repo.getRoutes(dateFrom: dayAfter, dateTo: dayAfter);

      expect(onSeedDay, isNotEmpty);
      expect(onEmptyDay, isEmpty);
      // Без периода поведение прежнее — весь список.
      expect(await repo.getRoutes(), hasLength(onSeedDay.length));
    });

    test('сводка считается по маршрутам того же периода', () async {
      final repo = MockCrmRepository();
      final dayAfter = SeedData.today.add(const Duration(days: 1));

      final empty =
          await repo.getSummaryReport(dateFrom: dayAfter, dateTo: dayAfter);
      final seeded = await repo.getSummaryReport(
        dateFrom: SeedData.today,
        dateTo: SeedData.today,
      );

      expect(empty.routesCount, 0);
      expect(empty.totalRevenue, 0);
      expect(seeded.routesCount, greaterThan(0));
    });
  });

  group('Нижняя панель карточки маршрута', () {
    Future<void> pumpDetail(
      WidgetTester tester,
      CrmRepository repo,
      String routeId,
    ) async {
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
            home: RouteDetailPage(routeId: routeId),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('у завершённого маршрута кнопок нет', (tester) async {
      final repo = MockCrmRepository();
      final completed = repo.store.routes
          .firstWhere((r) => r.status == RouteStatus.completed);

      await pumpDetail(tester, repo, completed.id);

      expect(find.widgetWithText(AppButton, 'Отменить маршрут'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Редактировать'), findsNothing);
    });

    testWidgets('у созданного есть и отмена, и правка', (tester) async {
      final repo = MockCrmRepository();
      final created =
          repo.store.routes.firstWhere((r) => r.status == RouteStatus.created);

      await pumpDetail(tester, repo, created.id);

      expect(find.widgetWithText(AppButton, 'Отменить маршрут'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Редактировать'), findsOneWidget);
    });

    testWidgets('у начатого отмена есть — снять с рейса можно', (tester) async {
      final repo = MockCrmRepository();
      final inProgress = repo.store.routes
          .firstWhere((r) => r.status == RouteStatus.inProgress);

      await pumpDetail(tester, repo, inProgress.id);

      expect(find.widgetWithText(AppButton, 'Отменить маршрут'), findsOneWidget);
    });
  });
}

/// Заведомо пустой день — блок стартует с него, чтобы первый запрос был
/// быстрым и предсказуемым.
final _anyDay = DateTime(2026, 1, 15);

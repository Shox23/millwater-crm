import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/navigation/overlay_route.dart';
import 'package:crm_millwater/data/mock/seed_data.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/presentation/customer_form_page.dart';
import 'package:crm_millwater/features/routes/presentation/route_detail_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Свайп «назад» от левого края — тот самый жест, которого на iPhone не было.
/// Проверяется единственным честным способом: пальцем по экрану.
///
/// `pumpAndSettle` здесь не используется: у формы заказчика в режиме создания
/// стоит `autofocus`, и на нём ожидание покоя не заканчивается никогда.
/// Сид берётся синхронно — у мока задержка в 150 мс, а `await` в теле теста
/// под фейковыми часами её не дожидается.
void main() {
  final repo = MockCrmRepository();

  void useIphone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Открывает экран поверх корня — как это делает приложение.
  Future<void> pushOverlay(WidgetTester tester, Widget page) async {
    useIphone(tester);
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      RepositoryProvider<CrmRepository>.value(
        value: repo,
        child: MaterialApp(
          navigatorKey: navigator,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: const Scaffold(body: Center(child: Text('корень'))),
        ),
      ),
    );

    navigator.currentState!.push(OverlayPageRoute<void>(builder: (_) => page));
    await settle(tester);
  }

  /// Тянет от самого края вправо — так закрывают экран на iOS.
  Future<void> swipeBack(WidgetTester tester) async {
    await tester.dragFrom(const Offset(2, 400), const Offset(600, 0));
    await settle(tester);
  }

  group('Переход по платформам', () {
    testWidgets('на iOS экран ведёт системный переход — с ним приходит жест',
        (tester) async {
      await pushOverlay(tester, const Scaffold(body: Text('экран')));

      expect(find.byType(CupertinoPageTransition), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('на Android остаётся прежний fade + rise', (tester) async {
      await pushOverlay(tester, const Scaffold(body: Text('экран')));

      expect(find.byType(CupertinoPageTransition), findsNothing);
      expect(find.byType(SlideTransition), findsWidgets);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('Свайп назад', () {
    testWidgets('закрывает обычный экран', (tester) async {
      await pushOverlay(tester, const Scaffold(body: Text('экран')));
      expect(find.text('экран'), findsOneWidget);

      await swipeBack(tester);

      expect(find.text('экран'), findsNothing);
      expect(find.text('корень'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('закрывает нетронутую форму', (tester) async {
      await pushOverlay(
          tester, CustomerFormPage(customer: SeedData.customers().first));
      expect(find.text('корень'), findsNothing);

      await swipeBack(tester);

      // Ушли без вопросов: терять нечего, ни одного поля не правили.
      expect(find.text('корень'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('не закрывает форму с несохранёнными правками',
        (tester) async {
      await pushOverlay(
          tester, CustomerFormPage(customer: SeedData.customers().first));

      await tester.enterText(find.byType(TextFormField).first, 'Новое имя');
      await settle(tester);

      await swipeBack(tester);

      // Правки на месте, экран не ушёл: жест погашен намеренно.
      expect(find.text('корень'), findsNothing);
      expect(find.text('Новое имя'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('закрывает карточку маршрута', (tester) async {
      await pushOverlay(
          tester, RouteDetailPage(routeId: SeedData.routes().first.id));
      expect(find.text('корень'), findsNothing);

      await swipeBack(tester);

      expect(find.text('корень'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}

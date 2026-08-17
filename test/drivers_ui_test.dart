import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/mock/seed_data.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/drivers/presentation/driver_detail_page.dart';
import 'package:crm_millwater/features/drivers/presentation/drivers_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockCrmRepository repo;

  setUp(() => repo = MockCrmRepository());

  void useLargeSurface(WidgetTester tester) {
    // В тестах вместо Inter подставляется шрифт тестового рендерера с более
    // широкими глифами — на узком экране подписи в него не влезают.
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      RepositoryProvider<CrmRepository>.value(
        value: repo,
        child: MaterialApp(
            // Строки интерфейса берутся из локали: тесты идут на русской.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,theme: AppTheme.light(), home: page),
      ),
    );
    // Мок отвечает через Future.delayed — прокручиваем фейковые часы.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('Список водителей', () {
    testWidgets('в строке видно телефон — ТЗ требует его в списке',
        (tester) async {
      await pumpPage(tester, const DriversPage());

      expect(find.text('Азиз Каримов'), findsOneWidget);
      expect(find.text('+998 90 123 45 67'), findsOneWidget);
    });

    testWidgets('поиск не стирает список, пока идёт запрос', (tester) async {
      await pumpPage(tester, const DriversPage());
      expect(find.text('Азиз Каримов'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Азиз');
      // Дебаунс 300 мс, ответ мока ещё 150 — момент, когда запрос в пути.
      await tester.pump(const Duration(milliseconds: 350));

      // Раньше здесь на месте списка был спиннер, и список мигал на каждую
      // букву. Теперь показываем прежнюю выдачу и тонкую полоску прогресса.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Азиз Каримов'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('на первой загрузке спиннер всё-таки есть', (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            theme: AppTheme.light(),
            home: const DriversPage(),
          ),
        ),
      );
      // Показывать ещё нечего — здесь спиннер уместен.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('подпись шапки не выдаёт найденных за всю команду',
        (tester) async {
      await pumpPage(tester, const DriversPage());
      // ScreenHeader рисует подпись капсом.
      expect(find.textContaining('КОМАНДА · '), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Азиз');
      await tester.pump(const Duration(milliseconds: 800));

      // «Команда · 1» на двух буквах поиска — неправда: команда прежняя.
      expect(find.textContaining('КОМАНДА · '), findsNothing);
      expect(find.textContaining('НАЙДЕНО · '), findsOneWidget);
    });
  });

  group('Карточка водителя', () {
    testWidgets('показывает дату создания учётной записи', (tester) async {
      // Водитель берётся из сида напрямую: `await repo.getDrivers()` внутри
      // теста виджетов не дождётся — у мока `Future.delayed`, а часы здесь
      // фейковые и крутятся только через `pump`.
      final driver = SeedData.drivers().first;
      await pumpPage(tester, DriverDetailPage(driver: driver));

      expect(find.text('Дата создания'), findsOneWidget);
      expect(find.text('01.01.2026'), findsOneWidget);
    });
  });
}

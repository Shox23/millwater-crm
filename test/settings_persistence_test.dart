import 'package:crm_millwater/app/app.dart';
import 'package:crm_millwater/app/locale_cubit.dart';
import 'package:crm_millwater/app/settings/settings_storage.dart';
import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/app/theme/theme_cubit.dart';
import 'package:crm_millwater/data/network/session_storage.dart';
import 'package:crm_millwater/features/settings/presentation/widgets/language_selector_card.dart';
import 'package:crm_millwater/features/settings/presentation/widgets/theme_selector_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Выбор записывается в хранилище', () {
    test('тема сохраняется при каждом переключении', () async {
      final storage = InMemorySettingsStorage();
      final cubit = ThemeCubit(storage: storage);

      cubit.select(ThemeMode.dark);
      expect(storage.settings.themeMode, ThemeMode.dark);

      // Круговое переключение идёт тем же путём — тоже сохраняется.
      cubit.toggle();
      expect(storage.settings.themeMode, ThemeMode.system);
    });

    test('язык сохраняется, а возврат к системному стирает выбор', () async {
      final storage = InMemorySettingsStorage();
      final cubit = LocaleCubit(storage: storage);

      cubit.select(AppLocales.uz);
      expect(storage.settings.locale, AppLocales.uz);

      cubit.select(null);
      expect(storage.settings.locale, isNull);
    });
  });

  group('Сохранённое поднимается при запуске', () {
    test('прочитанные настройки становятся начальным состоянием', () {
      final storage = InMemorySettingsStorage();

      final theme = ThemeCubit(initial: ThemeMode.dark, storage: storage);
      final locale = LocaleCubit(initial: AppLocales.uz, storage: storage);

      expect(theme.state, ThemeMode.dark);
      expect(locale.state, AppLocales.uz);
    });

    testWidgets('приложение стартует сразу с сохранённым языком и темой',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(CrmApp(
        sessionStorage: InMemorySessionStorage(),
        settings: AppSettings(themeMode: ThemeMode.dark, locale: AppLocales.uz),
        settingsStorage: InMemorySettingsStorage(),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Экран входа сразу на узбекском — без перерисовки на глазах.
      expect(find.text('Tizimga kirish'), findsOneWidget);
      expect(find.text('Вход в систему'), findsNothing);

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });

  group('Настоящее хранилище', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('записанное читается обратно', () async {
      const storage = PrefsSettingsStorage();

      await storage.saveThemeMode(ThemeMode.dark);
      await storage.saveLocale(AppLocales.uz);

      final restored = await storage.load();
      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.locale, AppLocales.uz);
    });

    test('пустое хранилище — системные настройки', () async {
      final settings = await const PrefsSettingsStorage().load();

      expect(settings.themeMode, ThemeMode.system);
      expect(settings.locale, isNull);
    });

    test('мусор в хранилище не роняет запуск', () async {
      SharedPreferences.setMockInitialValues({
        'settings.theme_mode': 'neon',
        'settings.locale': 'de',
      });

      final settings = await const PrefsSettingsStorage().load();

      expect(settings.themeMode, ThemeMode.system);
      expect(settings.locale, isNull, reason: 'неподдерживаемый язык');
    });
  });

  group('Переключатели в настройках пишут в хранилище', () {
    Future<void> pumpCards(
      WidgetTester tester,
      SettingsStorage storage,
    ) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => ThemeCubit(storage: storage)),
            BlocProvider(create: (_) => LocaleCubit(storage: storage)),
          ],
          child: BlocBuilder<LocaleCubit, Locale?>(
            builder: (context, locale) => MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocales.supported,
              locale: locale ?? AppLocales.ru,
              theme: AppTheme.light(),
              home: const Scaffold(
                body: Column(
                  children: [ThemeSelectorCard(), LanguageSelectorCard()],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('выбор темы и языка уходит на диск', (tester) async {
      final storage = InMemorySettingsStorage();
      await pumpCards(tester, storage);

      await tester.tap(find.text('Тёмная'));
      await tester.pump();
      expect(storage.settings.themeMode, ThemeMode.dark);

      await tester.tap(find.text('O‘zbekcha'));
      await tester.pump();
      expect(storage.settings.locale, AppLocales.uz);
    });
  });
}

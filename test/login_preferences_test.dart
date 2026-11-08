// Язык и тема на экране входа: до входа профиль с настройками недоступен,
// а водитель, который не читает по-русски, должен переключиться сам.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/app.dart';
import 'package:crm_millwater/app/settings/settings_storage.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/network/session_storage.dart';
import 'package:crm_millwater/features/auth/presentation/login_page.dart';
import 'package:crm_millwater/features/driver/presentation/driver_shell.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Без сессии на диске экран входа в сеть не ходит; на всякий случай — 404.
class _NoServer implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString('', 404);
}

/// Пускает водителя; стартовые экраны оболочки получают пустые списки.
class _DriverServer implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Object body = switch (options.path) {
      '/auth/login' => const {
          'access_token': 'a',
          'refresh_token': 'r',
          'token_type': 'bearer',
          'role': 'driver',
        },
      '/auth/me' => const {
          'id': 'u1',
          'phone': '+998901234567',
          'role': 'driver',
        },
      _ => const <Object>[],
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  Future<InMemorySettingsStorage> pumpLogin(
    WidgetTester tester, {
    Size size = const Size(1290, 2796),
    HttpClientAdapter? server,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final settings = InMemorySettingsStorage();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server ?? _NoServer();
    await tester.pumpWidget(CrmApp(
      sessionStorage: InMemorySessionStorage(),
      settingsStorage: settings,
      dio: dio,
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(LoginPage), findsOneWidget);
    return settings;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('RU | UZ переводит экран входа и запоминает выбор',
      (tester) async {
    final settings = await pumpLogin(tester);
    expect(find.text('Вход в систему'), findsOneWidget);

    await tester.tap(find.text('UZ'));
    await settle(tester);

    expect(find.text('Tizimga kirish'), findsOneWidget);
    expect(find.text('Вход в систему'), findsNothing);
    expect(settings.settings.locale, AppLocales.uz);

    await tester.tap(find.text('RU'));
    await settle(tester);

    expect(find.text('Вход в систему'), findsOneWidget);
    expect(settings.settings.locale, AppLocales.ru);
  });

  group('Язык водителя после входа', () {
    Future<Locale> signInAsDriver(WidgetTester tester) async {
      final fields = find.byType(EditableText);
      await tester.enterText(fields.at(0), '+998901234567');
      await tester.enterText(fields.at(1), '12345678');
      await settle(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Войти'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      return Localizations.localeOf(tester.element(find.byType(DriverShell)));
    }

    testWidgets('нажатый на входе подсвеченный RU остаётся и после входа',
        (tester) async {
      final settings = await pumpLogin(tester, server: _DriverServer());
      // Без выбора подсвечен язык телефона — в тестах это русский.
      expect(find.text('Вход в систему'), findsOneWidget);

      await tester.tap(find.text('RU'));
      await settle(tester);
      expect(settings.settings.locale, AppLocales.ru);

      expect(await signInAsDriver(tester), AppLocales.ru);
    });

    testWidgets('без нажатия водитель после входа получает узбекский',
        (tester) async {
      final settings = await pumpLogin(tester, server: _DriverServer());

      expect(await signInAsDriver(tester), AppLocales.uz);
      expect(settings.settings.locale, isNull);
    });
  });

  testWidgets('меню темы включает тёмную и запоминает выбор', (tester) async {
    final settings = await pumpLogin(tester);
    Brightness brightness() =>
        Theme.of(tester.element(find.byType(LoginPage))).brightness;
    expect(brightness(), Brightness.light);

    await tester.tap(find.byTooltip('Тема · Как в системе'));
    await settle(tester);
    // В меню все три режима, текущий — «как в системе».
    expect(find.text('Как в системе'), findsOneWidget);
    expect(find.text('Светлая'), findsOneWidget);

    await tester.tap(find.text('Тёмная'));
    await settle(tester);

    expect(brightness(), Brightness.dark);
    expect(settings.settings.themeMode, ThemeMode.dark);
    expect(find.byTooltip('Тема · Тёмная'), findsOneWidget);
  });

  testWidgets('на телефоне 360dp переключатели помещаются', (tester) async {
    await pumpLogin(tester, size: const Size(1080, 2340));

    expect(tester.takeException(), isNull);
    expect(find.text('RU'), findsOneWidget);
    expect(find.text('UZ'), findsOneWidget);
  });
}

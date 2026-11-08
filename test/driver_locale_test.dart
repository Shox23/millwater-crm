// Язык водителя по умолчанию — узбекский: язык телефона у водителей часто
// русский или английский, а читают они в основном по-узбекски.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/app.dart';
import 'package:crm_millwater/app/locale_cubit.dart';
import 'package:crm_millwater/app/settings/settings_storage.dart';
import 'package:crm_millwater/data/models/user_role.dart';
import 'package:crm_millwater/data/network/session_storage.dart';
import 'package:crm_millwater/features/auth/bloc/auth_bloc.dart';
import 'package:crm_millwater/features/auth/presentation/login_page.dart';
import 'package:crm_millwater/features/driver/presentation/driver_shell.dart';
import 'package:crm_millwater/features/home/presentation/admin_shell.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// `/auth/me` отвечает ролью, остальное — пустыми списками.
class _FakeServer implements HttpClientAdapter {
  _FakeServer(this.role);

  final UserRole role;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Object body = switch (options.path) {
      '/auth/me' => {'id': 'u1', 'phone': '+998901234567', 'role': role.wire},
      // Стартовые экраны: водителю — массив маршрутов, админу — страницы.
      _ when role == UserRole.driver => const <Object>[],
      _ => const {'items': <Object>[], 'total': 0},
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
  test('без выбора водителю — узбекский, остальным — язык системы', () {
    expect(LocaleCubit.defaultFor(UserRole.driver), AppLocales.uz);
    expect(LocaleCubit.defaultFor(UserRole.admin), isNull);
    expect(LocaleCubit.defaultFor(null), isNull);
  });

  /// Поднимает приложение с сохранённой сессией [role] и выбором [chosen].
  /// Язык тестовой платформы — английский, то есть «системный» здесь русский.
  Future<void> pumpSignedIn(
    WidgetTester tester,
    UserRole role, {
    Locale? chosen,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(CrmApp(
      sessionStorage: InMemorySessionStorage({
        'access_token': 'stored-access',
        'refresh_token': 'stored-refresh',
        'role': role.wire,
      }),
      settings: AppSettings(locale: chosen),
      settingsStorage: InMemorySettingsStorage(),
      dio: Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _FakeServer(role),
    ));
    // Восстановление сессии и стартовые запросы оболочки: таймеры Dio надо
    // догнать, иначе тест падает на «A Timer is still pending».
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Locale localeOf(WidgetTester tester, Type screen) =>
      Localizations.localeOf(tester.element(find.byType(screen)));

  testWidgets('водитель без выбора видит узбекский, а после выхода вход — '
      'на языке системы', (tester) async {
    await pumpSignedIn(tester, UserRole.driver);
    expect(localeOf(tester, DriverShell), AppLocales.uz);

    tester
        .element(find.byType(DriverShell))
        .read<AuthBloc>()
        .add(const AuthLogoutRequested());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(localeOf(tester, LoginPage), AppLocales.ru);
  });

  testWidgets('выбранный водителем русский остаётся русским', (tester) async {
    await pumpSignedIn(tester, UserRole.driver, chosen: AppLocales.ru);
    expect(localeOf(tester, DriverShell), AppLocales.ru);
  });

  testWidgets('админ без выбора видит язык системы', (tester) async {
    await pumpSignedIn(tester, UserRole.admin);
    expect(localeOf(tester, AdminShell), AppLocales.ru);
  });
}

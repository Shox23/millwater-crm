import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/network/dio_client.dart';
import 'package:crm_millwater/data/network/session_storage.dart';
import 'package:crm_millwater/data/repositories/auth_repository.dart';
import 'package:crm_millwater/features/settings/presentation/change_password_page.dart';
import 'package:crm_millwater/features/settings/presentation/widgets/change_password_tile.dart';
import 'package:dio/dio.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Запоминает тела запросов и отвечает заданным статусом.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.status = 204, this.body = const <String, Object>{}});

  final int status;
  final Object body;

  /// Тела ушедших запросов — по ним проверяем, что и когда отправлено.
  final List<Map<String, dynamic>> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((options.data as Map).cast<String, dynamic>());
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  void useLargeSurface(WidgetTester tester) {
    // В тестах вместо Inter подставляется шрифт тестового рендерера с более
    // широкими глифами — на узком экране подписи кнопок в него не влезают.
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Прокачивает кадры вместо `pumpAndSettle`: автофокус держит мигающий
  /// курсор, и «до полной остановки» экран формы не доходит никогда.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  AuthRepository repositoryWith(_RecordingAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    return AuthRepository(dio, AuthTokenStore(InMemorySessionStorage()));
  }

  /// Открывает экран отдельным маршрутом — как в приложении, чтобы успешная
  /// смена пароля могла его закрыть.
  Future<void> pumpPage(
    WidgetTester tester,
    AuthRepository repository, {
    Widget page = const ChangePasswordPage(),
  }) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      RepositoryProvider<AuthRepository>.value(
        value: repository,
        child: MaterialApp(
            // Строки интерфейса берутся из локали: тесты идут на русской.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<bool>(builder: (_) => page)),
                  child: const Text('открыть'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await settle(tester);
  }

  /// Поле по подписи над ним: ближайший общий Column внутри LabeledTextField.
  Finder inputFor(String label) => find.descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Column))
            .first,
        matching: find.byType(TextField),
      );

  Future<void> fillForm(
    WidgetTester tester, {
    required String current,
    required String fresh,
    required String repeat,
  }) async {
    await tester.enterText(inputFor('Текущий пароль'), current);
    await tester.enterText(inputFor('Новый пароль'), fresh);
    await tester.enterText(inputFor('Повторите новый пароль'), repeat);
    await settle(tester);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text('Сменить'));
    // Ответ адаптера приходит через микротаску, Dio оставляет свои таймеры.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Активна ли кнопка отправки: форма блокирует её, пока есть ошибки.
  bool submitEnabled(WidgetTester tester) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, 'Сменить'))
          .enabled;

  /// Уводит фокус с текущего поля — по этому событию появляется первая
  /// подсветка ошибки.
  ///
  /// Два кадра: первый доносит смену фокуса до `FocusManager`, второй
  /// перерисовывает поле с ошибкой.
  Future<void> leaveField(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump();
  }

  group('Смена пароля', () {
    testWidgets('пустая форма: кнопка заблокирована, запроса нет',
        (tester) async {
      final adapter = _RecordingAdapter();
      await pumpPage(tester, repositoryWith(adapter));

      // Полей не касались — ошибок ещё не показываем.
      expect(find.text('Введите текущий пароль'), findsNothing);
      expect(submitEnabled(tester), isFalse);

      await submit(tester);

      expect(adapter.requests, isEmpty);
    });

    testWidgets('повтор должен совпадать с новым паролем', (tester) async {
      final adapter = _RecordingAdapter();
      await pumpPage(tester, repositoryWith(adapter));

      await fillForm(
        tester,
        current: 'oldpass',
        fresh: 'newpass',
        repeat: 'newpas',
      );
      await leaveField(tester);

      expect(find.text('Пароли не совпадают'), findsOneWidget);
      expect(submitEnabled(tester), isFalse);

      await submit(tester);
      expect(adapter.requests, isEmpty);
    });

    testWidgets('новый пароль не может повторять текущий', (tester) async {
      final adapter = _RecordingAdapter();
      await pumpPage(tester, repositoryWith(adapter));

      await fillForm(
        tester,
        current: 'oldpass',
        fresh: 'oldpass',
        repeat: 'oldpass',
      );
      await leaveField(tester);

      expect(find.text('Новый пароль совпадает с текущим'), findsOneWidget);
      expect(submitEnabled(tester), isFalse);

      await submit(tester);
      expect(adapter.requests, isEmpty);
    });

    testWidgets('короткий пароль отклоняется до запроса', (tester) async {
      final adapter = _RecordingAdapter();
      await pumpPage(tester, repositoryWith(adapter));

      await fillForm(tester, current: 'oldpass', fresh: '123', repeat: '123');
      await leaveField(tester);

      expect(find.text('Минимум 6 символов'), findsOneWidget);
      expect(submitEnabled(tester), isFalse);

      await submit(tester);
      expect(adapter.requests, isEmpty);
    });

    testWidgets('валидная форма отправляет пару паролей и закрывает экран',
        (tester) async {
      final adapter = _RecordingAdapter();
      await pumpPage(tester, repositoryWith(adapter));

      await fillForm(
        tester,
        current: 'oldpass',
        fresh: 'newpass',
        repeat: 'newpass',
      );
      await submit(tester);

      expect(adapter.requests, [
        {'old_password': 'oldpass', 'new_password': 'newpass'},
      ]);
      expect(find.byType(ChangePasswordPage), findsNothing);
    });

    testWidgets('отказ сервера читается как неверный текущий пароль',
        (tester) async {
      // Сервер отвечает 401: старый пароль не подошёл.
      final adapter = _RecordingAdapter(
        status: 401,
        body: const {
          'success': false,
          'error': {'code': 'INVALID_PASSWORD', 'message': 'Invalid password'},
        },
      );
      await pumpPage(tester, repositoryWith(adapter));

      await fillForm(
        tester,
        current: 'wrong',
        fresh: 'newpass',
        repeat: 'newpass',
      );
      await submit(tester);

      expect(find.text('Неверный текущий пароль.'), findsOneWidget);
      // Экран остаётся открытым: пароль не сменился, форму терять нельзя.
      expect(find.byType(ChangePasswordPage), findsOneWidget);
    });

    testWidgets('пункт настроек открывает форму и подтверждает успех',
        (tester) async {
      final adapter = _RecordingAdapter();
      await pumpPage(
        tester,
        repositoryWith(adapter),
        page: const Scaffold(body: Center(child: ChangePasswordTile())),
      );

      await tester.tap(find.text('Сменить пароль'));
      await settle(tester);
      expect(find.byType(ChangePasswordPage), findsOneWidget);

      await fillForm(
        tester,
        current: 'oldpass',
        fresh: 'newpass',
        repeat: 'newpass',
      );
      await submit(tester);

      expect(find.byType(ChangePasswordPage), findsNothing);
      expect(find.text('Пароль изменён'), findsOneWidget);
    });
  });
}

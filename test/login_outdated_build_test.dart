// Регрессия: «водитель не может войти, хотя пароль верный» (07.11).
//
// У водителя стоял APK от сентября, который ходит на `/auth/login` без
// `/api/v1`. nginx отвечает на такой путь своей HTML-страницей 404, а
// приложение принимало её за USER_NOT_FOUND: повторяло вход без «+» и
// показывало «Неверный телефон или пароль». Водитель перебирал пароли, хотя
// ни один до сервера даже не доходил.
//
// Здесь — что теперь отличается: страница nginx даёт «приложение устарело»
// без повтора, JSON-ответ 404 от бэкенда работает по-старому, а версия
// сборки видна на экране входа и в User-Agent.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/app.dart';
import 'package:crm_millwater/core/app_version.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/network/dio_client.dart';
import 'package:crm_millwater/data/network/session_storage.dart';
import 'package:crm_millwater/data/repositories/auth_repository.dart';
import 'package:crm_millwater/features/auth/bloc/auth_bloc.dart';
import 'package:crm_millwater/features/auth/presentation/login_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Встроенная страница nginx — 153 байта, ровно как в access.log 07.11.
const _nginx404 = '<html>\r\n'
    '<head><title>404 Not Found</title></head>\r\n'
    '<body>\r\n'
    '<center><h1>404 Not Found</h1></center>\r\n'
    '<hr><center>nginx/1.27.0</center>\r\n'
    '</body>\r\n'
    '</html>\r\n';

ResponseBody _html404() => ResponseBody.fromString(_nginx404, 404, headers: {
      Headers.contentTypeHeader: ['text/html'],
    });

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Отвечает всем одним и тем же и записывает, что у него спросили.
class _Server implements HttpClientAdapter {
  _Server(this._reply);

  final ResponseBody Function() _reply;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _reply();
  }

  List<String> get phones => [
        for (final r in requests) (r.data as Map)['phone'] as String,
      ];
}

Future<AuthState> _login(_Server server) async {
  final store = AuthTokenStore(InMemorySessionStorage());
  final bloc = AuthBloc(AuthRepository(buildDio(store, adapter: server), store));
  addTearDown(bloc.close);

  bloc.add(const AuthLoginRequested(phone: '+998901234567', password: '12345678'));
  return bloc.stream.firstWhere((s) => s.status != AuthStatus.authenticating);
}

void main() {
  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Millwater',
      packageName: 'uz.millwater.crm',
      version: '1.1.0',
      buildNumber: '2',
      buildSignature: '',
    );
    await AppVersion.load();
  });

  test('страница nginx весит 153 байта, как в access.log', () {
    expect(utf8.encode(_nginx404).length, 153);
  });

  group('Вход при 404', () {
    test('страница nginx — «приложение устарело», без повтора без «+»',
        () async {
      final server = _Server(_html404);

      final state = await _login(server);

      expect(state.status, AuthStatus.failure);
      expect(state.error, AuthError.outdated);
      // Повтор по тому же несуществующему пути ничего бы не дал.
      expect(server.phones, ['+998901234567']);
    });

    test('USER_NOT_FOUND от бэкенда — повтор без «+», затем «неверные данные»',
        () async {
      final server = _Server(() => _json(const {
            'success': false,
            'error': {'code': 'USER_NOT_FOUND', 'message': 'User not found'},
          }, 404));

      final state = await _login(server);

      expect(state.error, AuthError.credentials);
      expect(server.phones, ['+998901234567', '998901234567']);
    });

    test('любой JSON-ответ 404 считается ответом бэкенда, как раньше', () async {
      // Формат USER_NOT_FOUND вживую не снимался: сужать правило до кода
      // значило бы рискнуть входом по номерам без «+».
      final server = _Server(() => _json(const {'detail': 'Not Found'}, 404));

      final state = await _login(server);

      expect(state.error, AuthError.credentials);
      expect(server.phones, ['+998901234567', '998901234567']);
    });
  });

  test('версия сборки уходит в User-Agent нативных запросов', () async {
    expect(AppVersion.label, '1.1.0+2');
    final server = _Server(() => _json(const {}, 200));
    final dio = buildDio(AuthTokenStore(InMemorySessionStorage()), adapter: server);

    await dio.get<dynamic>('/ping');

    expect(server.requests.single.headers['User-Agent'],
        'crm_millwater/1.1.0+2 (android)');
  });

  testWidgets('экран входа показывает версию и «приложение устарело»',
      (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final server = _Server(_html404);
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server;
    await tester.pumpWidget(
        CrmApp(sessionStorage: InMemorySessionStorage(), dio: dio));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Версия 1.1.0+2'), findsOneWidget);

    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), '+998901234567');
    await tester.enterText(fields.at(1), '12345678');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(AppButton, 'Войти'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(
      find.text('Эта версия приложения устарела, сервер её не принимает. '
          'Установите новую.'),
      findsOneWidget,
    );
    expect(find.text('Неверный телефон или пароль.'), findsNothing);
    expect(server.requests, hasLength(1));
  });
}

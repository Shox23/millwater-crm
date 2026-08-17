import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/app.dart';
import 'package:crm_millwater/data/models/user_role.dart';
import 'package:crm_millwater/data/network/dio_client.dart';
import 'package:crm_millwater/data/network/session_storage.dart';
import 'package:crm_millwater/data/repositories/api_notifications_repository.dart';
import 'package:crm_millwater/data/repositories/auth_repository.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/notifications_repository.dart';
import 'package:crm_millwater/features/auth/presentation/login_page.dart';
import 'package:crm_millwater/features/driver/presentation/driver_shell.dart';
import 'package:crm_millwater/features/home/presentation/admin_shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Отвечает на запросы Dio без сети.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  /// path → (статус, тело).
  final (int, Object) Function(String path) handler;

  final List<String> requestedPaths = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    final (status, body) = handler(options.path);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Знает единственную учётку — записанную без «+».
class _RecordingLoginAdapter implements HttpClientAdapter {
  _RecordingLoginAdapter(this.tried);

  final List<String> tried;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final phone = (options.data as Map)['phone'] as String;
    tried.add(phone);

    if (phone.startsWith('+')) {
      return ResponseBody.fromString(
        jsonEncode(const {
          'success': false,
          'error': {'code': 'USER_NOT_FOUND', 'message': 'User not found'},
        }),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(const {
        'access_token': 'a',
        'refresh_token': 'r',
        'token_type': 'bearer',
        'role': 'admin',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Сессия на диске: приложение должно поднять её без экрана входа.
  InMemorySessionStorage storedSession(UserRole role) => InMemorySessionStorage({
        'access_token': 'stored-access',
        'refresh_token': 'stored-refresh',
        'role': role.wire,
      });

  Dio dioWith(_FakeAdapter adapter) =>
      Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;

  Future<void> pumpApp(
    WidgetTester tester, {
    required SessionStorage storage,
    required Dio dio,
  }) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(CrmApp(sessionStorage: storage, dio: dio));
    // Восстановление сессии (чтение хранилища + /auth/me), затем стартовые
    // запросы оболочки. Каждый запрос Dio оставляет свой таймер — их надо
    // догнать, иначе тест падает на «A Timer is still pending».
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  group('Разводка по ролям', () {
    testWidgets('без сохранённой сессии показывается вход', (tester) async {
      final adapter = _FakeAdapter((_) => (200, const {}));

      await pumpApp(
        tester,
        storage: InMemorySessionStorage(),
        dio: dioWith(adapter),
      );

      expect(find.byType(LoginPage), findsOneWidget);
      // Токена нет — сервер вообще не дёргается.
      expect(adapter.requestedPaths, isEmpty);
    });

    testWidgets('сохранённая сессия админа открывает админскую оболочку',
        (tester) async {
      final adapter = _FakeAdapter(
        (path) => switch (path) {
          '/auth/me' => (
              200,
              {'id': 'u1', 'phone': '+998901234567', 'role': 'admin'},
            ),
          // Стартовые запросы вкладок админа — пустые страницы.
          _ => (200, const {'items': <Object>[], 'total': 0}),
        },
      );

      await pumpApp(
        tester,
        storage: storedSession(UserRole.admin),
        dio: dioWith(adapter),
      );

      expect(find.byType(AdminShell), findsOneWidget);
      expect(find.byType(DriverShell), findsNothing);
      expect(adapter.requestedPaths, contains('/auth/me'));
    });

    testWidgets('сохранённая сессия водителя открывает водительскую оболочку',
        (tester) async {
      final adapter = _FakeAdapter(
        (path) => switch (path) {
          '/auth/me' => (
              200,
              {'id': 'u2', 'phone': '+998907654321', 'role': 'driver'},
            ),
          // Список своих маршрутов запрашивает стартовый экран водителя.
          _ => (200, const <Object>[]),
        },
      );

      await pumpApp(
        tester,
        storage: storedSession(UserRole.driver),
        dio: dioWith(adapter),
      );

      expect(find.byType(DriverShell), findsOneWidget);
      expect(find.byType(AdminShell), findsNothing);
      // Водитель не должен ходить в админскую часть API.
      expect(
        adapter.requestedPaths.where((p) => p.startsWith('/admin')),
        isEmpty,
      );
    });

    testWidgets('роль с сервера важнее сохранённой на диске', (tester) async {
      // На диске лежит admin, но учётку понизили до водителя.
      final adapter = _FakeAdapter(
        (path) => switch (path) {
          '/auth/me' => (
              200,
              {'id': 'u3', 'phone': '+998901112233', 'role': 'driver'},
            ),
          _ => (200, const <Object>[]),
        },
      );


      await pumpApp(
        tester,
        storage: storedSession(UserRole.admin),
        dio: dioWith(adapter),
      );

      expect(find.byType(DriverShell), findsOneWidget);
    });

    testWidgets('репозиторий виден экранам, открытым через Navigator.push',
        (tester) async {
      // Провайдер, лежащий в поддереве `home`, недоступен маршрутам, которые
      // кладутся рядом с ним: форма падала с ProviderNotFound ещё до запроса
      // и навсегда застревала в «Сохранение…».
      final adapter = _FakeAdapter(
        (path) => switch (path) {
          '/auth/me' => (
              200,
              {'id': 'u1', 'phone': '+998901234567', 'role': 'admin'},
            ),
          _ => (200, const {'items': <Object>[], 'total': 0}),
        },
      );

      await pumpApp(
        tester,
        storage: storedSession(UserRole.admin),
        dio: dioWith(adapter),
      );

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      late final BuildContext pushedContext;
      unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (context) {
          pushedContext = context;
          return const SizedBox.shrink();
        },
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(pushedContext.read<CrmRepository>(), isA<CrmRepository>());
    });

    /// Какой поток уведомлений оказался в дереве у этой роли.
    ///
    /// Админский поток несёт события по всем водителям: водителю его давать
    /// нельзя, и держится это тем же способом, что и остальные репозитории —
    /// в его поддереве такого провайдера просто нет.
    Future<String> streamPathFor(WidgetTester tester, UserRole role) async {
      final adapter = _FakeAdapter(
        (path) => switch (path) {
          '/auth/me' => (
              200,
              {'id': 'u1', 'phone': '+998901234567', 'role': role.wire},
            ),
          _ => (200, const {'items': <Object>[], 'total': 0}),
        },
      );
      await pumpApp(
        tester,
        storage: storedSession(role),
        dio: dioWith(adapter),
      );

      final context = tester.element(find.byType(Navigator).first);
      final repo = context.read<NotificationsRepository>();
      return (repo as ApiNotificationsRepository).path;
    }

    testWidgets('админ получает поток по всем водителям', (tester) async {
      expect(
        await streamPathFor(tester, UserRole.admin),
        ApiNotificationsRepository.adminPath,
      );
    });

    testWidgets('водителю админский поток не достаётся', (tester) async {
      expect(
        await streamPathFor(tester, UserRole.driver),
        ApiNotificationsRepository.driverPath,
      );
    });

    testWidgets('протухший токен возвращает на вход', (tester) async {
      final storage = storedSession(UserRole.admin);
      final adapter = _FakeAdapter(
        (_) => (401, const {'success': false, 'error': {'message': 'expired'}}),
      );

      await pumpApp(tester, storage: storage, dio: dioWith(adapter));

      expect(find.byType(LoginPage), findsOneWidget);
      // Негодная сессия стирается, а не остаётся на диске до следующего раза.
      expect(await storage.read('access_token'), isNull);
    });
  });

  group('AuthRepository', () {
    test('логин запоминает роль и токены', () async {
      final storage = InMemorySessionStorage();
      final store = AuthTokenStore(storage);
      final dio = dioWith(_FakeAdapter(
        (_) => (
          200,
          {
            'access_token': 'a',
            'refresh_token': 'r',
            'token_type': 'bearer',
            'role': 'driver',
          },
        ),
      ));

      final role = await AuthRepository(dio, store)
          .login(phone: '+998901234567', password: 'secret');

      expect(role, UserRole.driver);
      expect(store.role, UserRole.driver);
      expect(await storage.read('access_token'), 'a');
      expect(await storage.read('role'), 'driver');
    });

    test('учётка без «+» в базе всё равно пускает', () async {
      // Сервер телефоны не нормализует: админ заведён как 998901234567,
      // а приложение шлёт E.164. Первый запрос обязан получить 404,
      // второй — уйти без «+».
      final tried = <String>[];
      final storage = InMemorySessionStorage();
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.httpClientAdapter = _RecordingLoginAdapter(tried);

      final role = await AuthRepository(dio, AuthTokenStore(storage))
          .login(phone: '+998901234567', password: 'Admin123!');

      expect(role, UserRole.admin);
      expect(tried, ['+998901234567', '998901234567']);
    });

    test('выход стирает сессию с диска', () async {
      final storage = storedSession(UserRole.admin);
      final store = AuthTokenStore(storage);
      await store.restore();

      await AuthRepository(dioWith(_FakeAdapter((_) => (200, const {}))), store)
          .logout();

      expect(store.isAuthenticated, isFalse);
      expect(store.role, isNull);
      expect(await storage.read('refresh_token'), isNull);
    });
  });
}

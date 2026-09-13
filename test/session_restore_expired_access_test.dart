// Регрессия: «после закрытия приложения нужно заново логиниться».
//
// Access-токен живёт 15 минут, refresh — 30 дней (см. PROMPT_PROJECT_CONTEXT.md).
// Если приложение открыли позже, `/auth/me` при восстановлении сессии
// отвечает 401 на протухший access. Раньше `_AuthInterceptor` считал любой
// путь `/auth/*` служебным и не пытался обновить токен на 401 от него —
// `restoreSession` принимал это за отказ сервера и стирал рабочий
// refresh-токен. Тест гоняет боевую цепочку `buildDio` + `restoreSession`.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/data/models/user_role.dart';
import 'package:crm_millwater/data/network/dio_client.dart';
import 'package:crm_millwater/data/network/session_storage.dart';
import 'package:crm_millwater/data/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Сервер как на стенде: access протух, refresh живой.
class _ExpiredAccessServer implements HttpClientAdapter {
  final List<String> log = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    log.add('${options.method} ${options.path} [$auth]');

    if (options.path == '/auth/refresh') {
      return _json(const {
        'access_token': 'fresh-access',
        'refresh_token': 'stored-refresh', // сервер refresh не ротирует
        'token_type': 'bearer',
        'role': 'driver',
      }, 200);
    }

    if (options.path == '/auth/me') {
      if (auth == 'Bearer fresh-access') {
        return _json(const {
          'id': 'u1',
          'phone': '+998900000099',
          'role': 'driver',
        }, 200);
      }
      // Ровно то, что отдаёт InvalidTokenError на бэкенде.
      return _json(const {
        'success': false,
        'error': {'code': 'INVALID_TOKEN', 'message': 'Invalid token'},
      }, 401);
    }

    return _json(const {}, 404);
  }
}

/// Сервер, у которого refresh-токен тоже мёртв — сессию действительно пора
/// стереть, и это должно продолжать работать после фикса.
class _DeadRefreshServer implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _json(const {
      'success': false,
      'error': {'code': 'INVALID_TOKEN', 'message': 'Invalid token'},
    }, 401);
  }
}

void main() {
  group('Восстановление сессии при протухшем access-токене', () {
    test('401 от /auth/me запускает refresh, а не стирает сессию', () async {
      final storage = InMemorySessionStorage({
        'access_token': 'stored-access',
        'refresh_token': 'stored-refresh',
        'role': 'driver',
      });
      final store = AuthTokenStore(storage);
      final server = _ExpiredAccessServer();
      final dio = buildDio(store, adapter: server);

      final role = await AuthRepository(dio, store).restoreSession();

      expect(role, UserRole.driver,
          reason: 'refresh-токен живой, сессия должна подняться');
      expect(await storage.read('refresh_token'), 'stored-refresh',
          reason: 'хранилище не должно быть стёрто');
      expect(server.log.any((l) => l.contains('/auth/refresh')), isTrue,
          reason: 'на 401 от /auth/me должен был уйти /auth/refresh');
    });

    test('мёртвый refresh-токен по-прежнему возвращает на вход', () async {
      final storage = InMemorySessionStorage({
        'access_token': 'stored-access',
        'refresh_token': 'dead-refresh',
        'role': 'driver',
      });
      final store = AuthTokenStore(storage);
      final dio = buildDio(store, adapter: _DeadRefreshServer());

      final role = await AuthRepository(dio, store).restoreSession();

      expect(role, isNull);
      expect(await storage.read('access_token'), isNull,
          reason: 'сессия без рабочего refresh-токена должна стираться');
    });
  });
}

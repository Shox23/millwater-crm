import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/user_role.dart';
import 'api_config.dart';
import 'api_envelope.dart';
import 'session_storage.dart';

/// Хранилище сессии: токены и роль в памяти + запись в защищённое хранилище.
///
/// В памяти держим потому, что интерсептор подставляет токен синхронно;
/// [SessionStorage] нужен, чтобы сессия пережила перезапуск приложения.
class AuthTokenStore {
  AuthTokenStore([SessionStorage? storage])
      : _storage = storage ?? const SecureSessionStorage();

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kRole = 'role';

  final SessionStorage _storage;

  String? accessToken;
  String? refreshToken;
  UserRole? role;

  /// Вызывается, когда refresh не удался — сессия истекла.
  VoidCallback? onSessionExpired;

  bool get isAuthenticated => accessToken != null;

  /// Поднимает сессию из хранилища. Возвращает true, если токен нашёлся.
  Future<bool> restore() async {
    accessToken = await _storage.read(_kAccess);
    refreshToken = await _storage.read(_kRefresh);
    role = UserRole.tryFromJson(await _storage.read(_kRole));
    return isAuthenticated;
  }

  /// Сохраняет пару токенов (и роль, если она известна) в памяти и на диске.
  Future<void> setTokens({
    required String access,
    required String refresh,
    UserRole? role,
  }) async {
    accessToken = access;
    refreshToken = refresh;
    // Refresh роль не возвращает — не затираем известную.
    if (role != null) this.role = role;

    await _storage.write(_kAccess, access);
    await _storage.write(_kRefresh, refresh);
    final current = this.role;
    if (current != null) await _storage.write(_kRole, current.wire);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    role = null;
    await _storage.deleteAll();
  }
}

/// Подставляет Bearer-токен и обновляет его при 401 (один раз), повторяя запрос.
class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._store, this._bareDio);

  final AuthTokenStore _store;

  /// Dio без интерсепторов — для refresh и повтора запроса.
  final Dio _bareDio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _store.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final is401 = err.response?.statusCode == 401;
    final isAuthCall = err.requestOptions.path.contains('/auth/');
    final canRefresh = _store.refreshToken != null;

    if (!is401 || isAuthCall || !canRefresh) {
      return handler.next(err);
    }

    try {
      final res = await _bareDio.post('/auth/refresh', data: {
        'refresh_token': _store.refreshToken,
      });
      final data = asMap(res.data);
      // Пишем и в хранилище: иначе после ротации на диске останется
      // протухшая пара и следующий запуск начнётся с разлогина.
      await _store.setTokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );

      // Повторяем исходный запрос с новым токеном.
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer ${_store.accessToken}';
      final retry = await _bareDio.fetch(opts);
      return handler.resolve(retry);
    } catch (_) {
      await _store.clear();
      _store.onSessionExpired?.call();
      return handler.next(err);
    }
  }
}

/// Собирает настроенный [Dio], разделяемый Auth- и Api-репозиториями.
Dio buildDio(AuthTokenStore store) {
  BaseOptions options() => BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      );

  final bareDio = Dio(options());
  final dio = Dio(options());

  dio.interceptors.add(_AuthInterceptor(store, bareDio));
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  return dio;
}

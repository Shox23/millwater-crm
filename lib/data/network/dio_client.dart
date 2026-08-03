import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'api_envelope.dart';

/// Хранилище JWT-токенов сессии (пока в памяти).
class AuthTokenStore {
  String? accessToken;
  String? refreshToken;

  /// Вызывается, когда refresh не удался — сессия истекла.
  VoidCallback? onSessionExpired;

  bool get isAuthenticated => accessToken != null;

  void setTokens({required String access, required String refresh}) {
    accessToken = access;
    refreshToken = refresh;
  }

  void clear() {
    accessToken = null;
    refreshToken = null;
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
      _store.setTokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );

      // Повторяем исходный запрос с новым токеном.
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer ${_store.accessToken}';
      final retry = await _bareDio.fetch(opts);
      return handler.resolve(retry);
    } catch (_) {
      _store.clear();
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

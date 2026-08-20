import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/user_role.dart';
import 'api_config.dart';
import 'api_envelope.dart';
import 'breadcrumb_interceptor.dart';
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

  /// Обновление пары токенов; ставит [buildDio].
  ///
  /// Сам стор в сеть не ходит, но добраться до обновления нужно не только
  /// интерсептору: поток уведомлений при 401 переподключается сам, а
  /// [TokenRefresher] спрятан внутри клиента.
  Future<bool> Function()? refreshTokens;

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

/// Ключ в `RequestOptions.extra`: не обновлять токен и не повторять запрос
/// при 401, отдать ошибку вызывающему как есть.
///
/// Нужен потоку уведомлений: «повторить» для него значит открыть соединение
/// заново и продолжить с `Last-Event-ID`, а не вернуть кому-то ответ.
const kNoAuthRetry = 'no_auth_retry';

/// Обновляет пару токенов по refresh-токену.
///
/// Вынесено из интерсептора, потому что тем же путём обновляет токен поток
/// уведомлений: там 401 приходит на открытии соединения, и повтор запроса
/// интерсептором ему не поможет.
///
/// Параллельные вызовы разделяют одну попытку: у потока и у обычного запроса
/// токен протухает одновременно, а второй refresh с уже потраченным
/// одноразовым токеном сервер отклонит — и разлогинит живую сессию.
class TokenRefresher {
  TokenRefresher(this._store, this._dio);

  final AuthTokenStore _store;

  /// Dio без интерсепторов: иначе 401 на самом refresh ушёл бы на второй круг.
  final Dio _dio;

  Future<bool>? _inFlight;

  /// `false` — сессия не восстановилась; она уже стёрта, экран входа впереди.
  Future<bool> refresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<bool> _refresh() async {
    final token = _store.refreshToken;
    if (token == null) return false;
    try {
      final res = await _dio.post('/auth/refresh', data: {
        'refresh_token': token,
      });
      final data = asMap(res.data);
      // Пишем и в хранилище: иначе после ротации на диске останется
      // протухшая пара и следующий запуск начнётся с разлогина.
      await _store.setTokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      await _store.clear();
      _store.onSessionExpired?.call();
      return false;
    }
  }
}

/// Подставляет Bearer-токен и обновляет его при 401 (один раз), повторяя запрос.
class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._store, this._bareDio, this._refresher);

  final AuthTokenStore _store;

  /// Dio без интерсепторов — для refresh и повтора запроса.
  final Dio _bareDio;

  final TokenRefresher _refresher;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _store.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// Тело исходного запроса, пригодное для повторной отправки.
  ///
  /// `FormData` одноразова: первая попытка вычитывает её поток, и повтор того
  /// же объекта ушёл бы с пустым телом. Задевает это ровно тот запрос, где
  /// 401 наиболее вероятен, — завершение доставки с фото у водителя на плохой
  /// связи. `clone()` пересобирает part'ы, а `MultipartFile.fromFile` хранит
  /// не поток, а `() => file.openRead()`, поэтому файл читается заново.
  ///
  /// Остальные тела (Map, String) повтор переживают как есть.
  static dynamic _retryBody(dynamic data) =>
      data is FormData ? data.clone() : data;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final is401 = err.response?.statusCode == 401;
    final isAuthCall = err.requestOptions.path.contains('/auth/');
    final canRefresh = _store.refreshToken != null;
    final ownRetry = err.requestOptions.extra[kNoAuthRetry] == true;

    if (!is401 || isAuthCall || !canRefresh || ownRetry) {
      return handler.next(err);
    }

    if (!await _refresher.refresh()) return handler.next(err);

    try {
      // Повторяем исходный запрос с новым токеном.
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer ${_store.accessToken}';
      opts.data = _retryBody(opts.data);
      final retry = await _bareDio.fetch(opts);
      return handler.resolve(retry);
    } catch (_) {
      // Токен обновился, а повтор всё равно не прошёл: сессия тут ни при чём,
      // отдаём исходную ошибку вызывающему.
      return handler.next(err);
    }
  }
}

/// Собирает настроенный [Dio], разделяемый Auth- и Api-репозиториями.
///
/// [adapter] подменяется в тестах и ставится на оба клиента: refresh и повтор
/// запроса идут через внутренний «голый» Dio, до которого снаружи не
/// добраться, — без этого шва поведение при 401 проверить нечем.
Dio buildDio(AuthTokenStore store, {HttpClientAdapter? adapter}) {
  BaseOptions options() => BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      );

  final bareDio = Dio(options());
  final dio = Dio(options());
  if (adapter != null) {
    bareDio.httpClientAdapter = adapter;
    dio.httpClientAdapter = adapter;
  }

  // Один обновлятель на клиента: поток уведомлений обновляет токен в обход
  // интерсептора, и две параллельные попытки сожгли бы refresh-токен.
  final refresher = TokenRefresher(store, bareDio);
  store.refreshTokens = refresher.refresh;

  dio.interceptors.add(_AuthInterceptor(store, bareDio, refresher));
  // След запросов в отчёте об ошибке. После интерсептора авторизации: повтор
  // после обновления токена должен попасть в след как отдельная попытка.
  dio.interceptors.add(BreadcrumbInterceptor());
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  return dio;
}

import 'package:dio/dio.dart';

import '../../core/utils/uz_phone.dart';
import '../models/user_role.dart';
import '../network/api_envelope.dart';
import '../network/dio_client.dart';

/// Авторизация: логин, роль и хранение сессии (refresh делает интерсептор Dio).
class AuthRepository {
  AuthRepository(this._dio, this._store);

  final Dio _dio;
  final AuthTokenStore _store;

  bool get isAuthenticated => _store.isAuthenticated;
  UserRole? get role => _store.role;

  /// Вход по телефону и паролю. Роль приходит в ответе (`LoginResponse.role`).
  ///
  /// [phone] ожидается в E.164 (`+998901234567`). Сервер телефоны не
  /// нормализует и сверяет строкой, а часть учёток заведена без «+» —
  /// поэтому при USER_NOT_FOUND пробуем второй раз без него.
  Future<UserRole> login({
    required String phone,
    required String password,
  }) async {
    Response<dynamic> res;
    try {
      res = await _postLogin(phone, password);
    } on DioException catch (e) {
      final bare = UzPhone.normalizeBare(phone);
      if (e.response?.statusCode != 404 || bare == phone) rethrow;
      res = await _postLogin(bare, password);
    }
    final data = asMap(res.data);
    final role = UserRole.tryFromJson(data['role'] as String?);
    if (role == null) {
      // Неизвестная роль — не наш случай: пускать некуда.
      throw StateError('Unknown user role: ${data['role']}');
    }
    await _store.setTokens(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
      role: role,
    );
    return role;
  }

  Future<Response<dynamic>> _postLogin(String phone, String password) =>
      _dio.post('/auth/login', data: {'phone': phone, 'password': password});

  /// Текущий пользователь по токену (`GET /auth/me`).
  Future<UserResponse> me() async {
    final res = await _dio.get('/auth/me');
    return UserResponse.fromJson(asMap(res.data));
  }

  /// Поднимает сессию с диска и подтверждает её у сервера.
  ///
  /// Возвращает `null`, если сессии нет или сервер её отверг — тогда
  /// пользователя ждёт экран входа.
  ///
  /// Недоступный сервер сессию не трогает: водитель открывает приложение
  /// в подвале, в лифте и во дворе-колодце, и разлогинивать его там, где
  /// он даже пароль ввести не сможет, — значит срывать смену. Роль в этом
  /// случае берётся с диска: её подтвердил прошлый успешный вход, а первый
  /// же запрос по восстановившейся связи проверит токен заново.
  Future<UserRole?> restoreSession() async {
    if (!await _store.restore()) return null;

    try {
      final user = await me();
      // Роль на сервере могли поменять — доверяем ответу, а не диску.
      await _store.setTokens(
        access: _store.accessToken!,
        refresh: _store.refreshToken!,
        role: user.role,
      );
      return user.role;
    } on DioException catch (e) {
      if (_isUnreachable(e)) return _store.role;
      // Сервер ответил (401 после неудачного refresh и прочее) — сессии нет.
      await _store.clear();
      return null;
    } catch (_) {
      // Неожиданное (например, сменившийся формат ответа) — безопаснее
      // попросить войти заново, чем работать с непонятной сессией.
      await _store.clear();
      return null;
    }
  }

  /// Ответа от сервера не было вовсе — о судьбе сессии это ничего не говорит.
  ///
  /// `unknown` сюда входит намеренно: в него dio заворачивает `SocketException`,
  /// а импортировать `dart:io` ради его проверки не хочется.
  static bool _isUnreachable(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError ||
        DioExceptionType.unknown =>
          true,
        _ => false,
      };

  /// Меняет пароль текущей учётной записи (`POST /auth/change-password`).
  ///
  /// Требуется старый пароль, поэтому чужой пароль этим методом не сбросить:
  /// водителю, забывшему свой, нужен отдельный админский эндпоинт — его в
  /// API пока нет.
  ///
  /// Токены остаются прежними: сервер их не возвращает. Если он всё-таки
  /// отзовёт сессию, следующий 401 разлогинит обычным путём.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _dio.post('/auth/change-password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<void> logout() => _store.clear();
}

/// Ответ `GET /auth/me`.
class UserResponse {
  const UserResponse({
    required this.id,
    required this.phone,
    required this.role,
  });

  final String id;
  final String phone;
  final UserRole role;

  factory UserResponse.fromJson(Map<String, dynamic> json) => UserResponse(
        id: json['id'] as String,
        phone: json['phone'] as String,
        role: UserRole.tryFromJson(json['role'] as String?) ?? UserRole.driver,
      );
}

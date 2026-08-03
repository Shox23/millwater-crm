import 'package:dio/dio.dart';

import '../network/api_envelope.dart';
import '../network/dio_client.dart';

/// Авторизация: логин и хранение токенов (refresh делает интерсептор Dio).
class AuthRepository {
  AuthRepository(this._dio, this._store);

  final Dio _dio;
  final AuthTokenStore _store;

  bool get isAuthenticated => _store.isAuthenticated;

  Future<void> login({
    required String phone,
    required String password,
  }) async {
    final res = await _dio.post('/auth/login', data: {
      'phone': phone,
      'password': password,
    });
    final data = asMap(res.data);
    _store.setTokens(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
  }

  void logout() => _store.clear();
}

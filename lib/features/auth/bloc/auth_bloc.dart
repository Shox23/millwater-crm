import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthState()) {
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthSessionExpired>(_onSessionExpired);
  }

  final AuthRepository _repository;

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.authenticating, clearError: true));
    try {
      await _repository.login(phone: event.phone, password: event.password);
      emit(state.copyWith(status: AuthStatus.authenticated));
    } on DioException catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        error: _messageFor(e),
      ));
    } catch (_) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        error: 'Не удалось войти. Попробуйте ещё раз.',
      ));
    }
  }

  void _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) {
    _repository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void _onSessionExpired(AuthSessionExpired event, Emitter<AuthState> emit) {
    emit(const AuthState(
      status: AuthStatus.unauthenticated,
      error: 'Сессия истекла. Войдите снова.',
    ));
  }

  String _messageFor(DioException e) {
    final code = e.response?.statusCode;
    // Неверные учётные данные: сервер отдаёт 404 USER_NOT_FOUND либо 401/400.
    if (code == 404 || code == 401 || code == 400) {
      return 'Неверный телефон или пароль.';
    }
    return apiErrorMessage(e, fallback: 'Ошибка входа. Попробуйте ещё раз.');
  }
}

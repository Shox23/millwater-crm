import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


import '../../../data/models/user_role.dart';
import '../../../data/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthState()) {
    on<AuthBootstrapRequested>(_onBootstrap);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthSessionExpired>(_onSessionExpired);
  }

  final AuthRepository _repository;

  Future<void> _onBootstrap(
    AuthBootstrapRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState(status: AuthStatus.restoring));
    // Репозиторий уже гасит любые ошибки восстановления в null:
    // непонятная сессия — значит, показываем вход.
    final role = await _repository.restoreSession();
    emit(role == null
        ? const AuthState(status: AuthStatus.unauthenticated)
        : AuthState(status: AuthStatus.authenticated, role: role));
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.authenticating, clearError: true));
    try {
      final role =
          await _repository.login(phone: event.phone, password: event.password);
      emit(AuthState(status: AuthStatus.authenticated, role: role));
    } on DioException catch (e) {
      emit(AuthState(status: AuthStatus.failure, error: _errorFor(e)));
    } catch (_) {
      emit(const AuthState(
        status: AuthStatus.failure,
        error: AuthError.failed,
      ));
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void _onSessionExpired(AuthSessionExpired event, Emitter<AuthState> emit) {
    emit(const AuthState(
      status: AuthStatus.unauthenticated,
      error: AuthError.sessionExpired,
    ));
  }

  /// Текст подбирает экран входа: блок про язык интерфейса не знает.
  AuthError _errorFor(DioException e) {
    final code = e.response?.statusCode;
    // Неверные учётные данные: сервер отдаёт 404 USER_NOT_FOUND либо 401/400.
    if (code == 404 || code == 401 || code == 400) {
      return AuthError.credentials;
    }
    return AuthError.generic;
  }
}

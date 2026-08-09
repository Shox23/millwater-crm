part of 'auth_bloc.dart';

/// Что показать пользователю после неудачи. Текст — на стороне экрана.
enum AuthError {
  /// Неверный телефон или пароль.
  credentials,

  /// Прочая ошибка входа.
  generic,

  /// Запрос не дошёл или упал не по вине данных.
  failed,

  /// Refresh не удался — сессию пришлось сбросить.
  sessionExpired,
}

enum AuthStatus {
  /// Стартовое состояние: проверяем сохранённую сессию.
  restoring,
  unauthenticated,
  authenticating,
  authenticated,
  failure,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.restoring,
    this.role,
    this.error,
  });

  final AuthStatus status;

  /// Роль вошедшего пользователя. Определяет, какую оболочку показать.
  final UserRole? role;
  final AuthError? error;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && role != null;

  AuthState copyWith({
    AuthStatus? status,
    UserRole? role,
    AuthError? error,
    bool clearError = false,
    bool clearRole = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      role: clearRole ? null : (role ?? this.role),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, role, error];
}

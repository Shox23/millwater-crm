part of 'auth_bloc.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated, failure }

class AuthState extends Equatable {
  const AuthState({this.status = AuthStatus.unauthenticated, this.error});

  final AuthStatus status;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, error];
}

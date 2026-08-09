import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/l10n.dart';
import '../data/models/user_role.dart';
import '../data/network/dio_client.dart';
import '../data/network/session_storage.dart';
import '../data/repositories/api_crm_repository.dart';
import '../data/repositories/api_driver_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/crm_repository.dart';
import '../data/repositories/driver_repository.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/driver/presentation/driver_shell.dart';
import '../features/home/presentation/admin_shell.dart';
import 'locale_cubit.dart';
import 'theme/app_theme.dart';
import 'theme/theme_cubit.dart';

class CrmApp extends StatefulWidget {
  const CrmApp({super.key, this.sessionStorage, this.dio});

  /// Подменяется в тестах: боевое хранилище ходит в платформенный канал.
  final SessionStorage? sessionStorage;

  /// Подменяется в тестах, чтобы проверить разводку по ролям без сети.
  final Dio? dio;

  @override
  State<CrmApp> createState() => _CrmAppState();
}

class _CrmAppState extends State<CrmApp> {
  late final AuthTokenStore _tokenStore;
  late final Dio _dio;
  late final AuthRepository _authRepository;

  @override
  void initState() {
    super.initState();
    _tokenStore = AuthTokenStore(widget.sessionStorage);
    _dio = widget.dio ?? buildDio(_tokenStore);
    _authRepository = AuthRepository(_dio, _tokenStore);
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: _authRepository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(create: (_) => LocaleCubit()),
          BlocProvider(
            create: (_) {
              final bloc = AuthBloc(_authRepository);
              // Истёкшая сессия (refresh не удался) → возврат на логин.
              _tokenStore.onSessionExpired =
                  () => bloc.add(const AuthSessionExpired());
              return bloc..add(const AuthBootstrapRequested());
            },
          ),
        ],
        // Репозиторий кладётся НАД MaterialApp: экраны, открытые через
        // Navigator.push, живут рядом с `home`, а не под ним, и провайдер
        // из поддерева `home` им не виден.
        child: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (a, b) => a.role != b.role || a.status != b.status,
          builder: (context, auth) => _RoleScopedRepositories(
            dio: _dio,
            role: auth.isAuthenticated ? auth.role : null,
            child: _buildApp(auth),
          ),
        ),
      ),
    );
  }

  Widget _buildApp(AuthState auth) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return BlocBuilder<LocaleCubit, Locale?>(
          builder: (context, locale) {
            return MaterialApp(
              // onGenerateTitle, а не title: контекст самого MaterialApp
              // лежит выше Localizations, и строк там ещё нет.
              onGenerateTitle: (context) => context.l10n.appTitle,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              // null — язык берётся из системы; всё, кроме узбекского,
              // приводится к русскому в localeResolutionCallback.
              locale: locale,
              supportedLocales: AppLocales.supported,
              // Делегаты нужны и системным диалогам (выбор даты в форме
              // маршрута), и строкам самого приложения.
              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,
              localeResolutionCallback: (system, _) =>
                  LocaleCubit.resolve(locale, system),
              home: _rootFor(auth),
            );
          },
        );
      },
    );
  }

  /// Что показывать при текущем состоянии сессии.
  Widget _rootFor(AuthState state) {
    if (state.status == AuthStatus.restoring) return const _RestoringPage();
    if (!state.isAuthenticated) return const LoginPage();

    return switch (state.role!) {
      UserRole.admin => const AdminShell(),
      UserRole.driver => const DriverShell(),
    };
  }
}

/// Кладёт в дерево репозиторий, соответствующий роли, — и только его.
///
/// У водителя `CrmRepository` физически отсутствует, поэтому «доступ по
/// ролям» не зависит от того, что кто-то вызовет не тот метод. До входа
/// не предоставляется ничего.
class _RoleScopedRepositories extends StatelessWidget {
  const _RoleScopedRepositories({
    required this.dio,
    required this.role,
    required this.child,
  });

  final Dio dio;
  final UserRole? role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (role) {
      null => child,
      UserRole.admin => RepositoryProvider<CrmRepository>(
          create: (_) => ApiCrmRepository(dio),
          child: child,
        ),
      UserRole.driver => RepositoryProvider<DriverRepository>(
          create: (_) => ApiDriverRepository(dio),
          child: child,
        ),
    };
  }
}

/// Пока поднимаем сохранённую сессию — экран входа мелькать не должен.
class _RestoringPage extends StatelessWidget {
  const _RestoringPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

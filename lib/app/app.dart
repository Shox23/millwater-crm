import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/network/dio_client.dart';
import '../data/repositories/api_crm_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/crm_repository.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/home/presentation/home_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_cubit.dart';

class CrmApp extends StatefulWidget {
  const CrmApp({super.key});

  @override
  State<CrmApp> createState() => _CrmAppState();
}

class _CrmAppState extends State<CrmApp> {
  late final AuthTokenStore _tokenStore;
  late final Dio _dio;
  late final AuthRepository _authRepository;
  late final CrmRepository _crmRepository;

  @override
  void initState() {
    super.initState();
    _tokenStore = AuthTokenStore();
    _dio = buildDio(_tokenStore);
    _authRepository = AuthRepository(_dio, _tokenStore);
    // Боевой API. Для демо без сервера можно подставить MockCrmRepository().
    _crmRepository = ApiCrmRepository(_dio);
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _authRepository),
        RepositoryProvider.value(value: _crmRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(
            create: (_) {
              final bloc = AuthBloc(_authRepository);
              // Истёкшая сессия (refresh не удался) → возврат на логин.
              _tokenStore.onSessionExpired =
                  () => bloc.add(const AuthSessionExpired());
              return bloc;
            },
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp(
              title: 'CRM Millwater',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              // Без делегатов системные диалоги (в т.ч. выбор даты
              // в форме маршрута) остаются на английском.
              locale: const Locale('ru'),
              supportedLocales: const [Locale('ru'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  return state.isAuthenticated
                      ? const HomeShell()
                      : const LoginPage();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

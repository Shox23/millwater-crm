import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/app/theme/theme_cubit.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/network/dio_client.dart';
import 'package:crm_millwater/data/repositories/auth_repository.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/auth/bloc/auth_bloc.dart';
import 'package:crm_millwater/features/customers/bloc/customers_bloc.dart';
import 'package:crm_millwater/features/customers/presentation/customers_page.dart';
import 'package:crm_millwater/features/settings/presentation/settings_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Считает обращения к списку и запоминает поисковые запросы.
class _CountingRepository extends MockCrmRepository {
  _CountingRepository({this.empty = false});

  final bool empty;
  final List<String?> searches = [];

  @override
  Future<List<Customer>> getCustomers({String? search, bool? hasDebt}) async {
    searches.add(search);
    if (empty) return [];
    return super.getCustomers(search: search, hasDebt: hasDebt);
  }
}

void main() {
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> pumpPage(
    WidgetTester tester,
    CrmRepository repo,
    Widget page,
  ) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      RepositoryProvider<CrmRepository>.value(
        value: repo,
        child: MaterialApp(theme: AppTheme.light(), home: page),
      ),
    );
    await settle(tester);
  }

  group('Поиск уходит на сервер', () {
    test('запрос передаётся в репозиторий', () async {
      final repo = _CountingRepository();
      final bloc = CustomersBloc(repo)..add(const CustomersRequested());
      await Future<void>.delayed(const Duration(milliseconds: 300));

      bloc.add(const CustomersSearchChanged('Nasiba'));
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(repo.searches, ['', 'Nasiba']);
      await bloc.close();
    });

    test('быстрый набор схлопывается в один запрос', () async {
      final repo = _CountingRepository();
      final bloc = CustomersBloc(repo)..add(const CustomersRequested());
      await Future<void>.delayed(const Duration(milliseconds: 300));

      for (final q in ['Н', 'На', 'Нас', 'Наси']) {
        bloc.add(CustomersSearchChanged(q));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Начальная загрузка + один запрос по последнему введённому тексту.
      expect(repo.searches, ['', 'Наси']);
      await bloc.close();
    });

    test('таймер debounce не переживает закрытие блока', () async {
      final repo = _CountingRepository();
      final bloc = CustomersBloc(repo);
      bloc.add(const CustomersSearchChanged('abc'));
      await bloc.close();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(repo.searches, isEmpty);
    });
  });

  group('Пустые состояния различаются', () {
    testWidgets('пустая база предлагает добавить первого', (tester) async {
      await pumpPage(tester, _CountingRepository(empty: true),
          const CustomersPage());

      expect(find.text('Заказчиков пока нет'), findsOneWidget);
      expect(find.text('Добавить заказчика'), findsOneWidget);
    });

    testWidgets('безрезультатный поиск предлагает сбросить', (tester) async {
      final repo = _CountingRepository(empty: true);
      await pumpPage(tester, repo, const CustomersPage());

      await tester.enterText(find.byType(TextField).first, 'зззз');
      await settle(tester);

      expect(find.text('По запросу «зззз» ничего нет'), findsOneWidget);
      expect(find.text('Сбросить поиск'), findsOneWidget);
      // Кнопка «добавить первого» здесь была бы не к месту.
      expect(find.text('Добавить заказчика'), findsNothing);
    });
  });

  group('Поле поиска', () {
    testWidgets('крестик появляется и очищает ввод', (tester) async {
      await pumpPage(tester, MockCrmRepository(), const CustomersPage());
      final field = find.byType(TextField).first;

      expect(find.byTooltip('Очистить'), findsNothing);

      await tester.enterText(field, 'Nasiba');
      await settle(tester);
      expect(find.byTooltip('Очистить'), findsOneWidget);

      await tester.tap(find.byTooltip('Очистить'));
      await settle(tester);

      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.byTooltip('Очистить'), findsNothing);
    });
  });

  group('Настройки', () {
    Widget settingsHost(AuthBloc auth) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: auth),
            BlocProvider(create: (_) => ThemeCubit()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SettingsPage(),
          ),
        );

    testWidgets('выход из аккаунта сбрасывает сессию', (tester) async {
      useLargeSurface(tester);
      final store = AuthTokenStore()
        ..setTokens(access: 'a', refresh: 'r');
      final auth = AuthBloc(AuthRepository(Dio(), store));
      addTearDown(auth.close);

      await tester.pumpWidget(settingsHost(auth));
      await settle(tester);

      await tester.tap(find.text('Выйти из аккаунта'));
      await settle(tester);
      expect(find.text('Выйти из аккаунта?'), findsOneWidget);

      await tester.tap(find.text('Выйти').last);
      await settle(tester);

      expect(auth.state.status, AuthStatus.unauthenticated);
      expect(store.isAuthenticated, isFalse);
    });

    testWidgets('тема переключается явным выбором', (tester) async {
      useLargeSurface(tester);
      final auth = AuthBloc(AuthRepository(Dio(), AuthTokenStore()));
      addTearDown(auth.close);

      await tester.pumpWidget(settingsHost(auth));
      await settle(tester);
      expect(find.text('Тема · Как в системе'), findsOneWidget);

      await tester.tap(find.text('Тёмная'));
      await settle(tester);

      expect(find.text('Тема · Тёмная'), findsOneWidget);
    });
  });
}

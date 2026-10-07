import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/settings/settings_storage.dart';
import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/app/theme/theme_cubit.dart';
import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/data/models/driver.dart';
import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/desktop/presentation/desktop_shell.dart';
import 'package:crm_millwater/features/desktop/presentation/pages/drivers_desktop_page.dart';
import 'package:crm_millwater/features/desktop/widgets/desktop_button.dart';
import 'package:crm_millwater/features/drivers/bloc/drivers_bloc.dart';
import 'package:crm_millwater/features/drivers/presentation/driver_detail_page.dart';
import 'package:crm_millwater/features/drivers/presentation/drivers_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Возврат удалённого водителя в работу.
///
/// Удаление водителя на сервере мягкое — снимает `is_active`, — и с
/// 2026-09-30 сервер умеет вернуть такую учётку:
/// `POST /admin/drivers/{id}/activate`, а список неактивных отдаёт
/// `GET /admin/drivers?is_active=false`. Признака активности в ответе нет:
/// приложение знает о нём по тому, из какого списка открыт водитель.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'POST') return ResponseBody.fromString('', 204);
    return ResponseBody.fromString(
      jsonEncode({
        'items': <Object>[],
        'total': 0,
        'page': 1,
        'page_size': 100,
        'pages': 1,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  Future<void> settle(WidgetTester tester, {int steps = 5}) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  group('Запросы', () {
    late _RecordingAdapter adapter;
    late ApiCrmRepository repo;

    setUp(() {
      adapter = _RecordingAdapter();
      repo = ApiCrmRepository(
        Dio(BaseOptions(baseUrl: 'https://crm.millwater.uz'))
          ..httpClientAdapter = adapter,
      );
    });

    test('неактивных спрашивают с is_active=false, активных — без него',
        () async {
      await repo.getDriversPage(active: false);
      await repo.getDriversPage();

      expect(adapter.requests.first.queryParameters['is_active'], isFalse);
      // Обычный список шлём как раньше: он не должен зависеть от новой ручки.
      expect(
        adapter.requests.last.queryParameters.containsKey('is_active'),
        isFalse,
      );
    });

    test('возврат — POST на /activate', () async {
      await repo.activateDriver('d-7');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/admin/drivers/d-7/activate');
    });
  });

  group('Демо-режим', () {
    test('удалённый водитель уходит в неактивные и возвращается', () async {
      final repo = MockCrmRepository();
      final driver = repo.store.drivers.first;

      await repo.deleteDriver(driver.id);
      expect(
        (await repo.getDriversPage()).items.map((d) => d.id),
        isNot(contains(driver.id)),
      );
      expect(
        (await repo.getDriversPage(active: false)).items.single.id,
        driver.id,
      );

      await repo.activateDriver(driver.id);
      // Полный список, а не первая страница: в моке страница — 4 водителя, и
      // вернувшийся встаёт пятым.
      expect((await repo.getDrivers()).map((d) => d.id), contains(driver.id));
      expect((await repo.getDriversPage(active: false)).items, isEmpty);
    });
  });

  group('Телефон', () {
    late MockCrmRepository repo;
    late Driver removed;

    setUp(() async {
      repo = MockCrmRepository();
      removed = repo.store.drivers.first;
      await repo.deleteDriver(removed.id);
    });

    Future<void> pump(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            home: page,
          ),
        ),
      );
      await tester.pump();
      await settle(tester);
    }

    testWidgets('во вкладке «Неактивные» удалённого водителя можно вернуть',
        (tester) async {
      await pump(tester, const DriversPage());
      expect(find.text(removed.fullName), findsNothing);

      await tester.tap(find.text('Неактивные'));
      await settle(tester);

      expect(find.text(removed.fullName), findsOneWidget);
      // У неактивного нет правки и удаления: сервер ответит 404 и 409.
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.restore_rounded));
      await settle(tester);

      expect(find.text('Водитель снова в работе'), findsOneWidget);
      expect(find.text('Неактивных водителей нет'), findsOneWidget);
      expect(repo.store.drivers.map((d) => d.id), contains(removed.id));

      // В работающих он снова есть — пятым, то есть за первой страницей
      // мока (4 водителя): проверяем по счётчику в шапке, а не по строке.
      await tester.tap(find.text('Активные'));
      await settle(tester);
      expect(
        tester.element(find.byType(ListView)).read<DriversBloc>().state.total,
        5,
      );

      // Снэкбар живёт несколько секунд — догоняем его таймер.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('экран неактивного водителя: вместо правки — возврат',
        (tester) async {
      await pump(tester, DriverDetailPage(driver: removed, inactive: true));

      expect(find.text('Неактивен'), findsOneWidget);
      expect(find.text('Редактировать'), findsNothing);

      await tester.tap(find.text('Вернуть в работу'));
      await settle(tester);

      expect(repo.store.drivers.map((d) => d.id), contains(removed.id));
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('Десктоп', () {
    late MockCrmRepository repo;
    late Driver removed;

    setUp(() async {
      repo = MockCrmRepository();
      removed = repo.store.drivers.first;
      await repo.deleteDriver(removed.id);
    });

    Future<void> pumpShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1728, 1117);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CrmRepository>.value(value: repo),
            RepositoryProvider<CapsulePrice>.value(
              value: const BuildCapsulePrice(),
            ),
          ],
          child: BlocProvider(
            create: (_) => ThemeCubit(storage: InMemorySettingsStorage()),
            child: MaterialApp(
              theme: AppTheme.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocales.supported,
              locale: AppLocales.ru,
              home: const DesktopShell(),
            ),
          ),
        ),
      );
      await settle(tester, steps: 8);
    }

    testWidgets('вкладка неактивных не трогает общий список, возврат работает',
        (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('Водители'));
      await settle(tester);

      await tester.tap(find.text('Неактивные'));
      await settle(tester);

      expect(find.text(removed.fullName), findsOneWidget);
      // Общий список — его читают сайдбар и касса — остался с работающими:
      // уволенный не должен попасть ни в «на линии», ни в фильтр кассы.
      final shared = tester
          .element(find.byType(DriversDesktopPage))
          .read<DriversBloc>()
          .state
          .drivers;
      expect(shared, isNotEmpty);
      expect(shared.map((d) => d.id), isNot(contains(removed.id)));

      await tester.tap(find.widgetWithText(DesktopButton, 'Вернуть в работу'));
      await settle(tester);
      // Тост живёт несколько секунд — догоняем его таймер.
      await tester.pump(const Duration(seconds: 3));

      expect(repo.store.drivers.map((d) => d.id), contains(removed.id));
      expect(find.text('Неактивных водителей нет'), findsOneWidget);
      // Общий список перечитан: водителей снова пятеро (вернувшийся — за
      // первой страницей мока, поэтому смотрим счётчик, а не строки).
      expect(
        tester
            .element(find.byType(DriversDesktopPage))
            .read<DriversBloc>()
            .state
            .total,
        5,
      );
    });
  });
}

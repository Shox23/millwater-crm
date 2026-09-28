import 'dart:typed_data';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/mock/mock_store.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:crm_millwater/data/repositories/api_driver_repository.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/presentation/my_route_detail_page.dart';
import 'package:crm_millwater/features/routes/presentation/route_detail_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Завершение маршрута — `POST /driver/routes/{id}/complete` (сервер с
/// 2026-09-19).
///
/// Сервер больше не закрывает маршрут по последней доставке: только явной
/// командой, и незакрытые точки при этом отменяются. Здесь закреплено, что
/// уходит на сервер, как это повторяет мок и что видят админ и водитель.
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
    return ResponseBody.fromString('', 204);
  }
}

/// Админский мок, у которого завершение отвечает 409: маршрут уже закрыли
/// с другого устройства.
class _ConflictRepository extends MockCrmRepository {
  @override
  Future<void> completeRoute(String id, {String? idempotencyKey}) async {
    final options = RequestOptions(path: '/driver/routes/$id/complete');
    throw DioException(
      requestOptions: options,
      response: Response(
        requestOptions: options,
        statusCode: 409,
        data: {
          'error': {'code': 'ORDER_ALREADY_COMPLETED', 'message': 'x'}
        },
      ),
    );
  }
}

void main() {
  group('Модель', () {
    test('awaitsCompletion — все точки закрыты у маршрута в работе', () {
      final store = MockStore();
      final repo = MockCrmRepository(store: store);
      final open = store.routes.firstWhere((r) => r.id == 'r1');
      expect(open.awaitsCompletion, isFalse);

      for (final stop in open.stops.where((s) => s.status.isOpen)) {
        repo.store.cancelStop(stop.id);
      }
      final closed = store.routes.firstWhere((r) => r.id == 'r1');
      expect(closed.status, RouteStatus.inProgress);
      expect(closed.awaitsCompletion, isTrue);

      // Завершённый и пустой — нет: закрывать нечего.
      store.completeRoute('r1');
      expect(store.routes.firstWhere((r) => r.id == 'r1').awaitsCompletion,
          isFalse);
      expect(
        store.copyRoute(closed, stops: const []).awaitsCompletion,
        isFalse,
      );
    });
  });

  group('Запрос', () {
    late _RecordingAdapter adapter;

    Dio dio() {
      adapter = _RecordingAdapter();
      return Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
    }

    test('админ бьёт в водительскую ручку с ключом идемпотентности', () async {
      await ApiCrmRepository(dio()).completeRoute('r-1', idempotencyKey: 'k1');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/driver/routes/r-1/complete');
      expect(request.headers['Idempotency-Key'], 'k1');
    });

    test('водитель — та же ручка; без ключа заголовка нет', () async {
      await ApiDriverRepository(dio()).completeRoute('r-1');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/driver/routes/r-1/complete');
      expect(request.headers.containsKey('Idempotency-Key'), isFalse);
    });
  });

  group('Мок', () {
    test('открытые точки отменяются с серверной причиной, маршрут закрыт',
        () async {
      final store = MockStore();
      await MockCrmRepository(store: store).completeRoute('r1');

      final route = store.routes.firstWhere((r) => r.id == 'r1');
      expect(route.status, RouteStatus.completed);
      // Доставленная точка нетронута, обе открытые — отменены.
      expect(route.stops.map((s) => s.status), [
        DeliveryStatus.delivered,
        DeliveryStatus.cancelled,
        DeliveryStatus.cancelled,
      ]);
      for (final stop in route.stops.where((s) => s.isCancelled)) {
        expect(stop.cancelReason, MockStore.routeCompletionCancelReason);
        expect(stop.cancelledAt, isNotNull);
      }
      // Счётчик выполненных отменой не растёт.
      expect(route.completedCount, 1);
    });

    test('повторно и не in_progress — 409, как на сервере', () async {
      final repo = MockCrmRepository();
      await repo.completeRoute('r1');

      expect(repo.completeRoute('r1'), throwsA(isA<StateError>()));
      // r4 в сиде — `created`: завершать нечего.
      expect(repo.completeRoute('r4'), throwsA(isA<StateError>()));
    });

    test('водитель закрывает свой маршрут, чужой — нет', () async {
      final store = MockStore();
      final own = MockDriverRepository(store: store, driverId: 'd1');
      final other = MockDriverRepository(store: store, driverId: 'd2');

      expect(other.completeRoute('r1'), throwsA(isA<StateError>()));
      await own.completeRoute('r1');
      expect(
        store.routes.firstWhere((r) => r.id == 'r1').status,
        RouteStatus.completed,
      );
    });

    test('закрытие последней точки маршрут не завершает', () async {
      final store = MockStore();
      final repo = MockCrmRepository(store: store);
      final route = store.routes.firstWhere((r) => r.id == 'r1');

      for (final stop in route.stops.where((s) => s.status.isOpen)) {
        await repo.cancelOrder(orderId: stop.id);
      }

      // Сервер держит `in_progress`, пока маршрут не завершат явно.
      expect(
        store.routes.firstWhere((r) => r.id == 'r1').status,
        RouteStatus.inProgress,
      );
    });
  });

  group('Экран админа', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
    }

    Future<void> pumpDetail(
      WidgetTester tester,
      CrmRepository repo,
      String routeId,
    ) async {
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
            // Ключ — иначе второй pump того же экрана переиспользует State,
            // а маршрут грузится в initState.
            home: RouteDetailPage(key: ValueKey(routeId), routeId: routeId),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('«Завершить» только у начатого маршрута', (tester) async {
      final repo = MockCrmRepository();

      await pumpDetail(tester, repo, 'r1');
      expect(find.widgetWithText(AppButton, 'Завершить'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Отменить'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Редактировать'), findsOneWidget);

      // `created` — завершать нечего, сервер ответил бы 409.
      await pumpDetail(tester, repo, 'r4');
      expect(find.widgetWithText(AppButton, 'Завершить'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Отменить'), findsOneWidget);
    });

    testWidgets('диалог называет число незакрытых точек и закрывает маршрут',
        (tester) async {
      final repo = MockCrmRepository();
      await pumpDetail(tester, repo, 'r1');

      await tester.tap(find.widgetWithText(AppButton, 'Завершить'));
      await settle(tester);

      expect(find.text('Завершить маршрут?'), findsOneWidget);
      expect(find.textContaining('2 незакрытые точки будут отменены'),
          findsOneWidget);

      await tester.tap(find.text('Завершить маршрут'));
      await settle(tester);

      expect(
        repo.store.routes.firstWhere((r) => r.id == 'r1').status,
        RouteStatus.completed,
      );
      // Панель действий у завершённого исчезает целиком.
      expect(find.byType(AppButton), findsNothing);
      expect(find.text('Маршрут завершён'), findsOneWidget);
    });
  });

  group('Экран админа: подсказка и 409', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
    }

    Future<void> pumpDetail(
      WidgetTester tester,
      CrmRepository repo,
      String routeId,
    ) async {
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
            home: RouteDetailPage(key: ValueKey(routeId), routeId: routeId),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('когда все точки закрыты, просит завершить маршрут',
        (tester) async {
      final repo = MockCrmRepository();
      final route = repo.store.routes.firstWhere((r) => r.id == 'r1');
      for (final stop in route.stops.where((s) => s.status.isOpen)) {
        repo.store.cancelStop(stop.id);
      }

      await pumpDetail(tester, repo, 'r1');
      expect(find.text('Все точки закрыты — завершите маршрут'), findsOneWidget);
    });

    testWidgets('с открытой точкой подсказки нет', (tester) async {
      await pumpDetail(tester, MockCrmRepository(), 'r1');
      expect(find.text('Все точки закрыты — завершите маршрут'), findsNothing);
    });

    testWidgets('409 читается как «маршрут уже завершён», а не «заказ»',
        (tester) async {
      await pumpDetail(tester, _ConflictRepository(), 'r1');

      await tester.tap(find.widgetWithText(AppButton, 'Завершить'));
      await settle(tester);
      await tester.tap(find.text('Завершить маршрут'));
      await settle(tester);

      expect(find.text('Маршрут уже завершён'), findsOneWidget);
      expect(find.text('Заказ уже закрыт'), findsNothing);
    });
  });

  group('Экран водителя', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
    }

    Future<void> pumpDetail(
      WidgetTester tester,
      DriverRepository repo,
      String routeId,
    ) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<DriverRepository>.value(value: repo),
            RepositoryProvider<CapsulePrice>.value(
              value: const BuildCapsulePrice(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            home: MyRouteDetailPage(routeId: routeId),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('кнопка есть у начатого, после завершения пропадает',
        (tester) async {
      final store = MockStore();
      final repo = MockDriverRepository(store: store, driverId: 'd1');
      await pumpDetail(tester, repo, 'r1');

      final button = find.widgetWithText(AppButton, 'Завершить маршрут');
      expect(button, findsOneWidget);

      await tester.tap(button);
      await settle(tester);
      // Кнопка диалога называется так же — берём ту, что в диалоге.
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Завершить маршрут'),
      ));
      await settle(tester);

      expect(
        store.routes.firstWhere((r) => r.id == 'r1').status,
        RouteStatus.completed,
      );
      expect(find.widgetWithText(AppButton, 'Завершить маршрут'), findsNothing);
      expect(find.text('Завершён'), findsOneWidget);
    });
  });
}

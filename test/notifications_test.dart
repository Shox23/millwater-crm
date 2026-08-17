import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/mock/mock_store.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/notification_event.dart';
import 'package:crm_millwater/data/models/reports_summary.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/network/sse_client.dart';
import 'package:crm_millwater/data/repositories/api_notifications_repository.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_notifications_repository.dart';
import 'package:crm_millwater/data/repositories/notifications_repository.dart';
import 'package:crm_millwater/features/driver/presentation/my_route_detail_page.dart';
import 'package:crm_millwater/features/reports/bloc/reports_bloc.dart';
import 'package:crm_millwater/features/routes/bloc/routes_bloc.dart';
import 'package:crm_millwater/features/routes/presentation/route_detail_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Кадр боевого сервера — из тех, что снимались с `/admin/notifications/stream`.
const _liveFrame = 'id: 7\n'
    'event: delivery_status_updated\n'
    'data: {"id":7,"type":"delivery_status_updated",'
    '"payload":{"route_id":"r-1","route_customer_id":"s-1",'
    '"driver_id":"d-1","customer_name":"Влад","status":"on_way"},'
    '"created_at":"2026-08-15T09:51:56.250097Z"}\n'
    '\n';

/// Сервер, отдающий один поток: тест шлёт в него кадры руками.
class _OneShotAdapter implements HttpClientAdapter {
  final chunks = StreamController<Uint8List>();

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    unawaited(cancelFuture?.then((_) {
      if (!chunks.isClosed) chunks.close();
    }));
    return ResponseBody(
      chunks.stream,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  void send(String raw) => chunks.add(Uint8List.fromList(utf8.encode(raw)));
}

void main() {
  // `SseClient` подписывается на жизненный цикл настоящим
  // `AppLifecycleListener`, а тому нужен поднятый биндинг.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Разбор события', () {
    test('боевой кадр разбирается до полей маршрута', () async {
      final frame = (await parseSseFrames(
        Stream.fromIterable(const LineSplitter().convert(_liveFrame)),
      ).toList())
          .single;

      final event = NotificationEvent.tryFromFrame(frame)!;

      expect(event.id, '7');
      expect(event.type, 'delivery_status_updated');
      expect(event.routeId, 'r-1');
      expect(event.stopId, 's-1');
      expect(event.driverId, 'd-1');
      expect(event.createdAt?.isUtc, isTrue);
    });

    test('тип берётся из рамки, если в теле его не оказалось', () {
      final event = NotificationEvent.tryFromFrame(const SseFrame(
        event: 'route_customer_added',
        data: '{"payload":{"route_id":"r-9"}}',
      ))!;

      expect(event.type, 'route_customer_added');
      expect(event.routeId, 'r-9');
      // Кадр без `id:` — обычное дело, событие от этого не пропадает.
      expect(event.id, isNull);
    });

    test('незнакомый тип события не отбрасывается', () {
      // Сервер вправе завести новый тип; для приложения это всё равно повод
      // перечитать маршрут, а не причина замолчать.
      final event = NotificationEvent.tryFromFrame(const SseFrame(
        data: '{"type":"route_reassigned","payload":{"route_id":"r-2"}}',
      ))!;

      expect(event.type, 'route_reassigned');
      expect(event.routeId, 'r-2');
    });

    test('мусор вместо JSON не роняет разбор', () {
      expect(
        NotificationEvent.tryFromFrame(
          const SseFrame(data: '<html>502 Bad Gateway</html>'),
        ),
        isNull,
      );
      expect(
        NotificationEvent.tryFromFrame(const SseFrame(data: '[1,2,3]')),
        isNull,
      );
      // Тело без типа событием не считается: реагировать не на что.
      expect(
        NotificationEvent.tryFromFrame(const SseFrame(data: '{"payload":{}}')),
        isNull,
      );
    });
  });

  group('ApiNotificationsRepository', () {
    test('кадры потока доходят до подписчика событиями', () async {
      final adapter = _OneShotAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final repo = ApiNotificationsRepository(
        dio,
        path: ApiNotificationsRepository.adminPath,
      );
      addTearDown(repo.dispose);

      final received = <NotificationEvent>[];
      final sub = repo.events.listen(received.add);
      addTearDown(sub.cancel);

      // Даём подключению открыться, потом шлём ping и кадр.
      await pumpEventQueue();
      adapter.send(': ping\n\n');
      adapter.send(_liveFrame);
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single.routeId, 'r-1');
    });

    test('оба потока разведены по ролям', () {
      expect(
        ApiNotificationsRepository.adminPath,
        '/admin/notifications/stream',
      );
      expect(
        ApiNotificationsRepository.driverPath,
        '/driver/notifications/stream',
      );
    });
  });

  group('MockNotificationsRepository', () {
    test('событие доходит до всех подписчиков', () async {
      final repo = MockNotificationsRepository();
      addTearDown(repo.dispose);

      final first = <String?>[];
      final second = <String?>[];
      final s1 = repo.events.listen((e) => first.add(e.routeId));
      final s2 = repo.events.listen((e) => second.add(e.routeId));
      addTearDown(s1.cancel);
      addTearDown(s2.cancel);

      repo.emitRouteEvent('r-1');
      await pumpEventQueue();

      expect(first, ['r-1']);
      expect(second, ['r-1']);
    });
  });

  group('Реакция блоков на событие', () {
    late _CountingRepository repo;
    late MockNotificationsRepository notifications;

    setUp(() {
      repo = _CountingRepository();
      notifications = MockNotificationsRepository();
    });
    tearDown(() => notifications.dispose());

    test('список маршрутов перечитывается сам', () async {
      final bloc = RoutesBloc(repo, notifications: notifications.events)
        ..add(const RoutesRequested());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.status == RoutesStatus.ready);
      expect(repo.routeListCalls, 1);

      // Водитель закрыл доставку — админ видит это без жеста обновления.
      notifications.emitRouteEvent('r-1');
      await bloc.stream.firstWhere((s) => s.status == RoutesStatus.ready);

      expect(repo.routeListCalls, 2);
    });

    test('сводка отчётов перечитывается сама', () async {
      final bloc = ReportsBloc(repo, notifications: notifications.events)
        ..add(const ReportsRequested());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.status == ReportsStatus.ready);
      final before = repo.summaryCalls;

      notifications.emitRouteEvent('r-1');
      await bloc.stream.firstWhere((s) => s.status == ReportsStatus.ready);

      expect(repo.summaryCalls, before + 1);
    });

    test('закрытый блок от потока отписывается', () async {
      final bloc = RoutesBloc(repo, notifications: notifications.events)
        ..add(const RoutesRequested());
      await bloc.stream.firstWhere((s) => s.status == RoutesStatus.ready);
      await bloc.close();

      // Экран ушёл, а поток жив: событие в закрытый блок — это исключение
      // «Cannot add new events after calling close», а не тихий холостой ход.
      notifications.emitRouteEvent('r-1');
      await pumpEventQueue();

      expect(repo.routeListCalls, 1);
    });

    test('без потока блок работает как раньше', () async {
      final bloc = RoutesBloc(repo)..add(const RoutesRequested());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.status == RoutesStatus.ready);

      notifications.emitRouteEvent('r-1');
      await pumpEventQueue();

      expect(repo.routeListCalls, 1);
    });
  });

  group('Реакция карточки маршрута', () {
    /// [providers] оборачивает готовое приложение — так тест сам решает,
    /// лежит ли в дереве поток уведомлений.
    Future<void> pumpDetail(
      WidgetTester tester, {
      required Widget page,
      required Widget Function(Widget child) providers,
    }) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        providers(MaterialApp(
          // Без темы приложения нет ThemeExtension с токенами, и первый же
          // context.tokens валит сборку экрана.
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          home: page,
        )),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('админская карточка перечитывает свой маршрут',
        (tester) async {
      final repo = _CountingRepository();
      final notifications = MockNotificationsRepository();
      addTearDown(notifications.dispose);
      // Фикстуру берём из стора синхронно: `await` по моку внутри
      // testWidgets упёрся бы в таймер на фейковых часах.
      final routeId = repo.store.routes.first.id;

      await pumpDetail(
        tester,
        page: RouteDetailPage(routeId: routeId),
        providers: (child) => RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: RepositoryProvider<NotificationsRepository>.value(
            value: notifications,
            child: child,
          ),
        ),
      );
      expect(repo.routeCalls, 1);

      notifications.emitRouteEvent(routeId);
      await tester.pump();
      // Запрос ещё в пути (мок отвечает через 150 мс), а карточка на месте:
      // фоновое обновление не подменяет её спиннером.
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(repo.routeCalls, 2);

      // Чужой маршрут этот экран не касается.
      notifications.emitRouteEvent('другой-маршрут');
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(repo.routeCalls, 2);
    });

    testWidgets('водительская карточка видит досыпанную точку',
        (tester) async {
      final store = MockStore();
      final repo = _CountingDriverRepository(store: store);
      final notifications = MockNotificationsRepository();
      addTearDown(notifications.dispose);
      final route = store.routes.firstWhere((r) => r.driverId == 'd1');

      await pumpDetail(
        tester,
        page: MyRouteDetailPage(routeId: route.id),
        providers: (child) => RepositoryProvider<DriverRepository>.value(
          value: repo,
          child: RepositoryProvider<NotificationsRepository>.value(
            value: notifications,
            child: child,
          ),
        ),
      );
      expect(repo.routeCalls, 1);

      // Админ досыпал заказчика в маршрут, пока водитель в пути.
      store.replaceRoute(
        route.id,
        (r) => store.copyRoute(r, stops: [...r.stops, _extraStop]),
      );
      notifications.emitRouteEvent(route.id, type: 'route_customer_added');
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(repo.routeCalls, 2);
      expect(find.text('Новый заказчик'), findsOneWidget);
    });

    testWidgets('без потока карточка ведёт себя как прежде', (tester) async {
      final repo = _CountingRepository();
      final routeId = repo.store.routes.first.id;

      await pumpDetail(
        tester,
        page: RouteDetailPage(routeId: routeId),
        providers: (child) =>
            RepositoryProvider<CrmRepository>.value(value: repo, child: child),
      );

      expect(repo.routeCalls, 1);
      expect(find.byType(RouteDetailPage), findsOneWidget);
    });
  });
}

/// Точка, которой в маршруте раньше не было.
final _extraStop = RouteStop(
  id: 'stop-new',
  customerId: 'c-new',
  customerName: 'Новый заказчик',
  customerAddress: 'ул. Досыпанная, 1',
  customerPhone: '+998901112233',
  status: DeliveryStatus.pending,
);

/// Считает, сколько раз экран сходил в сеть.
class _CountingRepository extends MockCrmRepository {
  int routeListCalls = 0;
  int summaryCalls = 0;
  int routeCalls = 0;

  @override
  Future<List<RouteListItem>> getRoutes({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? driverId,
    RouteStatus? status,
  }) {
    routeListCalls++;
    return super.getRoutes(
      dateFrom: dateFrom,
      dateTo: dateTo,
      driverId: driverId,
      status: status,
    );
  }

  @override
  Future<SummaryReport> getSummaryReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    summaryCalls++;
    return super.getSummaryReport(dateFrom: dateFrom, dateTo: dateTo);
  }

  @override
  Future<RouteDetail?> getRoute(String id) {
    routeCalls++;
    return super.getRoute(id);
  }
}

/// То же для водительской части.
class _CountingDriverRepository extends MockDriverRepository {
  _CountingDriverRepository({super.store});

  int routeCalls = 0;

  @override
  Future<RouteDetail?> getMyRoute(String id) {
    routeCalls++;
    return super.getMyRoute(id);
  }
}

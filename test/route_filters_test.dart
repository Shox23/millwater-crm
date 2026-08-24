import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/features/desktop/bloc/day_deliveries_bloc.dart';
import 'package:crm_millwater/features/routes/bloc/routes_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Два фильтра, которых не было: отменённые маршруты у админа на телефоне и
/// недоставленные точки в десктопной таблице. Сервер отдавал и то и другое
/// вместе с остальным, а выделить их на экране было нечем.
void main() {
  final day = DateTime(2026, 8, 24);

  RouteListItem route(String id, RouteStatus status) => RouteListItem(
        id: id,
        date: day,
        status: status,
        completedCount: 0,
        totalCustomers: 3,
      );

  final routes = [
    route('r-created', RouteStatus.created),
    route('r-progress', RouteStatus.inProgress),
    route('r-done', RouteStatus.completed),
    route('r-cancelled', RouteStatus.cancelled),
  ];

  RoutesState stateWith(RouteFilter filter) =>
      RoutesState(date: day, routes: routes, filter: filter);

  group('Маршруты: отменённые', () {
    test('чип спрашивает именно отменённые', () {
      expect(RouteFilter.cancelled.status, RouteStatus.cancelled);
    });

    test('оставляет на экране только отменённые', () {
      expect(
        stateWith(RouteFilter.cancelled).visible.map((r) => r.id),
        ['r-cancelled'],
      );
    });

    test('под «Все» отменённый остаётся на месте', () {
      expect(stateWith(RouteFilter.all).visible.length, routes.length);
    });

    test('соседние фильтры отменённый не подбирают', () {
      for (final filter in [
        RouteFilter.created,
        RouteFilter.inProgress,
        RouteFilter.completed,
      ]) {
        expect(
          stateWith(filter).visible.map((r) => r.id),
          isNot(contains('r-cancelled')),
          reason: 'фильтр ${filter.name} захватил отменённый маршрут',
        );
      }
    });
  });

  group('Доставки: недоставленные', () {
    test('чип спрашивает именно неудавшиеся', () {
      expect(DeliveryFilter.failed.status, DeliveryStatus.failed);
    });

    test('каждому статусу доставки нашёлся свой чип', () {
      final covered =
          DeliveryFilter.values.map((f) => f.status).nonNulls.toSet();

      // Точка, чей статус не отбирается ничем, кроме «Все», теряется в
      // таблице дня — а недоставленные разбирают в первую очередь.
      expect(covered, DeliveryStatus.values.toSet());
    });
  });
}

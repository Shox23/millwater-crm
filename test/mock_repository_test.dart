import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockCrmRepository', () {
    late MockCrmRepository repo;

    setUp(() => repo = MockCrmRepository());

    test('сид: 5 водителей, 6 заказчиков, 5 маршрутов', () async {
      expect((await repo.getDrivers()).length, 5);
      expect((await repo.getCustomers()).length, 6);
      expect((await repo.getRoutes()).length, 5);
    });

    test('маршруты: 10 остановок, 5 завершено, собрано 280 000', () async {
      final routes = await repo.getRoutes();
      final stops = routes.fold<int>(0, (s, r) => s + r.totalCustomers);
      final done = routes.fold<int>(0, (s, r) => s + r.completedCount);
      expect(stops, 10);
      expect(done, 5);

      final summary = await repo.getReportsSummary();
      expect(summary.revenueToday, 280000);
      expect(summary.deliveriesDone, 5);
      expect(summary.deliveriesTotal, 10);
    });

    test('отчёт: долги 420 000 у 2 клиентов, капсул 26', () async {
      final s = await repo.getReportsSummary();
      expect(s.debtTotal, 420000);
      expect(s.debtorsCount, 2);
      expect(s.capsulesActive, 26);
    });

    test('поиск водителя по имени', () async {
      final found = await repo.getDrivers(search: 'Азиз');
      expect(found.length, 1);
      expect(found.first.fullName, 'Азиз Каримов');
    });

    test('фильтр заказчиков по долгу', () async {
      final debtors = await repo.getCustomers(hasDebt: true);
      expect(debtors.length, 2);
      expect(debtors.every((c) => c.debt > 0), isTrue);
    });

    test('добавление и удаление водителя', () async {
      final created = await repo.addDriver(
        fullName: 'Тест Тестов',
        phone: '+998 90 000 00 00',
        email: 'test@aqua.uz',
        password: 'secret123',
      );
      expect((await repo.getDrivers()).length, 6);
      await repo.deleteDriver(created.id);
      expect((await repo.getDrivers()).length, 5);
    });

    test('создание маршрута и завершение доставки', () async {
      final route = await repo.createRoute(
        driverId: 'd1',
        date: DateTime(2026, 7, 6),
        customerIds: ['c1', 'c2'],
      );
      expect(route.stops.length, 2);
      expect(route.status, RouteStatus.created);

      await repo.completeDelivery(
        stopId: route.stops.first.id,
        capsules: 4,
        amount: 80000,
      );

      final updated = await repo.getRoute(route.id);
      expect(updated!.completedCount, 1);
      expect(updated.status, RouteStatus.inProgress);
      expect(updated.collected, 80000);
    });
  });
}

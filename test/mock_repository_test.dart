import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/reports_summary.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/data/models/route_models.dart';
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

      // Общий отчёт — строка на состоявшуюся доставку; выручка складывается
      // из строк, незавершённых точек в нём нет вовсе.
      final rows = await repo.getGeneralReport(
        dateFrom: DateTime(2020), dateTo: DateTime(2030));
      expect(rows.fold<int>(0, (sum, r) => sum + r.orderAmount), 280000);
      expect(rows, hasLength(5));
    });

    test('отчёт: долги 420 000 у 2 клиентов, капсул 26', () async {
      // Долг и капсулы — показатели «на сейчас» по всей базе; ни один отчёт
      // их не отдаёт, поэтому справочник заказчиков по-прежнему нужен.
      final s = ReportsSummary.from(
        await repo.getGeneralReport(
            dateFrom: DateTime(2020), dateTo: DateTime(2030)),
        await repo.getCustomers(),
      );
      expect(s.debtTotal, 420000);
      expect(s.debtorsCount, 2);
      expect(s.capsulesActive, 26);
    });

    test('должники в отчёте идут по убыванию суммы', () async {
      final s = ReportsSummary.from(
        await repo.getGeneralReport(
            dateFrom: DateTime(2020), dateTo: DateTime(2030)),
        await repo.getCustomers(),
      );
      final amounts = s.debtors.map((d) => d.amount).toList();
      final descending = [...amounts]..sort((a, b) => b.compareTo(a));
      expect(amounts, descending);
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
        orders: const [
          RouteOrderInput(customerId: 'c1'),
          RouteOrderInput(customerId: 'c2'),
        ],
      );
      expect(route.stops.length, 2);
      expect(route.status, RouteStatus.created);

      // Завершение — водительская операция: она живёт в DriverRepository
      // и работает по тому же MockStore.
      await MockDriverRepository(store: repo.store).completeDelivery(
        stopId: route.stops.first.id,
        purpose: OrderPurpose.delivery19l,
        capsules: 4,
        amount: 80000,
        bottleBalance: 4,
        method: PaymentMethod.cash,
      );

      final updated = await repo.getRoute(route.id);
      expect(updated!.completedCount, 1);
      expect(updated.status, RouteStatus.inProgress);
      expect(updated.collected, 80000);
    });
  });
}

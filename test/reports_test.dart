import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/reports_summary.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/reports/bloc/reports_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Customer _customer({required String id, int debt = 0, int capsules = 0}) =>
    Customer(
      id: id,
      name: 'Заказчик $id',
      phone: '+99890111223$id',
      address: 'ул. Тестовая, $id',
      capsuleBalance: capsules,
      debt: debt,
      createdAt: DateTime(2026, 1, 1),
    );

/// Отвечает с задержкой, заданной для каждого вызова по очереди: так
/// воспроизводится обгон ответов при быстром переключении периода.
class _SlowFirstRepository extends MockCrmRepository {
  _SlowFirstRepository(this._delays);

  final List<Duration> _delays;
  int _call = 0;
  final List<ReportPeriodRange> ranges = [];

  @override
  Future<SummaryReport> getSummaryReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final delay = _delays[_call.clamp(0, _delays.length - 1)];
    _call++;
    ranges.add((from: dateFrom, to: dateTo));
    await Future<void>.delayed(delay);
    // Выручка кодирует номер вызова — по ней видно, чей ответ дошёл.
    return SummaryReport(
      routesCount: 0,
      completedDeliveries: 0,
      failedDeliveries: 0,
      totalRevenue: _call,
      totalDebt: 0,
    );
  }
}

typedef ReportPeriodRange = ({DateTime? from, DateTime? to});

void main() {
  group('Сводка по должникам', () {
    test('итог равен сумме строк списка', () {
      const report = SummaryReport(
        routesCount: 1,
        completedDeliveries: 1,
        failedDeliveries: 0,
        totalRevenue: 100000,
        // Сервер прислал своё число — на экране оно не должно разойтись
        // со списком, который тут же показан.
        totalDebt: 999999,
      );
      final customers = [
        _customer(id: '1', debt: 120000),
        _customer(id: '2', debt: 300000),
        _customer(id: '3'),
      ];

      final summary = ReportsSummary.from(report, customers);

      expect(summary.debtorsCount, 2);
      expect(summary.debtTotal, 420000);
      expect(
        summary.debtTotal,
        summary.debtors.fold<int>(0, (sum, d) => sum + d.amount),
      );
    });

    test('должники идут по убыванию суммы', () {
      const report = SummaryReport(
        routesCount: 0,
        completedDeliveries: 0,
        failedDeliveries: 0,
        totalRevenue: 0,
        totalDebt: 0,
      );
      final summary = ReportsSummary.from(report, [
        _customer(id: '1', debt: 100),
        _customer(id: '2', debt: 900),
        _customer(id: '3', debt: 500),
      ]);

      expect(summary.debtors.map((d) => d.amount), [900, 500, 100]);
    });

    test('остаток капсул считается по всем заказчикам, не только должникам',
        () {
      const report = SummaryReport(
        routesCount: 0,
        completedDeliveries: 0,
        failedDeliveries: 0,
        totalRevenue: 0,
        totalDebt: 0,
      );
      final summary = ReportsSummary.from(report, [
        _customer(id: '1', debt: 100, capsules: 5),
        _customer(id: '2', capsules: 3),
      ]);

      expect(summary.capsulesActive, 8);
    });
  });

  group('Смена периода', () {
    test('чистит прежние числа — они не висят под новой подписью', () async {
      final bloc = ReportsBloc(MockCrmRepository())
        ..add(const ReportsRequested());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.status == ReportsStatus.ready);
      expect(bloc.state.summary, isNotNull);

      bloc.add(const ReportsPeriodChanged(ReportPeriod.month));
      // Первое же состояние после смены: период новый, чисел ещё нет.
      final next = await bloc.stream.first;

      expect(next.period, ReportPeriod.month);
      expect(next.summary, isNull);
      expect(next.status, ReportsStatus.loading);
    });

    test('период доезжает до запроса', () async {
      final repo = _SlowFirstRepository([Duration.zero]);
      final bloc = ReportsBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const ReportsPeriodChanged(ReportPeriod.month));
      await bloc.stream.firstWhere((s) => s.status == ReportsStatus.ready);

      // У месяца начало — первое число, а не сегодня.
      expect(repo.ranges.last.from!.day, 1);
    });
  });

  group('Гонка ответов', () {
    test('медленный ранний ответ не затирает свежий результат', () async {
      // Первый запрос отвечает дольше второго — как при быстром
      // переключении «Сегодня → Месяц».
      final repo = _SlowFirstRepository([
        const Duration(milliseconds: 300),
        const Duration(milliseconds: 10),
      ]);
      final bloc = ReportsBloc(repo);
      addTearDown(bloc.close);

      bloc.add(const ReportsRequested());
      bloc.add(const ReportsPeriodChanged(ReportPeriod.month));

      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Победить должен второй ответ (`totalRevenue == 2`), а не приехавший
      // последним первый.
      expect(bloc.state.summary?.revenue, 2);
      expect(bloc.state.period, ReportPeriod.month);
    });
  });
}

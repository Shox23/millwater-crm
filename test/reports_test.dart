import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/report_rows.dart';
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
  Future<List<GeneralReportRow>> getGeneralReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) async {
    final delay = _delays[_call.clamp(0, _delays.length - 1)];
    _call++;
    ranges.add((from: dateFrom, to: dateTo));
    await Future<void>.delayed(delay);
    // Выручка кодирует номер вызова — по ней видно, чей ответ дошёл.
    return [_row(amount: _call)];
  }
}

typedef ReportPeriodRange = ({DateTime? from, DateTime? to});

/// Строка общего отчёта — минимальная, со значащей только суммой.
GeneralReportRow _row({int amount = 0, int delivered = 0}) => GeneralReportRow(
      date: DateTime(2026, 8, 25),
      driverName: 'Азиз',
      customer: 'Кафе',
      deliveredCapsules: delivered,
      returnedCapsules: 0,
      damagedCapsules: 0,
      coolerCount: 0,
      orderAmount: amount,
    );

void main() {
  group('Сводка по должникам', () {
    test('итог равен сумме строк списка', () {
      // Долг сервер отдельным числом больше не присылает: он считается по
      // тем же заказчикам, что попадут в список, — иначе итог над списком
      // разошёлся бы с суммой его строк.
      final rows = [_row(amount: 100000)];
      final customers = [
        _customer(id: '1', debt: 120000),
        _customer(id: '2', debt: 300000),
        _customer(id: '3'),
      ];

      final summary = ReportsSummary.from(rows, customers);

      expect(summary.debtorsCount, 2);
      expect(summary.debtTotal, 420000);
      expect(
        summary.debtTotal,
        summary.debtors.fold<int>(0, (sum, d) => sum + d.amount),
      );
    });

    test('должники идут по убыванию суммы', () {
      final summary = ReportsSummary.from(const <GeneralReportRow>[], [
        _customer(id: '1', debt: 100),
        _customer(id: '2', debt: 900),
        _customer(id: '3', debt: 500),
      ]);

      expect(summary.debtors.map((d) => d.amount), [900, 500, 100]);
    });

    test('остаток капсул считается по всем заказчикам, не только должникам',
        () {
      final summary = ReportsSummary.from(const <GeneralReportRow>[], [
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

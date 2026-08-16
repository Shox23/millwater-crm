import 'package:equatable/equatable.dart';

import '../../core/utils/money_parser.dart';
import 'customer.dart';

/// Сводка отчёта ровно в том виде, в каком её отдаёт сервер
/// (`GET /admin/reports/summary`, схема `SummaryReport`).
///
/// Никаких досчётов: всё, что приходится выводить из других запросов,
/// собирает [ReportsSummary.from]. Так репозиторий остаётся переводчиком
/// JSON в модель и не начинает считать бизнес-показатели.
class SummaryReport extends Equatable {
  const SummaryReport({
    required this.routesCount,
    required this.completedDeliveries,
    required this.failedDeliveries,
    required this.totalRevenue,
    required this.totalDebt,
  });

  final int routesCount;
  final int completedDeliveries;
  final int failedDeliveries;

  /// Выручка за период, в сумах.
  final int totalRevenue;

  /// Общий долг заказчиков, в сумах.
  final int totalDebt;

  factory SummaryReport.fromJson(Map<String, dynamic> json) => SummaryReport(
        routesCount: json['routes_count'] as int? ?? 0,
        completedDeliveries: json['completed_deliveries_count'] as int? ?? 0,
        failedDeliveries: json['failed_deliveries_count'] as int? ?? 0,
        totalRevenue: MoneyParser.toSum(json['total_revenue']),
        totalDebt: MoneyParser.toSum(json['total_debt']),
      );

  @override
  List<Object?> get props => [
        routesCount,
        completedDeliveries,
        failedDeliveries,
        totalRevenue,
        totalDebt,
      ];
}

/// Строка списка должников.
class Debtor extends Equatable {
  const Debtor({
    required this.name,
    required this.district,
    required this.amount,
  });
  final String name;
  final String district;
  final int amount;

  @override
  List<Object?> get props => [name, district, amount];
}

/// Числа экрана «Отчёты», готовые к показу.
///
/// Собирается из серверной сводки и справочника заказчиков: списка должников
/// и остатка капсул в `/admin/reports/summary` нет, а показывать их надо.
class ReportsSummary extends Equatable {
  const ReportsSummary({
    required this.revenue,
    required this.deliveriesDone,
    required this.deliveriesTotal,
    required this.debtTotal,
    required this.capsulesActive,
    required this.debtors,
  });

  /// Сводит серверные числа со справочником заказчиков.
  ///
  /// Чистая функция, а не метод репозитория: считать бизнес-показатели —
  /// не работа слоя данных, а проверять их удобнее без сети.
  factory ReportsSummary.from(
    SummaryReport report,
    List<Customer> customers,
  ) {
    final debtors = customers.where((c) => c.debt > 0).toList()
      ..sort((a, b) => b.debt.compareTo(a.debt));

    return ReportsSummary(
      revenue: report.totalRevenue,
      deliveriesDone: report.completedDeliveries,
      deliveriesTotal: report.completedDeliveries + report.failedDeliveries,
      // Считаем по тем же заказчикам, что попадут в список должников, а не
      // берём `report.totalDebt`. Иначе в одной карточке стояли бы серверная
      // сумма и посчитанное здесь число должников, а над списком — итог,
      // не равный сумме его же строк.
      debtTotal: debtors.fold<int>(0, (sum, c) => sum + c.debt),
      capsulesActive:
          customers.fold<int>(0, (sum, c) => sum + c.capsuleBalance),
      debtors: debtors
          .map((c) => Debtor(
                name: c.name,
                district: c.comment ?? c.address,
                amount: c.debt,
              ))
          .toList(),
    );
  }

  /// Выручка за выбранный период, в сумах.
  final int revenue;
  final int deliveriesDone;
  final int deliveriesTotal;
  final int debtTotal;

  /// Капсулы, находящиеся на руках у заказчиков.
  final int capsulesActive;

  /// Должники, по убыванию суммы.
  final List<Debtor> debtors;

  /// Отдельным полем не хранится: разошедшись со списком, оно врало бы.
  int get debtorsCount => debtors.length;

  @override
  List<Object?> get props => [
        revenue,
        deliveriesDone,
        deliveriesTotal,
        debtTotal,
        capsulesActive,
        debtors,
      ];
}

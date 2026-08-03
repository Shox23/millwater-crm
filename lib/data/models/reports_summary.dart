import 'package:equatable/equatable.dart';

/// Столбец недельного графика выручки.
class WeeklyBar extends Equatable {
  const WeeklyBar({required this.label, required this.value});
  final String label;
  final int value;

  @override
  List<Object?> get props => [label, value];
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

/// Свод для экрана «Отчёты».
class ReportsSummary extends Equatable {
  const ReportsSummary({
    required this.revenueToday,
    required this.revenueChangePct,
    required this.deliveriesDone,
    required this.deliveriesTotal,
    required this.debtTotal,
    required this.debtorsCount,
    required this.capsulesActive,
    required this.capsulesTotal,
    required this.weekly,
    required this.weeklyTotal,
    required this.weeklyChangePct,
    required this.debtors,
  });

  final int revenueToday;
  final int revenueChangePct;
  final int deliveriesDone;
  final int deliveriesTotal;
  final int debtTotal;
  final int debtorsCount;
  final int capsulesActive;
  final int capsulesTotal;
  final List<WeeklyBar> weekly;
  final int weeklyTotal;
  final int weeklyChangePct;
  final List<Debtor> debtors;

  @override
  List<Object?> get props => [
        revenueToday,
        revenueChangePct,
        deliveriesDone,
        deliveriesTotal,
        debtTotal,
        debtorsCount,
        capsulesActive,
        capsulesTotal,
        weekly,
        weeklyTotal,
        weeklyChangePct,
        debtors,
      ];
}

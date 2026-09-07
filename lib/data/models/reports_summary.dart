import 'package:equatable/equatable.dart';

import 'customer.dart';
import 'report_rows.dart';

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
/// Собирается из двух источников, и это не небрежность, а следствие контракта.
/// Выручка и число доставок — показатели **периода**, их даёт общий отчёт
/// (`GET /admin/reports/general`). Долг, должники и остаток капсул — показатели
/// **на сейчас**, по всей базе; отчёт по заказчикам их не заменяет: он отдаёт
/// строку только на тех, у кого в периоде была активность, и за пустой день
/// вернул бы ноль должников при непустом долге.
class ReportsSummary extends Equatable {
  const ReportsSummary({
    required this.revenue,
    required this.deliveries,
    required this.capsulesDelivered,
    required this.debtTotal,
    required this.capsulesActive,
    required this.debtors,
  });

  /// Сводит показатели периода со справочником заказчиков.
  ///
  /// Чистая функция, а не метод репозитория: считать бизнес-показатели —
  /// не работа слоя данных, а проверять их удобнее без сети.
  factory ReportsSummary.from(
    List<GeneralReportRow> rows,
    List<Customer> customers,
  ) {
    final debtors = customers.where((c) => c.debt > 0).toList()
      ..sort((a, b) => b.debt.compareTo(a.debt));

    return ReportsSummary(
      revenue: rows.fold<int>(0, (sum, r) => sum + r.orderAmount),
      // Строка общего отчёта — одна доставка. Незавершённых в нём нет, и
      // прежнего «сделано из запланированных» показать больше не из чего:
      // сервер отдаёт только состоявшееся.
      deliveries: rows.length,
      capsulesDelivered:
          rows.fold<int>(0, (sum, r) => sum + r.deliveredCapsules),
      // Считаем по тем же заказчикам, что попадут в список должников, а не
      // берём отдельное число. Иначе в одной карточке стояли бы сумма из
      // одного источника и число должников из другого, а над списком — итог,
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

  /// Выручка за выбранный период, сум.
  final int revenue;

  /// Сколько доставок состоялось за период.
  final int deliveries;

  /// Сколько капсул увезли заказчикам за период.
  final int capsulesDelivered;

  final int debtTotal;

  /// Капсулы, находящиеся на руках у заказчиков, — по всей базе.
  final int capsulesActive;

  /// Должники, по убыванию суммы.
  final List<Debtor> debtors;

  /// Отдельным полем не хранится: разошедшись со списком, оно врало бы.
  int get debtorsCount => debtors.length;

  @override
  List<Object?> get props => [
        revenue,
        deliveries,
        capsulesDelivered,
        debtTotal,
        capsulesActive,
        debtors,
      ];
}

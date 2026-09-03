import 'package:equatable/equatable.dart';

import '../../core/utils/money_parser.dart';
import 'enums.dart';
import 'json.dart';

/// Расход водителя по маршруту (`ExpenseResponse`).
///
/// Деньги, потраченные в дороге: топливо, обед, ремонт. На сервере расход
/// вычитается из наличной кассы маршрута, поэтому запись здесь — не заметка
/// для себя, а часть денежного отчёта: удалять её может только тот, кто
/// понимает последствия.
class RouteExpense extends Equatable {
  const RouteExpense({
    required this.id,
    required this.routeId,
    required this.driverId,
    required this.amount,
    required this.category,
    this.comment,
    this.photoUrl,
    required this.createdAt,
  });

  final String id;
  final String routeId;
  final String driverId;

  /// Сумма расхода, сум.
  final int amount;
  final ExpenseCategory category;

  /// Зачем потрачено — необязательная приписка водителя.
  final String? comment;

  /// Снимок чека, если водитель его приложил.
  final String? photoUrl;
  final DateTime createdAt;

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  /// Разбор терпим: обязателен только `id`. Расход без маршрута или без даты
  /// всё равно показывает сумму — а именно она нужна в кассе.
  factory RouteExpense.fromJson(Map<String, dynamic> json) => RouteExpense(
        id: requireString(json['id'], 'id'),
        routeId: stringOr(json['route_id']),
        driverId: stringOr(json['driver_id']),
        amount: MoneyParser.toSum(json['amount']),
        category: ExpenseCategory.fromJson(stringOr(json['category'])),
        comment: optionalString(json['comment']),
        photoUrl: optionalString(json['photo_url']),
        createdAt: dateOr(json['created_at'], epoch),
      );

  @override
  List<Object?> get props =>
      [id, routeId, driverId, amount, category, comment, photoUrl, createdAt];
}

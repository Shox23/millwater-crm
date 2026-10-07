import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../data/models/enums.dart';

/// Что ожидается: сколько капсул везти и сколько денег привезти.
///
/// Одни и те же две строки на всех карточках — заказа, точки маршрута и
/// самого маршрута — у обеих ролей: водитель по ним собирает машину, админ
/// сверяет, что задал. У заказа это задание админа (`bottle_sell_count` и
/// `custom_price`), у маршрута — сумма по открытым точкам
/// (`RouteExpectations`). Показывать их стоит, пока заказ открыт: после
/// закрытия важнее факт, и карточка отдаёт место ему.
///
/// Вызывающий сам решает, показывать ли виджет: у пустого ожидания и у
/// закрытого заказа его быть не должно — см. [hasAny].
class OrderExpectations extends StatelessWidget {
  const OrderExpectations({
    super.key,
    required this.capsules,
    required this.amount,
    this.purpose = OrderPurpose.delivery19l,
  });

  final int? capsules;
  final int? amount;

  /// Зачем едем. У вывоза то же число значит обратное — «забрать», а не
  /// «везти»: поле на сервере одно (`bottle_sell_count`), и без цели строка
  /// читается неверно. У маршрута целиком цели нет — там доставка по
  /// умолчанию, и капсулы в сводке действительно про погрузку.
  final OrderPurpose purpose;

  /// Есть что показать: капсулы или деньги больше нуля. Ноль — это «не
  /// задавали», как и `null`: договорная сумма нулём не бывает, а у
  /// маршрута из одних бесплатных вывозов денег не ждут.
  static bool hasAny({required int? capsules, required int? amount}) =>
      (capsules ?? 0) > 0 || (amount ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        if ((capsules ?? 0) > 0)
          Row(
            spacing: 4,
            children: [
              Icon(Icons.water_drop_outlined, size: 16, color: t.primary),
              Expanded(
                child: Text(
                  purpose == OrderPurpose.pickup
                      ? l10n.stopBottleSellPickup(capsules!)
                      : l10n.stopBottleSell(capsules!),
                  style: AppTypography.secondary.copyWith(color: t.primary),
                ),
              ),
            ],
          ),
        if ((amount ?? 0) > 0)
          Row(
            spacing: 4,
            children: [
              Icon(Icons.sell_outlined, size: 16, color: t.primary),
              Expanded(
                child: Text(
                  l10n.stopCustomPrice(MoneyFormatter.sum(l10n, amount!)),
                  style: AppTypography.secondary.copyWith(color: t.primary),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

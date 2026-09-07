import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import '../../data/models/route_models.dart';
import '../utils/money_formatter.dart';
import 'app_card.dart';

/// Касса маршрута: наличные, безнал, долг, расходы и остаток.
///
/// Общая для водителя и админа: числа одни и те же, считает их сервер, и
/// расходиться двум экранам нельзя — водитель сдаёт ровно тот остаток,
/// который админ у себя видит.
///
/// Кассой считаются **только наличные**: карта и перевод уходят на счёт
/// компании, водитель их в руках не держит, и вычитать из них обед было бы
/// неправдой. Полная выручка маршрута — наличные плюс безнал.
///
/// Все поля необязательны: старый стенд их не отдаёт. Пустая касса и
/// отсутствие кассы одинаково означают «сдавать нечего».
class RouteCashCard extends StatelessWidget {
  const RouteCashCard({super.key, required this.route, this.showHint = true});

  final RouteDetail route;

  /// Пояснение под остатком. Водителю оно нужно — он по этому числу сдаёт
  /// деньги; в админской карточке маршрута строка только шумит.
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final balance = route.cashBalance ?? 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          _CashRow(
            label: l10n.cashCollectedCash,
            value: route.cashCollected ?? 0,
          ),
          _CashRow(
            label: l10n.cashCollectedCashless,
            value: route.cashlessCollected ?? 0,
          ),
          _CashRow(label: l10n.cashDebtAmount, value: route.debtAmount ?? 0),
          _CashRow(
            label: l10n.cashExpensesTotal,
            value: route.expensesTotal ?? 0,
          ),
          Divider(color: t.border, height: 1),
          _CashRow(
            label: l10n.cashBalance,
            value: balance,
            strong: true,
            // Минус — рабочее состояние: расход больше собранного разрешён,
            // водитель заправился на свои.
            color: balance < 0 ? t.danger : t.success,
          ),
          if (showHint)
            Text(l10n.cashBalanceHint,
                style: AppTypography.secondary.copyWith(color: t.text2)),
        ],
      ),
    );
  }
}

class _CashRow extends StatelessWidget {
  const _CashRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.color,
  });

  final String label;
  final int value;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppTypography.secondary.copyWith(color: t.text2)),
        ),
        Text(
          MoneyFormatter.sum(context.l10n, value),
          style: strong
              ? AppTypography.money
                  .copyWith(fontSize: 18, color: color ?? t.text)
              : AppTypography.bodyStrong.copyWith(color: color ?? t.text),
        ),
      ],
    );
  }
}

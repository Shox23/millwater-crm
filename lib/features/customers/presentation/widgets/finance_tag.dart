import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../data/models/customer.dart';

/// Финансовый бейдж заказчика: предоплата (success) или долг (danger).
class FinanceTag extends StatelessWidget {
  const FinanceTag({
    super.key,
    required this.label,
    required this.amount,
    required this.isDebt,
  });

  final String label;
  final int amount;
  final bool isDebt;

  /// Строит бейдж по данным заказчика, либо null, если баланс нулевой.
  static FinanceTag? forCustomer(AppLocalizations l10n, Customer c) {
    if (c.prepayment > 0) {
      return FinanceTag(
        label: l10n.financePrepayment,
        amount: c.prepayment,
        isDebt: false,
      );
    }
    if (c.debt > 0) {
      return FinanceTag(label: l10n.financeDebt, amount: c.debt, isDebt: true);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tone = isDebt ? t.danger : t.success;
    final bg = isDebt ? t.dangerBg : t.successBg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          Text(label, style: AppTypography.badge.copyWith(color: tone)),
          MoneyText(
            amount: amount,
            numberStyle: AppTypography.bodyStrong.copyWith(color: tone),
            currencyColor: tone,
          ),
        ],
      ),
    );
  }
}

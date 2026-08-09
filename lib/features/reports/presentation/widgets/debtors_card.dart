import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/reports_summary.dart';

/// Карточка «Долги заказчиков» со списком должников.
class DebtorsCard extends StatelessWidget {
  const DebtorsCard({super.key, required this.total, required this.debtors});

  final int total;
  final List<Debtor> debtors;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: Text(context.l10n.reportsDebtors,
                    style: AppTypography.bodyStrong.copyWith(color: t.text)),
              ),
              Text(
                MoneyFormatter.sum(context.l10n, total),
                style: AppTypography.bodyStrong.copyWith(color: t.danger),
              ),
            ],
          ),
          for (var i = 0; i < debtors.length; i++) ...[
            if (i > 0) const Divider(),
            _DebtorRow(debtor: debtors[i]),
          ],
        ],
      ),
    );
  }
}

class _DebtorRow extends StatelessWidget {
  const _DebtorRow({required this.debtor});
  final Debtor debtor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      spacing: AppSpacing.md,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(debtor.name,
                  style: AppTypography.bodyStrong.copyWith(color: t.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(debtor.district,
                  style: AppTypography.secondary.copyWith(color: t.text2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Text(
          MoneyFormatter.amount(debtor.amount),
          style: AppTypography.bodyStrong.copyWith(color: t.danger),
        ),
      ],
    );
  }
}

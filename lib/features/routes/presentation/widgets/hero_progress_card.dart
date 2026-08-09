import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/money_text.dart';

/// Акцентная градиентная карточка прогресса на экране «Маршруты».
class HeroProgressCard extends StatelessWidget {
  const HeroProgressCard({
    super.key,
    required this.done,
    required this.total,
    this.collected,
  });

  final int done;
  final int total;

  /// Сумма за период. `null` — блок «Собрано» не рисуется: у водителя
  /// денежного показателя нет, сводный отчёт ему недоступен.
  final int? collected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final progress = total == 0 ? 0.0 : done / total;
    const labelStyle = TextStyle(
      color: Colors.white70,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.primary, t.primary2],
        ),
        boxShadow: t.accentShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(context.l10n.routeProgressTitle, style: labelStyle),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$done',
                            style: AppTypography.screenTitle
                                .copyWith(color: Colors.white),
                          ),
                          TextSpan(
                            text: ' / $total',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (collected case final int amount)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(context.l10n.routeCollectedToday, style: labelStyle),
                    MoneyText(
                      amount: amount,
                      numberStyle: AppTypography.screenTitle
                          .copyWith(color: Colors.white, fontSize: 22),
                      currencyColor: Colors.white70,
                    ),
                  ],
                ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

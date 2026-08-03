import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';

/// Карточка показателя в сетке 2×2 на экране «Отчёты».
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.aux,
    this.auxColor,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? aux;
  final Color? auxColor;

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
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.softOf(iconColor),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              if (aux != null)
                Expanded(
                  child: Text(
                    aux!,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.badge
                        .copyWith(color: auxColor ?? t.text2),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(value,
                  style: AppTypography.statNumber.copyWith(color: t.text)),
              Text(label,
                  style: AppTypography.secondary.copyWith(color: t.text2)),
            ],
          ),
        ],
      ),
    );
  }
}

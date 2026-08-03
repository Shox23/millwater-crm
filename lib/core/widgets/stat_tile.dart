import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import 'app_card.dart';

/// Карточка со значением и подписью (статы в деталях/отчётах).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.alignment = CrossAxisAlignment.start,
  });

  final String value;
  final String label;
  final Color? valueColor;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Text(value,
              style:
                  AppTypography.statNumber.copyWith(color: valueColor ?? t.text)),
          Text(label,
              style: AppTypography.secondary.copyWith(color: t.text2)),
        ],
      ),
    );
  }
}

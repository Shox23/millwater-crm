import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import 'app_card.dart';

/// Карточка с меткой-заголовком: подпись капсом и содержимое под ней.
///
/// Так собран весь экран завершения доставки — количество капсул, остаток у
/// клиента, способ оплаты. Вынесено из него, чтобы блоки того же смысла
/// («вот число, вот его название») выглядели одинаково и у водителя, и у
/// админа: две копии одного оформления разошлись бы на первой же правке.
class LabeledCard extends StatelessWidget {
  const LabeledCard({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Text(label, style: AppTypography.fieldLabel.copyWith(color: t.text2)),
          child,
        ],
      ),
    );
  }
}

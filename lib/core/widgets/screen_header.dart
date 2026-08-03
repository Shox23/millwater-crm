import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

/// Шапка списочного экрана: капс-подпись, крупный заголовок и слот действия.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.label,
    required this.title,
    this.action,
  });

  final String label;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTypography.sectionLabel.copyWith(color: t.primary),
              ),
              Text(title,
                  style: AppTypography.screenTitle.copyWith(color: t.text)),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

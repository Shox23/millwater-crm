import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../theme/desktop_typography.dart';

/// Пустое состояние: иконка в крупной плитке, заголовок и подсказка.
class DesktopEmpty extends StatelessWidget {
  const DesktopEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.md,
        children: [
          Container(
            width: 70,
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(icon, size: 30, color: t.text3),
          ),
          Text(title,
              textAlign: TextAlign.center,
              style: DesktopTypography.cardTitle.copyWith(color: t.text)),
          if (hint != null)
            Text(hint!,
                textAlign: TextAlign.center,
                style: DesktopTypography.secondary.copyWith(color: t.text2)),
        ],
      ),
    );
  }
}

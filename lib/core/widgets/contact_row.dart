import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

/// Строка контакта: иконка в мягком квадрате + подпись + значение.
class ContactRow extends StatelessWidget {
  const ContactRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.iconBackground,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Color? iconBackground;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = iconColor ?? t.primary;

    return Row(
      spacing: AppSpacing.md,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconBackground ?? t.softOf(fg),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 20, color: fg),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(label,
                  style: AppTypography.secondary.copyWith(color: t.text2)),
              Text(value,
                  style: AppTypography.bodyStrong.copyWith(color: t.text)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

enum StatusTone { success, progress, neutral, danger, warn, primary }

/// Статус-пилюля: текст цвета статуса на его полупрозрачной подложке.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.text,
    this.tone = StatusTone.neutral,
    this.showDot = false,
  });

  final String text;
  final StatusTone tone;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (fg, bg) = switch (tone) {
      StatusTone.success => (t.success, t.successBg),
      StatusTone.progress => (t.primary, t.softOf(t.primary)),
      StatusTone.danger => (t.danger, t.dangerBg),
      StatusTone.warn => (t.warn, t.warnBg),
      StatusTone.primary => (t.primary, t.softOf(t.primary)),
      StatusTone.neutral => (t.text2, t.surface3),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (showDot)
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          Text(
            text,
            style: AppTypography.badge.copyWith(color: fg, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

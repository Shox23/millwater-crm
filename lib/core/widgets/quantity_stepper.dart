import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

/// Счётчик количества: [ − ]  N  [ + ] с подписью снизу.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.caption,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      spacing: AppSpacing.md,
      children: [
        _StepButton(
          icon: Icons.remove,
          filled: false,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        Expanded(
          child: Column(
            spacing: 2,
            children: [
              Text('$value',
                  style: AppTypography.statNumber.copyWith(color: t.text)),
              if (caption != null)
                Text(caption!,
                    style: AppTypography.secondary.copyWith(color: t.text2)),
            ],
          ),
        ),
        _StepButton(
          icon: Icons.add,
          filled: true,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;
    final bg = filled
        ? (enabled ? t.primary : t.primary.withValues(alpha: 0.38))
        : t.surface2;
    final fg = filled ? Colors.white : t.text;

    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          mouseCursor:
              enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Icon(icon, color: fg, size: 24),
        ),
      ),
    );
  }
}

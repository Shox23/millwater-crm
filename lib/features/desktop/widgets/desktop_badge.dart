import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../theme/desktop_typography.dart';

/// Статус-пилюля десктопа: цвет — цвет статуса, фон — его же 10–15% альфы.
class DesktopBadge extends StatelessWidget {
  const DesktopBadge({
    super.key,
    required this.text,
    required this.color,
    this.large = false,
    this.showDot = false,
  });

  final String text;

  /// Цвет статуса; подложка считается из него.
  final Color color;

  /// Крупный вариант — в шапке drawer и карточке водителя.
  final bool large;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 11,
        vertical: large ? 6 : 5,
      ),
      decoration: BoxDecoration(
        color: t.softOf(color),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (showDot)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          Text(
            text,
            style: (large
                    ? DesktopTypography.badgeLarge
                    : DesktopTypography.badge)
                .copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Счётчик у пункта меню: число на мягкой подложке.
class DesktopCountBadge extends StatelessWidget {
  const DesktopCountBadge({
    super.key,
    required this.count,
    required this.color,
  });

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.softOf(color),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: DesktopTypography.badge.copyWith(color: color),
      ),
    );
  }
}

/// Фильтр-чип со счётчиком: активный — акцентный фон и белый текст.
class DesktopChip extends StatelessWidget {
  const DesktopChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? Colors.white : t.text2;

    return Semantics(
      button: true,
      selected: selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? t.primary : t.surface2,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: selected ? t.primary : t.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Text(label,
                    style: DesktopTypography.badgeLarge.copyWith(color: fg)),
                // Счётчик приглушён: он подсказка, а не сама подпись.
                Opacity(
                  opacity: 0.65,
                  child: Text('$count',
                      style: DesktopTypography.badgeLarge.copyWith(color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

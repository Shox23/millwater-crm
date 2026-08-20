import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../theme/desktop_typography.dart';

/// Карточка-поверхность десктопа: фон, рамка, тень и подъём под курсором.
class DesktopCard extends StatefulWidget {
  const DesktopCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  State<DesktopCard> createState() => _DesktopCardState();
}

class _DesktopCardState extends State<DesktopCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final interactive = widget.onTap != null;
    final lifted = interactive && _hovered;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      // Подъём на 3px даёт понять, что карточка кликабельна, до того как
      // пользователь попробует по ней щёлкнуть.
      transform: Matrix4.translationValues(0, lifted ? -3 : 0, 0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: t.border),
        boxShadow: lifted ? t.hoverShadow : t.cardShadow,
      ),
      child: widget.child,
    );

    if (!interactive) return card;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        child: GestureDetector(onTap: widget.onTap, child: card),
      ),
    );
  }
}

/// KPI-карточка: иконка в цветной плитке, крупное значение, подпись.
class DesktopKpiCard extends StatelessWidget {
  const DesktopKpiCard({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.hint,
    this.large = false,
  });

  final IconData icon;

  /// Цвет плитки с иконкой; подложка считается из него.
  final Color color;

  final String value;
  final String label;

  /// Мелкая приписка под подписью — например, что число оценочное.
  final String? hint;

  /// Крупный вариант — в разделе отчётов.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tile = large ? 40.0 : 38.0;

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Container(
            width: tile,
            height: tile,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.softOf(color),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                value,
                style: (large
                        ? DesktopTypography.kpiValueLarge
                        : DesktopTypography.kpiValue)
                    .copyWith(color: t.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(label,
                  style: DesktopTypography.kpiLabel.copyWith(color: t.text2)),
              if (hint != null)
                Text(hint!,
                    style: DesktopTypography.caption.copyWith(color: t.text3)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Акцентная сводка дня: градиент, прогресс и две приписки снизу.
class DesktopSummaryCard extends StatelessWidget {
  const DesktopSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.progress,
    required this.footnotes,
  });

  final String title;

  /// Крупная строка: «5 / 10» или «6 маршрутов».
  final String value;

  /// 0..1; отрицательного и большего единицы не бывает.
  final double progress;

  /// Пары «подпись — значение» под полосой прогресса.
  final List<(String, String)> footnotes;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.primary, t.primary2],
          ),
        ),
        child: Stack(
          children: [
            // Декоративные круги: карточка не должна выглядеть плоской
            // заливкой рядом с белыми соседями.
            Positioned(
              right: -30,
              top: -40,
              child: _Circle(size: 140),
            ),
            Positioned(
              right: 60,
              bottom: -70,
              child: _Circle(size: 120),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.md,
                children: [
                  Text(title,
                      style: DesktopTypography.kpiLabel
                          .copyWith(color: Colors.white70)),
                  Text(value,
                      style: DesktopTypography.kpiValue
                          .copyWith(color: Colors.white)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 7,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  Row(
                    children: [
                      for (final (label, value) in footnotes)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 1,
                            children: [
                              Text(label,
                                  style: DesktopTypography.caption
                                      .copyWith(color: Colors.white70)),
                              Text(value,
                                  style: DesktopTypography.bodyStrong
                                      .copyWith(color: Colors.white)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0x17FFFFFF),
        shape: BoxShape.circle,
      ),
    );
  }
}

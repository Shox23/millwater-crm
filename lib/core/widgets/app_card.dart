import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';

/// Карточка-контейнер: поверхность, скругление --r-lg, мягкая тень темы.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.radius = AppRadius.lg,
    this.compact = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  /// Компактный режим — паддинг 13 вместо 16.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final borderRadius = BorderRadius.circular(radius);
    final resolved = padding ??
        EdgeInsets.all(compact ? AppSpacing.cardCompact : AppSpacing.card);

    return DecoratedBox(
      decoration:
          BoxDecoration(borderRadius: borderRadius, boxShadow: t.cardShadow),
      child: Material(
        color: color ?? t.surface,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          mouseCursor:
              onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: Padding(padding: resolved, child: child),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';

/// Нижняя панель действий экрана-оверлея.
/// [filled] — поверхность с верхней границей (для сводных панелей).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.filled = false});

  final Widget child;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: filled
          ? BoxDecoration(
              color: t.surface,
              border: Border(top: BorderSide(color: t.border)),
            )
          : null,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: child,
        ),
      ),
    );
  }
}

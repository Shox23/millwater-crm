import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary }

/// Кнопка приложения. primary — акцент с цветной тенью, secondary — на surface2.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.height = 52,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final double height;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isPrimary = variant == AppButtonVariant.primary;
    final active = enabled && onPressed != null;

    final Color bg;
    final Color fg;
    if (isPrimary) {
      bg = active ? t.primary : t.primary.withValues(alpha: 0.38);
      fg = Colors.white;
    } else {
      bg = t.surface2;
      fg = t.text;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: isPrimary && active ? t.accentShadow : null,
      ),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: active ? onPressed : null,
          mouseCursor:
              active ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.sm,
                children: [
                  if (icon != null) Icon(icon, size: 20, color: fg),
                  // Подпись сжимается, а не рвёт вёрстку: в кнопке половинной
                  // ширины длинные подписи и увеличенный системный шрифт
                  // иначе дают overflow.
                  Flexible(
                    child: Text(
                      label,
                      style: AppTypography.button.copyWith(color: fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Небольшая квадратная кнопка-иконка (редактировать / удалить / позвонить).
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.background,
    this.size = 44,
    this.tone = IconActionTone.neutral,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Подпись для скринридера и всплывающей подсказки: у кнопки нет текста.
  final String? tooltip;
  final Color? color;
  final Color? background;

  /// Минимум 44 — рекомендованный размер зоны нажатия.
  final double size;
  final IconActionTone tone;

  /// Пресет для кнопки удаления.
  factory IconActionButton.delete({
    VoidCallback? onPressed,
    double size = 44,
    String tooltip = 'Удалить',
  }) {
    return IconActionButton(
      icon: Icons.delete_outline_rounded,
      onPressed: onPressed,
      tooltip: tooltip,
      size: size,
      tone: IconActionTone.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (fg, bg) = switch (tone) {
      IconActionTone.danger => (t.danger, t.dangerBg),
      IconActionTone.primary => (t.primary, t.softOf(t.primary)),
      IconActionTone.neutral => (t.text2, t.surface2),
    };

    final button = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: background ?? bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          mouseCursor: onPressed == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: Icon(icon, size: 20, color: color ?? fg),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(
      message: tooltip!,
      child: Semantics(button: true, label: tooltip, child: button),
    );
  }
}

enum IconActionTone { neutral, primary, danger }

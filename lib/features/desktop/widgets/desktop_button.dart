import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../theme/desktop_typography.dart';

enum DesktopButtonVariant {
  /// Основное действие: акцентный фон, белый текст, тень.
  primary,

  /// Второстепенное: приглушённая поверхность.
  soft,

  /// Опасное: подложка danger.
  danger,
}

/// Кнопка десктопа.
///
/// Своя, а не мобильный `AppButton`: тот жёстко берёт Inter и высоту 54 —
/// на десктопе такая кнопка в шапке занимает половину её высоты.
class DesktopButton extends StatefulWidget {
  const DesktopButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = DesktopButtonVariant.primary,
    this.height = 42,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DesktopButtonVariant variant;
  final double height;

  /// Растянуть по ширине родителя (кнопки в футере drawer).
  final bool expand;

  @override
  State<DesktopButton> createState() => _DesktopButtonState();
}

class _DesktopButtonState extends State<DesktopButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final disabled = widget.onPressed == null;

    final (bg, fg) = switch (widget.variant) {
      DesktopButtonVariant.primary => (t.primary, Colors.white),
      DesktopButtonVariant.soft => (t.surface3, t.text),
      DesktopButtonVariant.danger => (t.dangerBg, t.danger),
    };

    final child = DecoratedBox(
      decoration: BoxDecoration(
        // Выключенная кнопка гасится приглушённой заливкой, а не прозрачностью:
        // полупрозрачный акцент на цветной подложке даёт грязный оттенок.
        color: disabled ? t.surface3 : bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: widget.variant == DesktopButtonVariant.primary && !disabled
            ? [
                BoxShadow(
                  color: t.primaryLine,
                  blurRadius: 26,
                  spreadRadius: -12,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        height: widget.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              if (widget.icon != null)
                Icon(widget.icon, size: 18, color: disabled ? t.text3 : fg),
              Text(
                widget.label,
                style: DesktopTypography.button
                    .copyWith(color: disabled ? t.text3 : fg),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      child: MouseRegion(
        cursor: disabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _hovered && !disabled ? 0.88 : 1,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Квадратная кнопка-иконка: обновление, уведомления, закрытие оверлея.
class DesktopIconButton extends StatefulWidget {
  const DesktopIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 42,
    this.badge = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;

  /// Красная точка в углу — есть непрочитанное.
  final bool badge;
  final Color? color;

  @override
  State<DesktopIconButton> createState() => _DesktopIconButtonState();
}

class _DesktopIconButtonState extends State<DesktopIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _hovered ? t.surface3 : t.surface2,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: t.border),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(widget.icon, size: 19, color: widget.color ?? t.text2),
                  if (widget.badge)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: t.danger,
                          shape: BoxShape.circle,
                          // Обводка цветом кнопки: без неё точка сливается
                          // с иконкой колокольчика под ней.
                          border: Border.all(color: t.surface2, width: 1.5),
                        ),
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

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../theme/desktop_typography.dart';
import '../widgets/desktop_button.dart';
import 'desktop_overlays.dart';

/// Каркас модального окна: заголовок, тело и футер на приглушённой подложке.
class DesktopModalPanel extends StatelessWidget {
  const DesktopModalPanel({
    super.key,
    required this.title,
    required this.body,
    required this.footer,
    this.subtitle,
    this.width = 520,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget footer;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: t.modalShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(title,
                      style: DesktopTypography.modalTitle
                          .copyWith(color: t.text)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: DesktopTypography.secondary
                            .copyWith(color: t.text2)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                child: body,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: t.surface2,
                border: Border(top: BorderSide(color: t.border)),
              ),
              child: footer,
            ),
          ],
        ),
      ),
    );
  }
}

/// Модалка успеха: галочка с отскоком и короткий чек-лист.
class DesktopSuccessModal extends StatefulWidget {
  const DesktopSuccessModal({
    super.key,
    required this.title,
    required this.lines,
    required this.actionLabel,
  });

  final String title;

  /// Пары «подпись — значение», подтверждающие, что именно записано.
  final List<(String, String)> lines;

  final String actionLabel;

  @override
  State<DesktopSuccessModal> createState() => _DesktopSuccessModalState();
}

class _DesktopSuccessModalState extends State<DesktopSuccessModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 440,
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: t.modalShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.lg,
          children: [
            ScaleTransition(
              // Отскок: галочка «влетает» и слегка перелетает конечный
              // размер — так подтверждение читается как событие, а не как
              // ещё одна нарисованная иконка.
              scale: CurvedAnimation(
                parent: _controller,
                curve: const Cubic(0.2, 0.8, 0.2, 1),
              ).drive(Tween(begin: 0.4, end: 1.0)),
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.successBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, size: 46, color: t.success),
              ),
            ),
            Text(widget.title,
                textAlign: TextAlign.center,
                style: DesktopTypography.modalTitle.copyWith(color: t.text)),
            if (widget.lines.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: t.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final (label, value) in widget.lines)
                      Row(
                        children: [
                          Text(label,
                              style: DesktopTypography.secondary
                                  .copyWith(color: t.text2)),
                          const Spacer(),
                          Text(value,
                              style: DesktopTypography.bodyStrong
                                  .copyWith(color: t.text)),
                        ],
                      ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: DesktopButton(
                label: widget.actionLabel,
                height: 46,
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Спрашивает подтверждение опасного действия.
///
/// Своя, а не мобильная `showConfirmDialog`: та собрана мобильной
/// типографикой, и в десктопном окне рядом с Onest выглядела бы чужой.
Future<bool> showDesktopConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDesktopModal<bool>(
    context,
    builder: (context) => DesktopModalPanel(
      title: title,
      width: 440,
      body: Text(
        message,
        style: DesktopTypography.body.copyWith(color: context.tokens.text2),
      ),
      footer: Row(
        spacing: AppSpacing.md,
        children: [
          const Spacer(),
          DesktopButton(
            label: context.l10n.commonCancel,
            variant: DesktopButtonVariant.soft,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          DesktopButton(
            label: confirmLabel,
            variant: DesktopButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}

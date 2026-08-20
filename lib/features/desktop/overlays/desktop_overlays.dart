import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../theme/desktop_theme.dart';
import '../theme/desktop_typography.dart';

/// Открывает панель справа.
///
/// Через `showGeneralDialog`, а не своим слоем в `Stack`: так бесплатно
/// работают Esc, клик по затемнению и возврат фокуса — писать это руками
/// значило бы получить панель, из которой не выйти клавиатурой.
///
/// Содержимое оборачивается в [DesktopTheme] ещё раз: диалог живёт в том же
/// `Navigator`, что и `home`, то есть **над** десктопной темой, и без этого
/// панель отрисовалась бы мобильными токенами и мобильным шрифтом.
Future<T?> showDesktopDrawer<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: context.tokens.overlay,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => DesktopTheme(
      child: Align(
        alignment: Alignment.centerRight,
        child: Builder(builder: builder),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        // 28px сдвига при ширине панели 460 — это 0.06 от неё.
        position: Tween(begin: const Offset(0.06, 0), end: Offset.zero)
            .animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// Открывает модальное окно по центру.
Future<T?> showDesktopModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: context.tokens.overlay,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => DesktopTheme(
      child: Center(child: Builder(builder: builder)),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position:
              Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween(begin: 0.985, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Показывает тост внизу по центру на 2.2 секунды.
///
/// Не `SnackBar`: тот прилипает к низу окна во всю ширину, а на 1728px это
/// полоса через весь экран ради одной строки.
void showDesktopToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      message: message,
      onDone: () => entry.mounted ? entry.remove() : null,
    ),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 36,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _controller,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.4), end: Offset.zero)
                  .animate(CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOutCubic,
              )),
              child: _ToastBody(message: widget.message),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastBody extends StatelessWidget {
  const _ToastBody({required this.message});

  final String message;

  /// Тёмная пилюля одна в обеих темах: тост перекрывает содержимое, и на
  /// светлой подложке белая плашка на белом фоне просто теряется.
  static const _bg = Color(0xFF0F2A43);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: t.modalShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.sm,
          children: [
            Icon(Icons.check_circle_rounded, size: 18, color: t.success),
            Text(
              message,
              style: DesktopTypography.bodyStrong.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Каркас панели справа: шапка, прокручиваемое тело, футер с действиями.
class DesktopDrawerPanel extends StatelessWidget {
  const DesktopDrawerPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final Widget? footer;

  static const width = 460.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Material(
      color: t.surface,
      child: Container(
        width: width,
        height: double.infinity,
        decoration: BoxDecoration(
          color: t.surface,
          boxShadow: t.drawerShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(title,
                            style: DesktopTypography.modalTitle
                                .copyWith(color: t.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(subtitle,
                            style: DesktopTypography.secondary
                                .copyWith(color: t.text2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  _CloseButton(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: body,
              ),
            ),
            if (footer != null)
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

class _CloseButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Tooltip(
            message: context.l10n.commonClose,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.surface2,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.close_rounded, size: 19, color: t.text2),
            ),
          ),
        ),
      ),
    );
  }
}

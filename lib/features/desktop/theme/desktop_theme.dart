import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import 'desktop_typography.dart';

/// Подменяет тему на десктопную для всего поддерева.
///
/// Меняются три вещи: набор токенов (в тёмной теме десктоп ярче), шрифт
/// (Onest вместо мобильного Inter) и оформление скроллбаров — на десктопе
/// они видимые и постоянные, а не всплывающие, как на телефоне.
///
/// Сделано обёрткой, а не правкой [AppTheme], чтобы мобильная версия осталась
/// нетронутой: она согласована и меняться не должна. Компоненты про это не
/// знают — `context.tokens` работает как обычно.
class DesktopTheme extends StatelessWidget {
  const DesktopTheme({super.key, required this.child});

  final Widget child;

  /// Цвет ползунка скроллбара: rgba(120,150,180,.32).
  static const _thumb = Color(0x527896B4);

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final tokens = base.extension<AppTokens>()!;
    final desktop =
        tokens.isDark ? AppTokens.darkDesktop : AppTokens.lightDesktop;

    return Theme(
      data: base.copyWith(
        extensions: [desktop],
        scaffoldBackgroundColor: desktop.bg,
        textTheme: base.textTheme.apply(
          fontFamily: DesktopTypography.fontFamily,
          bodyColor: desktop.text,
          displayColor: desktop.text,
        ),
        scrollbarTheme: ScrollbarThemeData(
          thickness: const WidgetStatePropertyAll(8),
          thumbColor: const WidgetStatePropertyAll(_thumb),
          trackColor: const WidgetStatePropertyAll(Colors.transparent),
          trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
          radius: const Radius.circular(AppRadius.pill),
          // Мышь есть всегда — ползунок не должен появляться только на скролле.
          thumbVisibility: const WidgetStatePropertyAll(true),
        ),
        // Подсказки и ошибки полей тоже должны быть на Onest, иначе внутри
        // десктопной формы соседствовали бы два шрифта.
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          fillColor: desktop.surface,
          hintStyle: DesktopTypography.body.copyWith(color: desktop.text3),
          helperStyle: DesktopTypography.secondary.copyWith(
            color: desktop.text3,
            fontSize: 12,
          ),
          errorStyle: DesktopTypography.secondary.copyWith(
            color: desktop.danger,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: child,
    );
  }
}

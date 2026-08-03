import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_spacing.dart';
import 'app_tokens.dart';

/// Сборка ThemeData из набора токенов.
///
/// Светлая и тёмная темы строятся одной функцией — различаются только токены.
abstract class AppTheme {
  static ThemeData light() => _build(AppTokens.light, Brightness.light);

  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final base = ThemeData(useMaterial3: true, brightness: brightness);

    return base.copyWith(
      extensions: [t],
      scaffoldBackgroundColor: t.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: t.primary,
        secondary: t.aqua,
        surface: t.surface,
        error: t.danger,
        onSurface: t.text,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: t.text,
        displayColor: t.text,
      ),
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      datePickerTheme: DatePickerThemeData(backgroundColor: t.surface),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        hintStyle: GoogleFonts.inter(
          color: t.text3,
          fontWeight: FontWeight.w500,
        ),
        helperStyle: GoogleFonts.inter(
          color: t.text3,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: GoogleFonts.inter(
          color: t.danger,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        errorMaxLines: 2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        border: _inputBorder(t.border),
        enabledBorder: _inputBorder(t.border),
        focusedBorder: _inputBorder(t.primary),
        errorBorder: _inputBorder(t.danger),
        focusedErrorBorder: _inputBorder(t.danger),
      ),
    );
  }

  /// Рамка поля: 1.5px, радиус 13 — фокус меняет только цвет.
  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: color, width: 1.5),
      );
}

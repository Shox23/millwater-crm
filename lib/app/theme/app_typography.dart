import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Типографика на основе Inter.
///
/// Стили не задают цвет — он приходит из токенов темы в месте применения
/// (`DefaultTextStyle` от ThemeData или явный `.copyWith(color: t.text2)`).
abstract class AppTypography {
  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Крупный заголовок экрана («Маршруты», «Водители»).
  static TextStyle get screenTitle =>
      _inter(size: 28, weight: FontWeight.w800, height: 1.05);

  /// Заголовок детального экрана (в аппбаре).
  static TextStyle get appBarTitle => _inter(size: 20, weight: FontWeight.w700);

  /// Капс-подпись над заголовком («СЕГОДНЯ · 05.07.26»).
  static TextStyle get sectionLabel =>
      _inter(size: 12, weight: FontWeight.w700, letterSpacing: 1.2);

  /// Подпись-капс внутри карточек («КОЛИЧЕСТВО КАПСУЛ»).
  static TextStyle get fieldLabel =>
      _inter(size: 12, weight: FontWeight.w700, letterSpacing: 0.8);

  /// Заголовок карточки (название заказчика/маршрута).
  static TextStyle get cardTitle => _inter(size: 17, weight: FontWeight.w700);

  static TextStyle get body => _inter(size: 15, weight: FontWeight.w500);

  static TextStyle get bodyStrong => _inter(size: 15, weight: FontWeight.w700);

  static TextStyle get secondary => _inter(size: 13, weight: FontWeight.w500);

  /// Крупное число (статы, сумма к оплате).
  static TextStyle get statNumber => _inter(size: 24, weight: FontWeight.w800);

  static TextStyle get money => _inter(size: 16, weight: FontWeight.w800);

  /// Текст статус-пилюли.
  static TextStyle get badge => _inter(size: 12, weight: FontWeight.w700);

  static TextStyle get button => _inter(size: 16, weight: FontWeight.w700);
}

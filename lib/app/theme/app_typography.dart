import 'package:flutter/material.dart';

/// Типографика на основе Inter.
///
/// Стили не задают цвет — он приходит из токенов темы в месте применения
/// (`DefaultTextStyle` от ThemeData или явный `.copyWith(color: t.text2)`).
///
/// Все стили — константы, а не геттеры. Раньше каждое обращение собирало
/// стиль заново через `GoogleFonts.inter(...)`: 23 микросекунды на вызов при
/// 136 местах вызова и полусотне обращений на перестроение списка. Теперь
/// это литералы, известные на этапе компиляции.
abstract class AppTypography {
  /// Семейство объявлено в pubspec и лежит в сборке — см. `assets/fonts`.
  static const String fontFamily = 'Inter';

  /// Крупный заголовок экрана («Маршруты», «Водители»).
  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.05,
  );

  /// Заголовок детального экрана (в аппбаре).
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  /// Капс-подпись над заголовком («СЕГОДНЯ · 05.07.26»).
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  /// Подпись-капс внутри карточек («КОЛИЧЕСТВО КАПСУЛ»).
  static const TextStyle fieldLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  /// Заголовок карточки (название заказчика/маршрута).
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle secondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// Крупное число (статы, сумма к оплате).
  static const TextStyle statNumber = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle money = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  /// Текст статус-пилюли.
  static const TextStyle badge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );
}

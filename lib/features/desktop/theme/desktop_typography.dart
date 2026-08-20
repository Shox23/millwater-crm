import 'package:flutter/material.dart';

/// Типографика десктопа на основе Onest.
///
/// Отдельно от мобильной [AppTypography] намеренно: мобильная версия
/// согласована и остаётся на Inter, а размеры здесь всё равно другие —
/// на 1728px строка таблицы и пилюля статуса мельче, чем карточка в телефоне.
///
/// Цвет стили не задают: он приходит из токенов в месте применения.
abstract class DesktopTypography {
  /// Семейство объявлено в pubspec и лежит в сборке — см. `assets/fonts`.
  static const String fontFamily = 'Onest';

  // ---- Сайдбар ----
  /// Название приложения в логотипе.
  static const TextStyle brand = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w800,
  );

  /// Подпись под названием («Доставка воды»).
  static const TextStyle brandSub = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
  );

  /// Заголовок группы пунктов («РАБОТА»).
  static const TextStyle navGroup = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.3,
  );

  /// Пункт меню.
  static const TextStyle navItem = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
  );

  /// Активный пункт меню — тот же размер, но жирнее.
  static const TextStyle navItemActive = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
  );

  // ---- Хедер ----
  /// Заголовок раздела.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 21,
    fontWeight: FontWeight.w800,
    height: 1.1,
  );

  /// Подзаголовок под ним («Сегодня · 18.08 · 5 в работе»).
  static const TextStyle sectionSub = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
  );

  // ---- Карточки и числа ----
  /// Значение KPI-карточки.
  static const TextStyle kpiValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
  );

  /// Крупное значение в отчётах.
  static const TextStyle kpiValueLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w800,
  );

  /// Подпись под значением.
  static const TextStyle kpiLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
  );

  /// Число водителей на линии в сайдбаре.
  static const TextStyle bigNumber = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle secondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
  );

  // ---- Таблицы ----
  /// Шапка таблицы.
  static const TextStyle tableHeader = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  /// Основная ячейка (имя заказчика, водитель).
  static const TextStyle tableCell = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Второстепенная строка в ячейке (адрес, тип · телефон).
  static const TextStyle tableCellSub = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  // ---- Дата-табы ----
  /// День недели над датой.
  static const TextStyle dateTabWeekday = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );

  static const TextStyle dateTabDay = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle dateTabMeta = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  // ---- Мелочи ----
  /// Текст статус-пилюли.
  static const TextStyle badge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
  );

  /// Пилюля покрупнее — в шапке drawer и карточке водителя.
  static const TextStyle badgeLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  /// Инициалы в аватаре.
  static const TextStyle avatarInitials = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  /// Заголовок модалки.
  static const TextStyle modalTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w800,
  );

  /// Сумма в модалке завершения и в футере.
  static const TextStyle moneyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
  );
}

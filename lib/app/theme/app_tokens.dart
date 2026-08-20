import 'package:flutter/material.dart';

/// Единый набор дизайн-токенов — аналог CSS-переменных.
///
/// Живёт в [ThemeData.extensions], поэтому светлая и тёмная темы отличаются
/// только значениями токенов: компоненты не дублируются под тему и не знают
/// хексов. Доступ из виджета — `context.tokens`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.text,
    required this.text2,
    required this.text3,
    required this.primary,
    required this.primary2,
    required this.aqua,
    required this.success,
    required this.successBg,
    required this.danger,
    required this.dangerBg,
    required this.warn,
    required this.warnBg,
    required this.cardShadow,
    required this.isDark,
    required this.sidebar,
    required this.overlay,
    required this.primarySoft,
    required this.primaryLine,
    required this.hoverShadow,
    required this.drawerShadow,
    required this.modalShadow,
  });

  // Поверхности и текст
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color text;
  final Color text2;
  final Color text3;

  /// Фон боковой панели. Отличается от [surface] только в тёмной теме —
  /// на светлой сайдбар и карточки одинаково белые.
  final Color sidebar;

  /// Затемнение под drawer и модалками.
  final Color overlay;

  // Акценты
  final Color primary;

  /// Акцент, затемнённый на 18% — для градиентов и нажатых состояний.
  final Color primary2;

  /// Акцент под текстом и иконками: подложка активного пункта, плиток, чипов.
  final Color primarySoft;

  /// Акцент для теней и обводок акцентных элементов.
  final Color primaryLine;

  /// Вторичный «водный» акцент: вода, капсулы.
  final Color aqua;

  // Статусные пары «цвет + подложка»
  final Color success;
  final Color successBg;
  final Color danger;
  final Color dangerBg;
  final Color warn;
  final Color warnBg;

  final List<BoxShadow> cardShadow;

  /// Подъём карточки под курсором. Мышь есть только на десктопе, поэтому
  /// на мобильных экранах тень не используется.
  final List<BoxShadow> hoverShadow;

  final List<BoxShadow> drawerShadow;
  final List<BoxShadow> modalShadow;

  final bool isDark;

  /// Мягкая подложка под цвет статуса (10–15% прозрачности).
  Color softOf(Color color) => color.withValues(alpha: isDark ? 0.18 : 0.12);

  /// Тень акцентной кнопки: 0 12px 26px -10px rgba(primary, .55).
  List<BoxShadow> get accentShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.55),
          blurRadius: 26,
          spreadRadius: -10,
          offset: const Offset(0, 12),
        ),
      ];

  static const light = AppTokens(
    bg: Color(0xFFEEF4FB),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF4F9FD),
    surface3: Color(0xFFEAF2FB),
    border: Color(0xFFE4EDF6),
    text: Color(0xFF0F2A43),
    text2: Color(0xFF5C7389),
    text3: Color(0xFF93A6BA),
    primary: Color(0xFF2A6FDB),
    primary2: Color(0xFF225BB4),
    aqua: Color(0xFF0E96B6),
    success: Color(0xFF188A5E),
    successBg: Color(0x1C188A5E),
    danger: Color(0xFFD93A3F),
    dangerBg: Color(0x1AD93A3F),
    warn: Color(0xFFC4761C),
    warnBg: Color(0x1FC4761C),
    cardShadow: [
      BoxShadow(
        color: Color(0x141F446E),
        blurRadius: 10,
        offset: Offset(0, 2),
      ),
    ],
    isDark: false,
    // На светлой теме сайдбар и карточки одинаково белые.
    sidebar: Color(0xFFFFFFFF),
    overlay: Color(0x590F2A43),
    primarySoft: Color(0x1A2A6FDB),
    primaryLine: Color(0x662A6FDB),
    hoverShadow: [
      BoxShadow(
        color: Color(0x241F446E),
        blurRadius: 40,
        offset: Offset(0, 16),
      ),
    ],
    drawerShadow: [
      BoxShadow(
        color: Color(0x4D0F2A43),
        blurRadius: 60,
        spreadRadius: -20,
        offset: Offset(-24, 0),
      ),
    ],
    modalShadow: [
      BoxShadow(
        color: Color(0x800F2A43),
        blurRadius: 90,
        spreadRadius: -30,
        offset: Offset(0, 40),
      ),
    ],
  );

  static const dark = AppTokens(
    bg: Color(0xFF0A1520),
    surface: Color(0xFF13212F),
    surface2: Color(0xFF182838),
    surface3: Color(0xFF1E3141),
    border: Color(0xFF263A4E),
    text: Color(0xFFEAF2FA),
    text2: Color(0xFF93A9BF),
    text3: Color(0xFF617689),
    primary: Color(0xFF2A6FDB),
    primary2: Color(0xFF225BB4),
    aqua: Color(0xFF0E96B6),
    success: Color(0xFF188A5E),
    successBg: Color(0x2E188A5E),
    danger: Color(0xFFD93A3F),
    dangerBg: Color(0x2BD93A3F),
    warn: Color(0xFFC4761C),
    warnBg: Color(0x30C4761C),
    cardShadow: [
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 40,
        offset: Offset(0, 18),
      ),
    ],
    isDark: true,
    sidebar: Color(0xFF0D1926),
    overlay: Color(0x9E04090E),
    primarySoft: Color(0x382A6FDB),
    primaryLine: Color(0x802A6FDB),
    // На тёмном фоне синеватая тень не читается — все три от чёрного.
    hoverShadow: [
      BoxShadow(
        color: Color(0x73000000),
        blurRadius: 40,
        offset: Offset(0, 16),
      ),
    ],
    drawerShadow: [
      BoxShadow(
        color: Color(0x99000000),
        blurRadius: 60,
        spreadRadius: -20,
        offset: Offset(-24, 0),
      ),
    ],
    modalShadow: [
      BoxShadow(
        color: Color(0xB3000000),
        blurRadius: 90,
        spreadRadius: -30,
        offset: Offset(0, 40),
      ),
    ],
  );

  /// Набор для десктопа: те же поверхности, но акценты тёмной темы ярче.
  ///
  /// Отдельный набор, а не правка [dark], потому что мобильная версия
  /// согласована и остаётся как есть. Подключается только под десктопной
  /// оболочкой — см. `DesktopTheme`.
  static final lightDesktop = light;

  /// На тёмном десктопе статусные цвета мобильной палитры глохнут: экран
  /// большой, а пилюли мелкие. Значения из десктопной спеки.
  static final darkDesktop = dark.copyWith(
    aqua: const Color(0xFF3DD0E6),
    success: const Color(0xFF43D08F),
    successBg: const Color(0x2643D08F),
    danger: const Color(0xFFFF787B),
    dangerBg: const Color(0x26FF787B),
    warn: const Color(0xFFF0A742),
    warnBg: const Color(0x29F0A742),
    // Карточек на экране десятки — тяжёлая мобильная тень их бы залила.
    cardShadow: const [
      BoxShadow(
        color: Color(0x59000000),
        blurRadius: 14,
        offset: Offset(0, 4),
      ),
    ],
  );

  @override
  AppTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? border,
    Color? text,
    Color? text2,
    Color? text3,
    Color? primary,
    Color? primary2,
    Color? aqua,
    Color? success,
    Color? successBg,
    Color? danger,
    Color? dangerBg,
    Color? warn,
    Color? warnBg,
    List<BoxShadow>? cardShadow,
    bool? isDark,
    Color? sidebar,
    Color? overlay,
    Color? primarySoft,
    Color? primaryLine,
    List<BoxShadow>? hoverShadow,
    List<BoxShadow>? drawerShadow,
    List<BoxShadow>? modalShadow,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border: border ?? this.border,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      primary: primary ?? this.primary,
      primary2: primary2 ?? this.primary2,
      aqua: aqua ?? this.aqua,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      warn: warn ?? this.warn,
      warnBg: warnBg ?? this.warnBg,
      cardShadow: cardShadow ?? this.cardShadow,
      isDark: isDark ?? this.isDark,
      sidebar: sidebar ?? this.sidebar,
      overlay: overlay ?? this.overlay,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryLine: primaryLine ?? this.primaryLine,
      hoverShadow: hoverShadow ?? this.hoverShadow,
      drawerShadow: drawerShadow ?? this.drawerShadow,
      modalShadow: modalShadow ?? this.modalShadow,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primary2: Color.lerp(primary2, other.primary2, t)!,
      aqua: Color.lerp(aqua, other.aqua, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnBg: Color.lerp(warnBg, other.warnBg, t)!,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primaryLine: Color.lerp(primaryLine, other.primaryLine, t)!,
      hoverShadow: BoxShadow.lerpList(hoverShadow, other.hoverShadow, t)!,
      drawerShadow: BoxShadow.lerpList(drawerShadow, other.drawerShadow, t)!,
      modalShadow: BoxShadow.lerpList(modalShadow, other.modalShadow, t)!,
    );
  }

  /// Палитра фонов для аватарок-инициалов.
  List<Color> get avatarPalette => [
        primary,
        aqua,
        const Color(0xFF6C5CE0),
        warn,
        success,
      ];
}

/// Короткий доступ к токенам: `context.tokens.primary`.
extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

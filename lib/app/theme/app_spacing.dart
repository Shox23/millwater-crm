/// Отступы и радиусы. Единая шкала на всё приложение.
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Горизонтальные поля экрана.
  static const double page = 20;

  /// Внутренний отступ карточки и его компактный вариант.
  static const double card = 16;
  static const double cardCompact = 13;
}

/// Радиусы скругления: базовый corner = 18.
abstract class AppRadius {
  /// corner * 0.5
  static const double sm = 9;

  /// corner * 0.75
  static const double md = 14;

  /// corner
  static const double lg = 18;

  /// corner * 1.35 — крупные поверхности десктопа: модалки, drawer.
  static const double xl = 24;

  static const double pill = 999;

  /// Радиус аватарки-инициалов (скруглённый квадрат, не круг).
  static const double avatar = 14;

  /// Радиус поля ввода.
  static const double input = 13;
}

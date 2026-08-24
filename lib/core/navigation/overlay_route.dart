import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Переход для экранов-оверлеев (детали, формы, успех).
///
/// На Android экран поднимается поверх табов одновременным fade + rise —
/// вместо модалки по центру и вместо стандартного горизонтального перехода.
///
/// На iOS переход отдаётся системному купертиновскому, и вместе с ним
/// приходит краевой жест «назад». Своей анимацией его не добавить: жест
/// живёт внутри [CupertinoRouteTransitionMixin.buildPageTransitions] и
/// вешается на child там же, где строится переход. Раньше маршрут был собран
/// на `PageRouteBuilder`, который переход берёт из переданного
/// `transitionsBuilder` и мимо этого места проходит, — поэтому свайп назад
/// не работал ни на одном экране.
///
/// Жест дополнительно требует, чтобы маршрут был готов закрыться:
/// `PopScope(canPop: false)` гасит его наглухо (см. `PageRoute
/// .popGestureEnabled`). Поэтому экраны, которым нужно подтверждение выхода,
/// ставят `canPop` по состоянию формы, а не константой.
class OverlayPageRoute<T> extends PageRoute<T> {
  OverlayPageRoute({required this.builder});

  final WidgetBuilder builder;

  /// Платформы, где переход и жест ведёт система.
  ///
  /// Берётся `defaultTargetPlatform`, а не `Theme.of(context).platform`:
  /// длительность перехода спрашивают без контекста, и разъехаться эти два
  /// источника не должны — иначе анимация пойдёт по одной платформе, а её
  /// длительность по другой.
  static bool get _systemTransition =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Duration get transitionDuration => _systemTransition
      ? const Duration(milliseconds: 300)
      : const Duration(milliseconds: 260);

  @override
  Duration get reverseTransitionDuration => _systemTransition
      ? const Duration(milliseconds: 300)
      : const Duration(milliseconds: 200);

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_systemTransition) {
      return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

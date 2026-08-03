import 'package:flutter/material.dart';

/// Переход для экранов-оверлеев (детали, формы, успех).
///
/// Экран поднимается поверх табов с одновременным fade + rise — вместо
/// модалки по центру и вместо стандартного горизонтального перехода.
class OverlayPageRoute<T> extends PageRouteBuilder<T> {
  OverlayPageRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          opaque: true,
          pageBuilder: (context, _, _) => builder(context),
          transitionsBuilder: (context, animation, _, child) {
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
          },
        );
}

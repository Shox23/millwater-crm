import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';

/// Высоты нижней шторки маршрута — один источник на всё.
///
/// От них считается и сама шторка, и нижний отступ списка заказчиков (иначе
/// последняя строка уезжает под шторку и до неё не дотянуться), и позиция
/// тоста. Три числа врозь однажды разъедутся, и разъедутся молча.
abstract class RouteCreateSheetMetrics {
  /// Свёрнутая: ручка, итоги и кнопка создания.
  static const double peek = 160;

  /// Развёрнутая, но не выше этого — на планшете шторка во весь экран
  /// перестаёт быть шторкой.
  static const double maxExpanded = 640;

  /// Доля экрана под развёрнутую шторку: список заказчиков должен остаться
  /// виден хотя бы полосой, иначе непонятно, куда возвращаться.
  static const double expandedFraction = 0.76;

  static double expanded(double viewHeight) =>
      math.min(maxExpanded, viewHeight * expandedFraction);

  /// Отступ снизу у списка заказчиков.
  static const double listBottomPadding = peek + AppSpacing.lg;
}

/// Нижняя шторка с собираемым маршрутом (телефонная раскладка).
///
/// Свёрнутая показывает итоги и кнопку создания, развёрнутая — список точек с
/// редактированием. Высоту задаёт снаружи [RouteCreateSheetMetrics], потому
/// что от неё зависит не только шторка.
class RouteCreateSheet extends StatelessWidget {
  const RouteCreateSheet({
    super.key,
    required this.expanded,
    required this.title,
    required this.summary,
    required this.onToggle,
    required this.submit,
    this.summaryWarn = false,
    this.onCollapse,
    this.stops,
  });

  final bool expanded;

  /// «3 точки в маршруте» или «Маршрут пуст».
  final String title;

  /// «18 капсул · 396 000 сум».
  final String summary;

  /// Капсул больше, чем везёт машина — итог подсвечен.
  final bool summaryWarn;

  final VoidCallback onToggle;
  final VoidCallback? onCollapse;

  /// Кнопка создания — её собирает страница: подпись и доступность зависят
  /// от состояния отправки.
  final Widget submit;

  /// Список точек. Показывается только в развёрнутой шторке.
  final Widget? stops;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        border: Border(top: BorderSide(color: t.border)),
        boxShadow: t.drawerShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.sm,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: t.border,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                    Row(
                      spacing: AppSpacing.md,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              Text(
                                title,
                                style: AppTypography.cardTitle
                                    .copyWith(color: t.text),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                summary,
                                style: AppTypography.secondary.copyWith(
                                  color: summaryWarn ? t.warn : t.text2,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(Icons.expand_less_rounded, color: t.text2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Список строится только в развёрнутой шторке: в свёрнутой ему
          // достались бы считанные пиксели, а точки в ней и не нужны.
          if (expanded && stops != null) Expanded(child: stops!),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                if (expanded && onCollapse != null)
                  _BackToListButton(onTap: onCollapse!),
                Expanded(child: submit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackToListButton extends StatelessWidget {
  const _BackToListButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface2,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            context.l10n.routeCreateBackToList,
            style: AppTypography.button.copyWith(color: t.text),
          ),
        ),
      ),
    );
  }
}

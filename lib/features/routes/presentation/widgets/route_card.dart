import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/initials_avatar.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/route_models.dart';

/// Тон пилюли по статусу доставки (остановки).
StatusTone deliveryTone(DeliveryStatus status) => switch (status) {
      DeliveryStatus.delivered || DeliveryStatus.paid => StatusTone.success,
      DeliveryStatus.onWay => StatusTone.progress,
      DeliveryStatus.pending => StatusTone.neutral,
      DeliveryStatus.failed => StatusTone.danger,
    };

/// Цвет-индикатор статуса доставки.
Color deliveryColor(BuildContext context, DeliveryStatus status) {
  final t = context.tokens;
  return switch (status) {
    DeliveryStatus.delivered || DeliveryStatus.paid => t.success,
    DeliveryStatus.onWay => t.primary,
    DeliveryStatus.pending => t.text3,
    DeliveryStatus.failed => t.danger,
  };
}

/// Тон пилюли по статусу маршрута.
StatusTone routeTone(RouteStatus status) => switch (status) {
      RouteStatus.completed => StatusTone.success,
      RouteStatus.inProgress => StatusTone.progress,
      RouteStatus.created => StatusTone.neutral,
      RouteStatus.cancelled => StatusTone.danger,
    };

/// Цвет-индикатор статуса маршрута.
Color routeColor(BuildContext context, RouteStatus status) {
  final t = context.tokens;
  return switch (status) {
    RouteStatus.completed => t.success,
    RouteStatus.inProgress => t.primary,
    RouteStatus.created => t.text3,
    RouteStatus.cancelled => t.danger,
  };
}

/// Карточка маршрута в списке: дата, водитель, прогресс по точкам.
class RouteCard extends StatelessWidget {
  const RouteCard({super.key, required this.route, this.onTap});

  final RouteListItem route;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = routeColor(context, route.status);
    final progress = route.totalCustomers == 0
        ? 0.0
        : route.completedCount / route.totalCustomers;
    final trimmed = route.driverFullName?.trim();
    final driverName = (trimmed == null || trimmed.isEmpty) ? null : trimmed;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Row(
            spacing: AppSpacing.sm,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  DateFormat('dd.MM.yyyy').format(route.date),
                  style: AppTypography.cardTitle.copyWith(color: t.text),
                ),
              ),
              StatusBadge(
                text: route.status.label(context.l10n),
                tone: routeTone(route.status),
              ),
            ],
          ),
          const Divider(),
          Row(
            spacing: AppSpacing.md,
            children: [
              // Водительские эндпоинты полей водителя не отдают: в своём
              // списке маршрутов вместо «кто везёт» показываем «сколько точек».
              if (driverName != null) InitialsAvatar(name: driverName, size: 36),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      driverName ?? context.l10n.routeStopsCount(route.totalCustomers),
                      style: AppTypography.bodyStrong.copyWith(color: t.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (driverName != null)
                      Text(context.l10n.routeStopsCount(route.totalCustomers),
                          style:
                              AppTypography.secondary.copyWith(color: t.text2)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 2,
                children: [
                  Text(
                    '${route.completedCount} / ${route.totalCustomers}',
                    style: AppTypography.money.copyWith(color: t.text),
                  ),
                  Text(context.l10n.routeDoneShort,
                      style: AppTypography.secondary.copyWith(color: t.text2)),
                ],
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: t.surface2,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
    );
  }
}

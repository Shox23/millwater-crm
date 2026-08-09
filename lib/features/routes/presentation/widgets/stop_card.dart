import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../data/models/route_models.dart';
import 'route_card.dart';

/// Карточка точки маршрута — общая для админской и водительской карточек.
///
/// Админ открывает её на просмотр, водитель — на завершение доставки,
/// поэтому действие задаётся снаружи.
class StopCard extends StatelessWidget {
  const StopCard({
    super.key,
    required this.stop,
    this.onTap,
    this.trailing,
  });

  final RouteStop stop;
  final VoidCallback? onTap;

  /// Дополнительный элемент в шапке (например, меню смены статуса).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Row(
            spacing: AppSpacing.sm,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: deliveryColor(context, stop.status),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(stop.customerName,
                    style: AppTypography.cardTitle.copyWith(color: t.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              StatusBadge(
                text: stop.status.label(context.l10n),
                tone: deliveryTone(stop.status),
              ),
              ?trailing,
            ],
          ),
          Row(
            spacing: 4,
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: t.text2),
              Expanded(
                child: Text(stop.customerAddress,
                    style: AppTypography.secondary.copyWith(color: t.text2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (stop.isCompleted) ...[
            const Divider(),
            Row(
              children: [
                Text(context.l10n.stopCapsules(stop.deliveredCapsules ?? 0),
                    style: AppTypography.secondary.copyWith(color: t.text2)),
                const Spacer(),
                if (stop.paymentPhoto != null) ...[
                  Icon(Icons.photo_outlined, size: 16, color: t.text2),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  MoneyFormatter.sum(context.l10n, stop.paymentAmount ?? 0),
                  style: AppTypography.money.copyWith(color: t.success),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

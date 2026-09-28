import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/cancel_reason.dart';
import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/labeled_card.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/network_photo_card.dart';
import '../../../core/widgets/phone_contact_row.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/route_models.dart';
import '../../orders/presentation/widgets/order_expectations.dart';
import 'widgets/route_card.dart';

/// Точка маршрута глазами администратора — только просмотр.
///
/// Завершать доставку админ не может: `/driver/routes/customers/{id}/complete`
/// доступен лишь водителю маршрута, сервер отвечает 403.
class StopDetailPage extends StatelessWidget {
  const StopDetailPage({super.key, required this.stop});

  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final completedAt = stop.completedAt;

    return DetailScaffold(
      title: context.l10n.stopTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: [
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Expanded(
                      child: Text(stop.customerName,
                          style:
                              AppTypography.cardTitle.copyWith(color: t.text)),
                    ),
                    StatusBadge(
                      text: stop.status.label(context.l10n),
                      tone: deliveryTone(stop.status),
                    ),
                  ],
                ),
                Row(
                  spacing: 4,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: t.text2),
                    Expanded(
                      child: Text(stop.customerAddress,
                          style:
                              AppTypography.secondary.copyWith(color: t.text2)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Комментарий — тот же, что видит водитель, и при любом статусе:
          // у закрытой точки он объясняет, почему доставка прошла так.
          if (stop.comment case final String comment)
            LabeledCard(
              label: context.l10n.orderCommentTitle,
              child: Text(comment,
                  style: AppTypography.body.copyWith(color: t.text)),
            ),
          // Задание к незакрытой точке — как на её карточке в списке.
          if (stop.status.isOpen &&
              OrderExpectations.hasAny(
                capsules: stop.bottleSellCount,
                amount: stop.customPrice,
              ))
            AppCard(
              child: OrderExpectations(
                capsules: stop.bottleSellCount,
                amount: stop.customPrice,
              ),
            ),
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: StatTile(
                  value: '${stop.deliveredCapsules ?? 0}',
                  label: context.l10n.stopCapsulesDelivered,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: MoneyFormatter.sum(context.l10n, stop.paymentAmount ?? 0),
                  label: context.l10n.stopPaid,
                ),
              ),
            ],
          ),
          if (completedAt != null)
            AppCard(
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  Icon(Icons.schedule_outlined, size: 20, color: t.text2),
                  Expanded(
                    child: Text(context.l10n.stopCompleted,
                        style:
                            AppTypography.secondary.copyWith(color: t.text2)),
                  ),
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(completedAt),
                    style: AppTypography.bodyStrong.copyWith(color: t.text),
                  ),
                ],
              ),
            ),
          if (stop.paymentPhoto case final String photo)
            NetworkPhotoCard(label: context.l10n.stopPhotoLabel, url: photo),
          // Отменённая точка объясняет себя сама: причина и время отмены.
          if (stop.isCancelled)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.sm,
                children: [
                  Row(
                    spacing: AppSpacing.md,
                    children: [
                      Icon(Icons.block_outlined, size: 20, color: t.danger),
                      Expanded(
                        child: Text(context.l10n.orderCancelledAt,
                            style: AppTypography.secondary
                                .copyWith(color: t.text2)),
                      ),
                      if (stop.cancelledAt case final DateTime at)
                        Text(
                          DateFormat('dd.MM.yyyy HH:mm').format(at),
                          style:
                              AppTypography.bodyStrong.copyWith(color: t.text),
                        ),
                    ],
                  ),
                  Text(
                    cancelReasonLabel(context.l10n, stop.cancelReason),
                    style: AppTypography.body.copyWith(color: t.text),
                  ),
                ],
              ),
            ),
          AppCard(child: PhoneContactRow(phone: stop.customerPhone)),
        ],
      ),
    );
  }
}

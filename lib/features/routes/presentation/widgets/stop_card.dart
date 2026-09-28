import 'package:flutter/material.dart';

import '../../../../core/utils/cancel_reason.dart';
import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/route_models.dart';
import '../../../orders/presentation/widgets/order_expectations.dart';
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

  /// Чем закончилась точка — одной строкой и по её цели.
  ///
  /// Раньше строка всегда собиралась из доставленных капсул, и закрытый вывоз
  /// показывался как «0 капсул»: вся работа водителя — забранные кулеры и
  /// капсулы — из карточки пропадала, а у опта пропадали проданные бутыли.
  String _summary(BuildContext context) {
    final l10n = context.l10n;

    // Нули не пишем: «0 кулеров» рядом с «3 капсулы» — шум, а не факт.
    List<String> nonZero(List<(int?, String Function(int))> parts) => [
          for (final (count, label) in parts)
            if ((count ?? 0) > 0) label(count!),
        ];

    final parts = switch (stop.purpose) {
      OrderPurpose.pickup => nonZero([
          (stop.pickedCoolers, l10n.coolersCount),
          (stop.pickedBottles, l10n.stopCapsules),
        ]),
      OrderPurpose.bulkWater => nonZero([
          (stop.bulk5lCount, (n) => l10n.stopBulkBottles(n, 5)),
          (stop.bulk10lCount, (n) => l10n.stopBulkBottles(n, 10)),
        ]),
      // У доставки ноль осмыслен: привезли ноль — это тоже результат.
      OrderPurpose.delivery19l => [
          l10n.stopCapsules(stop.deliveredCapsules ?? 0),
        ],
    };

    // Вывоз, закрытый одним браком, и опт без позиций остались бы с пустой
    // строкой — а точка закрыта, и молчать об этом нельзя.
    if (parts.isEmpty) return l10n.stopNothingTaken;
    return parts.join(' · ');
  }

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
          // Задание к точке: сколько капсул везти и договорная сумма.
          // Показываем, пока точка не закрыта, — после закрытия важнее
          // факт, а не план: он уже в итоге внизу.
          if (stop.status.isOpen &&
              OrderExpectations.hasAny(
                capsules: stop.bottleSellCount,
                amount: stop.customPrice,
              ))
            OrderExpectations(
              capsules: stop.bottleSellCount,
              amount: stop.customPrice,
            ),
          // Комментарий админа — прямо в карточке: водитель читает его до
          // того, как поедет, а админ видит, что написал. Показываем и у
          // закрытой точки: он объясняет, почему доставка прошла так.
          if (stop.comment case final String comment)
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: t.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                spacing: AppSpacing.sm,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      size: 16, color: t.primary),
                  Expanded(
                    child: Text(
                      comment,
                      style: AppTypography.secondary.copyWith(color: t.text),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // Причина отмены — прямо в списке: у водителя это напоминание,
          // почему сюда не едем, у админа — ответ без звонка.
          if (stop.isCancelled)
            Row(
              spacing: 4,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.block_outlined, size: 16, color: t.danger),
                Expanded(
                  child: Text(
                    cancelReasonLabel(context.l10n, stop.cancelReason),
                    style: AppTypography.secondary.copyWith(color: t.text2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          if (stop.isCompleted) ...[
            const Divider(),
            Row(
              children: [
                Text(_summary(context),
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/order.dart';
import 'order_expectations.dart';

/// Карточка заказа в списке: номер и дата, заказчик, цель, статус, деньги.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.onTap});

  final Order order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final date = order.routeDate ?? order.createdAt;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: Text(
                  l10n.orderNumber(order.number),
                  style: AppTypography.cardTitle.copyWith(color: t.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                DateFormat('dd.MM.yy').format(date),
                style: AppTypography.secondary.copyWith(color: t.text2),
              ),
            ],
          ),
          Text(
            order.customerName,
            style: AppTypography.bodyStrong.copyWith(color: t.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (order.customerAddress.isNotEmpty)
            Row(
              spacing: 4,
              children: [
                Icon(Icons.location_on_outlined, size: 15, color: t.text2),
                Expanded(
                  child: Text(
                    order.customerAddress,
                    style: AppTypography.secondary.copyWith(color: t.text2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          // Задание к незакрытому заказу — как на карточке точки маршрута:
          // сколько везти и за сколько. У закрытого его место занимает факт.
          if (order.status.isOpen &&
              OrderExpectations.hasAny(
                capsules: order.bottleSellCount,
                amount: order.customPrice,
              ))
            OrderExpectations(
              capsules: order.bottleSellCount,
              amount: order.customPrice,
            ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                text: order.status.label(l10n),
                tone: _statusTone(order.status),
                showDot: true,
              ),
              // Цель показываем всегда, включая обычную доставку: без неё
              // непонятно, почему у половины заказов нет капсул.
              StatusBadge(text: order.purpose.label(l10n)),
              if (order.paymentMethod != null)
                StatusBadge(
                  text: order.paymentMethod!.label(l10n),
                  // «В долг» — не нейтральный факт: деньги не приняты.
                  tone: order.isDebt ? StatusTone.warn : StatusTone.neutral,
                ),
              // Суммы у незакрытого заказа нет вовсе — ноль здесь читался бы
              // как «привезли бесплатно».
              if (order.orderAmount != null)
                Text(
                  MoneyFormatter.sum(l10n, order.orderAmount!),
                  style: AppTypography.money.copyWith(color: t.text),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static StatusTone _statusTone(DeliveryStatus status) => switch (status) {
        DeliveryStatus.delivered => StatusTone.success,
        DeliveryStatus.onWay => StatusTone.progress,
        DeliveryStatus.failed => StatusTone.danger,
        DeliveryStatus.cancelled => StatusTone.danger,
        DeliveryStatus.pending => StatusTone.neutral,
      };
}

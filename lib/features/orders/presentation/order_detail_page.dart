import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/phone_contact_row.dart';
import '../../../core/widgets/section_block.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/order.dart';
import 'move_order_page.dart';
import 'order_payment_page.dart';

/// Карточка заказа: состав, расчёт и маршрут, которым его везли.
///
/// [canManage] — админ: ему доступны перенос заказа и правка оплаты. У
/// водителя эти ручки под `/admin/*`, и кнопки ему показывать нечестно.
/// Каждая из них к тому же работает не всегда: перенести можно только
/// незакрытый заказ, править оплату — только закрытый. Сервер это проверяет
/// (409 `ORDER_ALREADY_COMPLETED` и `ORDER_NOT_COMPLETED`), но упираться в
/// отказ после заполнения формы — не дело, поэтому кнопки прячутся заранее.
class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({
    super.key,
    required this.order,
    this.canManage = false,
  });

  final Order order;
  final bool canManage;

  /// Перенести можно, пока заказ не закрыт: у закрытого сервер отвечает 409.
  bool get _canMove =>
      order.status == DeliveryStatus.pending ||
      order.status == DeliveryStatus.onWay;

  /// Править оплату — наоборот, только у закрытого.
  bool get _canEditPayment => order.status == DeliveryStatus.delivered;

  Future<void> _open(BuildContext context, Widget page, String message) async {
    final done = await Navigator.of(context)
        .push<bool>(OverlayPageRoute(builder: (_) => page));
    if (done != true || !context.mounted) return;
    // Обе ручки отвечают 204 без тела: достраивать заказ в памяти значит
    // однажды показать состояние, которого на сервере нет. Возвращаем
    // «изменилось» — список перечитает себя целиком.
    showAppSnackBar(context, message);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;

    return DetailScaffold(
      title: l10n.orderNumber(order.number),
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
                    StatusBadge(
                      text: order.status.label(l10n),
                      tone: switch (order.status) {
                        DeliveryStatus.delivered => StatusTone.success,
                        DeliveryStatus.onWay => StatusTone.progress,
                        DeliveryStatus.failed => StatusTone.danger,
                        DeliveryStatus.pending => StatusTone.neutral,
                      },
                      showDot: true,
                    ),
                    StatusBadge(text: order.purpose.label(l10n)),
                  ],
                ),
                Text(
                  order.customerName,
                  style: AppTypography.cardTitle.copyWith(color: t.text),
                ),
                if (order.customerAddress.isNotEmpty)
                  Row(
                    spacing: 4,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: t.text2),
                      Expanded(
                        child: Text(
                          order.customerAddress,
                          style:
                              AppTypography.secondary.copyWith(color: t.text2),
                        ),
                      ),
                    ],
                  ),
                if (order.customerPhone.isNotEmpty)
                  PhoneContactRow(phone: order.customerPhone),
              ],
            ),
          ),
          SectionBlock(
            label: l10n.orderSectionComposition,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.md,
                children: [
                  // Незаполненные показатели пропускаем, а не рисуем нулями:
                  // у заказа до релиза брака и возврата не было вовсе, и ноль
                  // выглядел бы как «привезли, но ничего не забрали».
                  _Row(
                    label: l10n.orderDelivered,
                    value: order.deliveredCapsules,
                  ),
                  _Row(
                    label: l10n.orderReturned,
                    value: order.returnedCapsules,
                  ),
                  _Row(
                    label: l10n.orderDamaged,
                    value: order.damagedCapsules,
                  ),
                  _Row(
                    label: l10n.orderBalanceAfter,
                    value: order.capsuleBalanceAfter,
                  ),
                ],
              ),
            ),
          ),
          SectionBlock(
            label: l10n.orderSectionMoney,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.md,
                children: [
                  // Снимок цены, а не сегодняшний прайс: заказ считали по
                  // той цене, которая действовала в день доставки.
                  _MoneyRow(
                    label: l10n.orderPriceApplied,
                    amount: order.waterPriceApplied,
                  ),
                  _MoneyRow(
                    label: l10n.orderFineApplied,
                    amount: order.damagedFineApplied,
                  ),
                  _MoneyRow(
                    label: l10n.orderAmount,
                    amount: order.orderAmount,
                    strong: true,
                  ),
                  if (order.paymentMethod != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.orderPaymentMethod,
                            style: AppTypography.secondary
                                .copyWith(color: t.text2),
                          ),
                        ),
                        StatusBadge(
                          text: order.paymentMethod!.label(l10n),
                          tone:
                              order.isDebt ? StatusTone.warn : StatusTone.neutral,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          SectionBlock(
            label: l10n.orderSectionRoute,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.md,
                children: [
                  _TextRow(
                    label: l10n.orderCreatedAt,
                    value: DateFormat('dd.MM.yyyy')
                        .format(order.routeDate ?? order.createdAt),
                  ),
                  _TextRow(
                    label: l10n.orderCompletedAt,
                    value: order.completedAt == null
                        ? l10n.orderNotCompleted
                        : DateFormat('dd.MM.yyyy HH:mm')
                            .format(order.completedAt!),
                  ),
                  if (order.driverFullName != null)
                    _TextRow(
                      label: l10n.routeDriver,
                      value: order.driverFullName!,
                    ),
                  // Маршрут без водителя — это не «данные не пришли», а
                  // рабочее состояние: сервер разрешает создавать такие.
                  if (order.hasNoDriver)
                    StatusBadge(
                      text: l10n.orderNoDriver,
                      tone: StatusTone.warn,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomBar: (canManage && (_canMove || _canEditPayment))
          ? BottomActionBar(
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  if (_canMove)
                    Expanded(
                      child: AppButton(
                        label: l10n.orderActionMove,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => _open(
                          context,
                          MoveOrderPage(order: order),
                          l10n.orderMoved,
                        ),
                      ),
                    ),
                  if (_canEditPayment)
                    Expanded(
                      child: AppButton(
                        label: l10n.orderActionPayment,
                        onPressed: () => _open(
                          context,
                          OrderPaymentPage(order: order),
                          l10n.orderPaymentSaved,
                        ),
                      ),
                    ),
                ],
              ),
            )
          : null,
    );
  }
}

/// Строка «подпись — количество»; `null` не показывается вовсе.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    return _TextRow(label: label, value: '$value');
  }
}

/// Строка «подпись — сумма»; `null` не показывается вовсе.
class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amount,
    this.strong = false,
  });

  final String label;
  final int? amount;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    if (amount == null) return const SizedBox.shrink();
    return _TextRow(
      label: label,
      value: MoneyFormatter.sum(context.l10n, amount!),
      strong: strong,
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      spacing: AppSpacing.md,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.secondary.copyWith(color: t.text2),
          ),
        ),
        Text(
          value,
          style: strong
              ? AppTypography.money.copyWith(color: t.text)
              : AppTypography.bodyStrong.copyWith(color: t.text),
        ),
      ],
    );
  }
}

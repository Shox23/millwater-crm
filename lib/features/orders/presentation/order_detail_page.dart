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

  /// Что показывать в составе: свои показатели цели плюс всё ненулевое.
  ///
  /// Возврат и брак есть у любой цели — их сервер заполняет и у вывоза;
  /// остаток капсул осмыслен там, где капсулы вообще двигались.
  List<(String, int?)> _composition(AppLocalizations l10n) {
    final own = switch (order.purpose) {
      OrderPurpose.delivery19l => [
          (l10n.orderDelivered, order.deliveredCapsules),
          (l10n.orderReturned, order.returnedCapsules),
          (l10n.orderDamaged, order.damagedCapsules),
          (l10n.orderBalanceAfter, order.capsuleBalanceAfter),
        ],
      OrderPurpose.pickup => [
          (l10n.orderPickedCoolers, order.pickedCoolers),
          (l10n.orderPickedBottles, order.pickedBottles),
          (l10n.orderDamaged, order.damagedCapsules),
        ],
      OrderPurpose.bulkWater => [
          (l10n.orderBulk5l, order.bulk5lCount),
          (l10n.orderBulk10l, order.bulk10lCount),
        ],
    };

    // Чужие показатели — только если в них что-то есть: заказ мог быть
    // закрыт до релиза, когда цели ещё не было и всё шло одной строкой.
    final ownLabels = {for (final (label, _) in own) label};
    final rest = <(String, int?)>[
      (l10n.orderDelivered, order.deliveredCapsules),
      (l10n.orderReturned, order.returnedCapsules),
      (l10n.orderDamaged, order.damagedCapsules),
      (l10n.orderPickedCoolers, order.pickedCoolers),
      (l10n.orderPickedBottles, order.pickedBottles),
      (l10n.orderBulk5l, order.bulk5lCount),
      (l10n.orderBulk10l, order.bulk10lCount),
      (l10n.orderBalanceAfter, order.capsuleBalanceAfter),
    ].where((e) => !ownLabels.contains(e.$1) && (e.$2 ?? 0) > 0);

    return [...own, ...rest];
  }

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
                  // Состав показываем по цели заказа, а не всеми полями
                  // подряд: сервер отдаёт нули и по тем показателям, которых
                  // у этой цели не бывает, и у вывоза внизу висели «Бутыли
                  // 5 л — 0» и «Бутыли 10 л — 0».
                  //
                  // Ноль у своего показателя при этом остаётся: «Доставлено 0»
                  // у доставки — это результат, а не отсутствие данных.
                  for (final (label, value) in _composition(l10n))
                    _Row(label: label, value: value),
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
                  // Опт считается по договорной цене, которую вводил
                  // водитель, — в снимок общей цены он не попадает.
                  if (order.bulkTotal > 0)
                    _MoneyRow(
                      label: l10n.orderBulkTotal,
                      amount: order.bulkTotal,
                    ),
                  _MoneyRow(
                    label: l10n.orderAmount,
                    amount: order.orderAmount,
                    strong: true,
                  ),
                  // Недоплата — это долг заказчика, и видеть его нужно
                  // здесь же: иначе разницу приходится считать в уме.
                  if (order.unpaid > 0)
                    _MoneyRow(
                      label: l10n.orderUnpaid,
                      amount: order.unpaid,
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
          // История, а не одна сумма: правка админа добавляет строку-дельту,
          // и без списка исчезал бы след того, кто и когда изменил деньги.
          // У заказов, закрытых до релиза, платежей нет вовсе — тогда блок
          // прямо об этом и говорит, а не притворяется пустым.
          if (order.isCompleted)
            SectionBlock(
              label: l10n.orderSectionPayments,
              child: order.payments.isEmpty
                  ? AppCard(
                      child: Text(l10n.orderPaymentsEmpty,
                          style: AppTypography.secondary
                              .copyWith(color: t.text2)),
                    )
                  : Column(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final payment in order.payments)
                          _PaymentRow(payment: payment),
                      ],
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

/// Строка истории платежей: когда, чем и сколько.
///
/// Отрицательная сумма — не ошибка, а корректировка админа: он уменьшил
/// итог заказа, и разница вернулась заказчику. Такую строку помечаем прямо,
/// иначе минус читается как опечатка.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final OrderPayment payment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final note = payment.note;

    return AppCard(
      compact: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            spacing: AppSpacing.sm,
            children: [
              Text(
                DateFormat('dd.MM.yyyy HH:mm').format(payment.createdAt),
                style: AppTypography.secondary.copyWith(color: t.text2),
              ),
              if (payment.method case final PaymentMethod method)
                StatusBadge(
                  text: method.label(l10n),
                  tone: StatusTone.neutral,
                ),
              if (payment.isRefund)
                StatusBadge(
                  text: l10n.orderPaymentRefund,
                  tone: StatusTone.warn,
                ),
              const Spacer(),
              Text(
                MoneyFormatter.sum(l10n, payment.amount),
                style: AppTypography.bodyStrong.copyWith(
                    color: payment.isRefund ? t.warn : t.success),
              ),
            ],
          ),
          if (note != null && note.trim().isNotEmpty)
            Text(note,
                style: AppTypography.secondary.copyWith(color: t.text2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

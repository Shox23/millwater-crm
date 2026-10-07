import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/cancel_reason.dart';
import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/uz_phone.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/driver.dart';
import '../../../data/models/enums.dart';
import '../bloc/day_deliveries_bloc.dart';
import '../theme/desktop_typography.dart';
import '../widgets/desktop_badge.dart';
import '../widgets/desktop_button.dart';
import 'desktop_overlays.dart';

/// Строка «подпись — значение» в теле панели.
class DrawerField extends StatelessWidget {
  const DrawerField({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: DesktopTypography.secondary.copyWith(color: t.text2)),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: DesktopTypography.bodyStrong
                  .copyWith(color: valueColor ?? t.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Панель доставки: что известно о точке и что с ней можно сделать.
class DeliveryDrawer extends StatelessWidget {
  const DeliveryDrawer({
    super.key,
    required this.row,
    required this.onEditRoute,
    required this.onCancelRoute,
    required this.onCancelOrder,
  });

  final DeliveryRow row;

  /// Отмена этой доставки с причиной. Кнопка есть только у незакрытой
  /// точки: закрытую сервер отменять отказывается (409).
  final VoidCallback onCancelOrder;

  /// Правка маршрута, которому принадлежит эта доставка.
  ///
  /// Саму доставку админ не закрывает — это делает водитель, — но маршрут
  /// вокруг неё он ведёт: дата, водитель, состав точек. На телефоне это
  /// отдельный экран маршрута, а на десктопе список плоский, из доставок, и
  /// другого входа в маршрут отсюда нет.
  final VoidCallback onEditRoute;

  /// Отмена маршрута целиком — та же, что у админа на телефоне: маршрут
  /// помечается отменённым и остаётся в истории вместе с доставками и
  /// оплатами.
  ///
  /// Безвозвратного удаления здесь нет намеренно. Оно стирало маршрут вместе
  /// с закрытыми доставками и принятыми деньгами, а кнопка в карточке одной
  /// доставки читалась как «убрать эту точку».
  final VoidCallback onCancelRoute;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final stop = row.stop;

    return DesktopDrawerPanel(
      title: stop.customerName,
      subtitle: l10n.desktopDeliveryTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DesktopBadge(
              text: stop.status.label(l10n),
              color: switch (stop.status) {
                DeliveryStatus.delivered => t.success,
                DeliveryStatus.onWay => t.primary,
                DeliveryStatus.failed => t.danger,
                DeliveryStatus.cancelled => t.danger,
                DeliveryStatus.pending => t.text2,
              },
              large: true,
              showDot: true,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DrawerField(
            label: l10n.desktopFieldAddress,
            value: stop.customerAddress,
          ),
          DrawerField(
            label: l10n.commonPhone,
            value: UzPhone.format(stop.customerPhone),
          ),
          DrawerField(
            label: l10n.driverTitle,
            value: row.route.driverFullName ?? '—',
          ),
          DrawerField(
            label: l10n.desktopFieldCapsules,
            value: stop.deliveredCapsules == null
                ? '—'
                : '${stop.deliveredCapsules}',
          ),
          DrawerField(
            label: l10n.desktopFieldSum,
            value: stop.paymentAmount == null || stop.paymentAmount == 0
                ? '—'
                : MoneyFormatter.sum(l10n, stop.paymentAmount!),
          ),
          // Комментарий к точке — тем же полем, что видит водитель.
          if (stop.comment case final String comment)
            DrawerField(label: l10n.orderCommentTitle, value: comment),
          // Задание к открытой точке — теми же словами, что и у водителя.
          // После закрытия договорная сумма остаётся справкой о сделке, а
          // капсулы уже видны фактом выше.
          if (stop.status.isOpen) ...[
            if ((stop.bottleSellCount ?? 0) > 0)
              DrawerField(
                label: stop.purpose == OrderPurpose.pickup
                    ? l10n.orderExpectedPickupCapsules
                    : l10n.orderExpectedCapsules,
                value: '${stop.bottleSellCount}',
              ),
            if (stop.customPrice case final int customPrice)
              DrawerField(
                label: l10n.orderExpectedAmount,
                value: MoneyFormatter.sum(l10n, customPrice),
              ),
          ] else if (stop.customPrice case final int customPrice)
            DrawerField(
              label: l10n.orderCustomPrice,
              value: MoneyFormatter.sum(l10n, customPrice),
            ),
          if (stop.completedAt != null)
            DrawerField(
              label: l10n.desktopFieldTime,
              value: DateFormat('dd.MM.yyyy · HH:mm').format(stop.completedAt!),
            ),
          // Отмена — с причиной, за которой оператор и открывает панель.
          if (stop.isCancelled) ...[
            if (stop.cancelledAt case final DateTime at)
              DrawerField(
                label: l10n.orderCancelledAt,
                value: DateFormat('dd.MM.yyyy · HH:mm').format(at),
              ),
            DrawerField(
              label: l10n.orderCancelReason,
              value: cancelReasonLabel(l10n, stop.cancelReason),
            ),
          ],
        ],
      ),
      footer: _DeliveryActions(
        row: row,
        onCancelOrder: onCancelOrder,
        onEditRoute: onEditRoute,
        onCancelRoute: onCancelRoute,
      ),
    );
  }
}

/// Действия под карточкой доставки.
class _DeliveryActions extends StatelessWidget {
  const _DeliveryActions({
    required this.row,
    required this.onEditRoute,
    required this.onCancelRoute,
    required this.onCancelOrder,
  });

  final DeliveryRow row;
  final VoidCallback onEditRoute;
  final VoidCallback onCancelRoute;
  final VoidCallback onCancelOrder;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: [
        // Завершение доставки — под админским токеном 403, это делает
        // водитель в своём приложении. Показываем только готовый результат;
        // ни «закончить», ни «отметить долг оплаченным» отсюда всё равно не
        // сделать, и держать под них неработающие кнопки незачем.
        if (row.stop.isCompleted && !row.isDebt)
          Row(
            spacing: AppSpacing.sm,
            children: [
              Icon(Icons.check_circle_rounded, size: 20, color: t.success),
              Text(
                l10n.desktopFinishedAndPaid,
                style: DesktopTypography.bodyStrong.copyWith(color: t.success),
              ),
            ],
          ),
        // Снять одну точку, а не весь маршрут: отмена с причиной, как у
        // админа на телефоне. Только пока точка открыта.
        if (row.stop.status.isOpen)
          DesktopButton(
            label: l10n.orderActionCancel,
            icon: Icons.block_outlined,
            variant: DesktopButtonVariant.soft,
            height: 46,
            expand: true,
            onPressed: onCancelOrder,
          ),
        // Завершённый и отменённый маршрут править нечего — как и на телефоне,
        // кнопки тогда нет вовсе.
        if (row.route.status.isEditable)
          DesktopButton(
            label: l10n.desktopEditRoute,
            icon: Icons.edit_outlined,
            variant: DesktopButtonVariant.soft,
            height: 46,
            expand: true,
            onPressed: onEditRoute,
          ),
        // Отмена маршрута — по тому же правилу, что на телефоне: завершённый
        // сервер отменять отказывается (409), у отменённого отменять нечего.
        // Подпись полная: рядом стоит «Отменить заказ», и короткое «Отменить»
        // не говорило бы, что снимается весь маршрут, а не эта точка.
        if (row.route.status.canCancel)
          DesktopButton(
            label: l10n.routeCancelAction,
            icon: Icons.cancel_outlined,
            variant: DesktopButtonVariant.danger,
            height: 46,
            expand: true,
            onPressed: onCancelRoute,
          ),
      ],
    );
  }
}

/// Панель водителя.
///
/// Работающему — правка и удаление. Неактивному (передан [onActivate]) —
/// только возврат в работу: править и удалять его сервер не даёт (404 и 409).
class DriverDrawer extends StatelessWidget {
  const DriverDrawer({
    super.key,
    required this.driver,
    this.onEdit,
    this.onDelete,
    this.onActivate,
  }) : assert(
          onActivate != null || (onEdit != null && onDelete != null),
          'работающему водителю нужны правка и удаление',
        );

  final Driver driver;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final inactive = onActivate != null;
    final onLine = !inactive && driver.todayTripCount > 0;

    return DesktopDrawerPanel(
      title: driver.fullName,
      subtitle: UzPhone.format(driver.phone),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: AppSpacing.lg,
            children: [
              InitialsAvatar(name: driver.fullName, size: 54, radius: 17),
              DesktopBadge(
                text: inactive
                    ? l10n.driverInactive
                    : onLine
                        ? l10n.desktopOnLine
                        : l10n.desktopFree,
                color: inactive
                    ? t.danger
                    : onLine
                        ? t.success
                        : t.text2,
                large: true,
                showDot: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          DrawerField(
            label: l10n.driverTripsTotal,
            value: '${driver.tripCount}',
          ),
          DrawerField(
            label: l10n.driverTripsToday,
            value: '${driver.todayTripCount}',
            valueColor: onLine ? t.primary : null,
          ),
          DrawerField(
            label: l10n.driverCreatedAt,
            value: DateFormat('dd.MM.yyyy').format(driver.createdAt),
          ),
        ],
      ),
      footer: inactive
          ? DesktopButton(
              label: l10n.driverActivate,
              icon: Icons.restore_rounded,
              height: 52,
              expand: true,
              onPressed: onActivate,
            )
          : _EntityActions(onEdit: onEdit!, onDelete: onDelete!),
    );
  }
}

/// Панель заказчика.
class CustomerDrawer extends StatelessWidget {
  const CustomerDrawer({
    super.key,
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return DesktopDrawerPanel(
      title: customer.name,
      subtitle: UzPhone.format(customer.phone),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DesktopBadge(
              text: customer.hasCooler
                  ? l10n.desktopWithCooler
                  : l10n.desktopWithoutCooler,
              color: customer.hasCooler ? t.aqua : t.text2,
              large: true,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DrawerField(
            label: l10n.desktopFieldAddress,
            value: customer.address,
          ),
          // Основной телефон — в подзаголовке панели, второй — полем: он
          // есть не у всех, и пустую строку показывать незачем.
          if (customer.phoneSecondary case final String phoneSecondary)
            DrawerField(
              label: l10n.customerFormPhoneSecondary,
              value: UzPhone.format(phoneSecondary),
            ),
          DrawerField(
            label: l10n.customerCapsulesBalance,
            value: '${customer.capsuleBalance}',
          ),
          if (customer.debt > 0)
            DrawerField(
              label: l10n.financeDebt,
              value: MoneyFormatter.sum(l10n, customer.debt),
              valueColor: t.danger,
            ),
          if (customer.prepayment > 0)
            DrawerField(
              label: l10n.financePrepayment,
              value: MoneyFormatter.sum(l10n, customer.prepayment),
              valueColor: t.success,
            ),
          if (customer.lastOrderDate != null)
            DrawerField(
              label: l10n.customerLastOrder,
              value: DateFormat('dd.MM.yyyy').format(customer.lastOrderDate!),
            ),
          if ((customer.comment ?? '').isNotEmpty)
            DrawerField(
              label: l10n.customerFormComment,
              value: customer.comment!,
            ),
        ],
      ),
      footer: _EntityActions(onEdit: onEdit, onDelete: onDelete),
    );
  }
}

/// Футер карточек справочников: удаление слева, правка во всю оставшуюся ширину.
class _EntityActions extends StatelessWidget {
  const _EntityActions({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Row(
      spacing: AppSpacing.md,
      children: [
        DesktopIconButton(
          icon: Icons.delete_outline_rounded,
          tooltip: context.l10n.commonDelete,
          size: 52,
          color: t.danger,
          onPressed: onDelete,
        ),
        Expanded(
          child: DesktopButton(
            label: context.l10n.commonEdit,
            height: 52,
            expand: true,
            onPressed: onEdit,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  const DeliveryDrawer({super.key, required this.row});

  final DeliveryRow row;

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
          if (stop.completedAt != null)
            DrawerField(
              label: l10n.desktopFieldTime,
              value: DateFormat('dd.MM.yyyy · HH:mm').format(stop.completedAt!),
            ),
        ],
      ),
      footer: _DeliveryActions(row: row),
    );
  }
}

/// Действия над доставкой.
///
/// Обе операции сервер админу не отдаёт: завершение доставки под админским
/// токеном — 403, а отдельной «оплаты долга» в API нет вовсе. Кнопки видны,
/// но заблокированы с объяснением: молча спрятать их значило бы, что оператор
/// будет искать их в другом месте.
class _DeliveryActions extends StatelessWidget {
  const _DeliveryActions({required this.row});

  final DeliveryRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    if (row.stop.isCompleted && !row.isDebt) {
      return Row(
        spacing: AppSpacing.sm,
        children: [
          Icon(Icons.check_circle_rounded, size: 20, color: t.success),
          Text(l10n.desktopFinishedAndPaid,
              style: DesktopTypography.bodyStrong.copyWith(color: t.success)),
        ],
      );
    }

    final debt = row.isDebt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        DesktopButton(
          label: debt ? l10n.desktopMarkDebtPaid : l10n.desktopFinishRoute,
          height: 46,
          expand: true,
          onPressed: null,
        ),
        Text(
          debt ? l10n.desktopDebtPaidHint : l10n.desktopDriverOnlyHint,
          style: DesktopTypography.caption.copyWith(color: t.text3),
        ),
      ],
    );
  }
}

/// Панель водителя.
class DriverDrawer extends StatelessWidget {
  const DriverDrawer({
    super.key,
    required this.driver,
    required this.onEdit,
    required this.onDelete,
  });

  final Driver driver;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final onLine = driver.todayTripCount > 0;

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
                text: onLine ? l10n.desktopOnLine : l10n.desktopFree,
                color: onLine ? t.success : t.text2,
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
      footer: _EntityActions(onEdit: onEdit, onDelete: onDelete),
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

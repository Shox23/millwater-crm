import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/widgets/initials_avatar.dart';
import '../../../../data/models/enums.dart';
import '../../bloc/day_deliveries_bloc.dart';
import '../../theme/desktop_typography.dart';
import '../../widgets/desktop_badge.dart';
import '../../widgets/desktop_cards.dart';
import '../../widgets/desktop_date_tabs.dart';
import '../../widgets/desktop_empty.dart';
import '../../widgets/desktop_table.dart';

/// Раздел «Маршруты»: лента дат, сводка дня и таблица доставок.
class RoutesDesktopPage extends StatelessWidget {
  const RoutesDesktopPage({super.key, required this.onRowTap});

  /// Открыть карточку доставки в drawer.
  final ValueChanged<DeliveryRow> onRowTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DayDeliveriesBloc, DayDeliveriesState>(
      builder: (context, state) {
        final bloc = context.read<DayDeliveriesBloc>();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.lg,
            children: [
              DesktopDateTabs(
                days: DayDeliveriesState.dateWindow(),
                selected: state.date,
                meta: state.dayMeta,
                onSelected: (day) => bloc.add(DayDeliveriesDateChanged(day)),
              ),
              _Summary(state: state),
              _Filters(state: state, bloc: bloc),
              _Table(state: state, onRowTap: onRowTap),
            ],
          ),
        );
      },
    );
  }
}

/// Сводка дня: акцентная карточка и три показателя.
class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final DayDeliveriesState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final future = state.isFuture;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.lg,
        children: [
          Expanded(
            flex: 135,
            child: DesktopSummaryCard(
              title: future
                  ? l10n.desktopSummaryPlanned
                  : l10n.desktopSummaryDone,
              value: future
                  ? l10n.routesCountPlural(state.routesCount)
                  : '${state.done} / ${state.total}',
              progress: state.progress,
              footnotes: [
                (l10n.desktopKpiCapsules, '${state.capsules}'),
                (l10n.desktopKpiDebt, MoneyFormatter.amount(state.debt)),
              ],
            ),
          ),
          // На будущий день денег ещё нет и быть не может: вместо выручки
          // и долга показываем то, что действительно известно из плана.
          if (future) ...[
            Expanded(
              flex: 100,
              child: DesktopKpiCard(
                icon: Icons.place_outlined,
                color: t.primary,
                value: '${state.total}',
                label: l10n.desktopKpiPlannedStops,
              ),
            ),
            Expanded(
              flex: 100,
              child: DesktopKpiCard(
                icon: Icons.local_shipping_outlined,
                color: t.aqua,
                value: '${state.driversInvolved}',
                label: l10n.desktopKpiPlannedDrivers,
              ),
            ),
            Expanded(
              flex: 90,
              child: DesktopKpiCard(
                icon: Icons.storefront_outlined,
                color: t.warn,
                value: '${state.customersInvolved}',
                label: l10n.desktopKpiPlannedCustomers,
              ),
            ),
          ] else ...[
            Expanded(
              flex: 100,
              child: DesktopKpiCard(
                icon: Icons.payments_outlined,
                color: t.success,
                value: MoneyFormatter.sum(l10n, state.collected),
                label: l10n.desktopKpiCollected,
              ),
            ),
            Expanded(
              flex: 100,
              child: DesktopKpiCard(
                icon: Icons.schedule_outlined,
                color: t.danger,
                value: MoneyFormatter.sum(l10n, state.debt),
                label: l10n.desktopKpiDebt,
                // Сервер хранит принятую сумму, но не ту, которую должны
                // были принять, — долг считается по цене капсулы.
                hint: l10n.desktopDebtEstimated,
              ),
            ),
            Expanded(
              flex: 90,
              child: DesktopKpiCard(
                icon: Icons.water_drop_outlined,
                color: t.aqua,
                value: '${state.capsules}',
                label: l10n.desktopKpiCapsules,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.bloc});

  final DayDeliveriesState state;
  final DayDeliveriesBloc bloc;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.sm,
      children: [
        for (final filter in DeliveryFilter.values)
          DesktopChip(
            label: filter.label(context.l10n),
            count: state.countFor(filter),
            selected: state.filter == filter,
            onTap: () => bloc.add(DayDeliveriesFilterChanged(filter)),
          ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.state, required this.onRowTap});

  final DayDeliveriesState state;
  final ValueChanged<DeliveryRow> onRowTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    if (state.status == DayDeliveriesStatus.loading && state.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status == DayDeliveriesStatus.error) {
      return DesktopEmpty(
        icon: Icons.cloud_off_outlined,
        title: l10n.routesLoadFailed,
      );
    }

    final rows = state.visible;

    return DesktopTable(
      columns: [
        DesktopColumn(l10n.desktopColCustomer, flex: 21),
        DesktopColumn(l10n.desktopColDriver, flex: 15),
        DesktopColumn(l10n.desktopColCapsules, flex: 7),
        DesktopColumn(l10n.desktopColSum, flex: 10),
        DesktopColumn(l10n.desktopColPayment, flex: 10),
        DesktopColumn(l10n.desktopColStatus, flex: 9),
        const DesktopColumn('', width: 44),
      ],
      itemCount: rows.length,
      onRowTap: (i) => onRowTap(rows[i]),
      empty: DesktopEmpty(
        icon: Icons.route_outlined,
        title: state.query.trim().isEmpty
            ? l10n.desktopDayEmpty
            : l10n.emptySearchTitle(state.query),
        hint: state.query.trim().isEmpty
            ? l10n.desktopDayEmptyHint
            : l10n.emptySearchHint,
      ),
      cellsBuilder: (i) {
        final row = rows[i];
        final stop = row.stop;

        return [
          _CustomerCell(row: row),
          Row(
            spacing: AppSpacing.sm,
            children: [
              InitialsAvatar(
                name: row.route.driverFullName ?? '—',
                size: 30,
                radius: 10,
              ),
              Expanded(
                child: Text(
                  row.route.driverFullName ?? '—',
                  style: DesktopTypography.tableCell.copyWith(color: t.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            stop.deliveredCapsules == null ? '—' : '${stop.deliveredCapsules}',
            style: DesktopTypography.tableCell.copyWith(color: t.text),
          ),
          Text(
            stop.paymentAmount == null || stop.paymentAmount == 0
                ? '—'
                : MoneyFormatter.amount(stop.paymentAmount!),
            style: DesktopTypography.tableCell.copyWith(color: t.text),
          ),
          _PaymentCell(row: row),
          Align(
            alignment: Alignment.centerLeft,
            child: DesktopBadge(
              text: stop.status.label(l10n),
              color: _statusColor(context, stop.status),
              showDot: true,
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: t.text3),
        ];
      },
    );
  }
}

Color _statusColor(BuildContext context, DeliveryStatus status) {
  final t = context.tokens;
  return switch (status) {
    DeliveryStatus.delivered => t.success,
    DeliveryStatus.onWay => t.primary,
    DeliveryStatus.failed => t.danger,
    DeliveryStatus.pending => t.text2,
  };
}

class _CustomerCell extends StatelessWidget {
  const _CustomerCell({required this.row});

  final DeliveryRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final district = row.district;
    final address = row.stop.customerAddress;

    return Row(
      spacing: AppSpacing.md,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _statusColor(context, row.stop.status),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              Text(
                row.stop.customerName,
                style: DesktopTypography.tableCell.copyWith(color: t.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                // Район в адресе стоит первым, поэтому второй раз его не
                // повторяем — показываем то, что после запятой.
                district == null
                    ? address
                    : '${address.substring(district.length + 1).trim()} · $district',
                style: DesktopTypography.tableCellSub.copyWith(color: t.text3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Колонка «Оплата».
///
/// Способа оплаты в ответе точки нет, поэтому различаем только два случая:
/// деньги приняты или доставка ушла в долг. Незакрытая точка — прочерк.
class _PaymentCell extends StatelessWidget {
  const _PaymentCell({required this.row});

  final DeliveryRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (!row.stop.isCompleted) {
      return Text(
        '—',
        style: DesktopTypography.tableCell.copyWith(color: t.text3),
      );
    }
    if (row.isDebt) {
      return Text(
        context.l10n.desktopDebtShort,
        style: DesktopTypography.tableCell.copyWith(color: t.danger),
      );
    }
    return Text(
      context.l10n.deliveryPaid,
      style: DesktopTypography.tableCell.copyWith(color: t.text),
    );
  }
}

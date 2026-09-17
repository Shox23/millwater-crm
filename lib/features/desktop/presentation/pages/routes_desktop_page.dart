import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/widgets/initials_avatar.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/route_models.dart';
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
              // Пока есть что ждать. Объеханный день блок не показывает:
              // нули под заголовком «Ожидается» читались бы как «ничего не
              // запланировано».
              if (!state.expected.isEmpty) _Expected(state: state),
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
              // На будущий день выданных капсул и долга нет и быть не
              // может — вместо нулей внизу то, что известно из плана.
              footnotes: future
                  ? [
                      (l10n.orderExpectedCapsules, '${state.expected.capsules}'),
                      (
                        l10n.orderExpectedAmount,
                        MoneyFormatter.amount(state.expected.amount),
                      ),
                    ]
                  : [
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
            // Касса дня: наличные минус расходы водителей. Числа серверные —
            // на стенде без этих полей карточка покажет ноль, а не мусор.
            Expanded(
              flex: 100,
              child: DesktopKpiCard(
                icon: Icons.account_balance_wallet_outlined,
                color: state.cashBalance < 0 ? t.danger : t.success,
                value: MoneyFormatter.sum(l10n, state.cashBalance),
                label: l10n.desktopKpiCashBalance,
                hint: l10n.cashBalanceHint,
              ),
            ),
            Expanded(
              flex: 90,
              child: DesktopKpiCard(
                icon: Icons.local_gas_station_outlined,
                color: t.warn,
                value: MoneyFormatter.sum(l10n, state.expensesTotal),
                label: l10n.desktopKpiExpenses,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Что ещё ожидается от дня: капсулы к доставке и деньги — по маршрутам.
///
/// Карточки маршрута на десктопе нет, таблица ниже плоская, из точек; эти
/// плашки и есть «карточка маршрута» оператора: водитель, точки и то, что
/// он должен привезти. При нескольких маршрутах впереди итог за день.
class _Expected extends StatelessWidget {
  const _Expected({required this.state});

  final DayDeliveriesState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final byRoute = state.expectedByRoute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Text(l10n.orderSectionExpected,
            style: DesktopTypography.kpiLabel.copyWith(color: t.text2)),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            if (byRoute.length > 1)
              _ExpectedCard(
                leading: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.softOf(t.primary),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.today_outlined, size: 16, color: t.primary),
                ),
                title: l10n.desktopExpectedWholeDay,
                subtitle: l10n.routesCountPlural(byRoute.length),
                expectations: state.expected,
              ),
            for (final (route, e) in byRoute)
              _ExpectedCard(
                leading: InitialsAvatar(
                  name: route.driverFullName ?? '—',
                  size: 30,
                  radius: 10,
                ),
                title: route.driverFullName ?? l10n.routeNoDriver,
                subtitle: l10n.routeStopsCount(route.totalCustomers),
                expectations: e,
              ),
          ],
        ),
      ],
    );
  }
}

class _ExpectedCard extends StatelessWidget {
  const _ExpectedCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.expectations,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final RouteExpectations expectations;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return SizedBox(
      width: 340,
      child: DesktopCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.md,
          children: [
            Row(
              spacing: AppSpacing.sm,
              children: [
                leading,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 1,
                    children: [
                      Text(title,
                          style: DesktopTypography.bodyStrong
                              .copyWith(color: t.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(subtitle,
                          style: DesktopTypography.caption
                              .copyWith(color: t.text3)),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              spacing: AppSpacing.md,
              children: [
                Expanded(
                  child: _ExpectedStat(
                    icon: Icons.water_drop_outlined,
                    label: l10n.orderExpectedCapsules,
                    value: '${expectations.capsules}',
                  ),
                ),
                Expanded(
                  child: _ExpectedStat(
                    icon: Icons.sell_outlined,
                    label: l10n.orderExpectedAmount,
                    value: MoneyFormatter.sum(l10n, expectations.amount),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpectedStat extends StatelessWidget {
  const _ExpectedStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(label,
            style: DesktopTypography.caption.copyWith(color: t.text3)),
        Row(
          spacing: 4,
          children: [
            Icon(icon, size: 16, color: t.primary),
            Expanded(
              child: Text(value,
                  style: DesktopTypography.bodyStrong.copyWith(color: t.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ],
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
        DesktopColumn(l10n.desktopColCustomer, flex: 19),
        DesktopColumn(l10n.desktopColDriver, flex: 13),
        DesktopColumn(l10n.desktopColPurpose, flex: 10),
        DesktopColumn(l10n.desktopColCapsules, flex: 6),
        DesktopColumn(l10n.desktopColDamaged, flex: 6),
        DesktopColumn(l10n.desktopColSum, flex: 9),
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
          // Цель заказа: маршрут бывает смешанным, и без неё «0 капсул» у
          // вывоза читается как невыполненная доставка.
          Align(
            alignment: Alignment.centerLeft,
            child: DesktopBadge(
              text: stop.purpose.shortLabel(l10n),
              color: t.text2,
            ),
          ),
          Text(
            stop.deliveredCapsules == null ? '—' : '${stop.deliveredCapsules}',
            style: DesktopTypography.tableCell.copyWith(color: t.text),
          ),
          // Брак: за него заказчику начисляют штраф, и в разборе дня он
          // нужен рядом с капсулами, а не в карточке точки.
          Text(
            (stop.damagedCapsules ?? 0) == 0 ? '—' : '${stop.damagedCapsules}',
            style: DesktopTypography.tableCell.copyWith(
                color: (stop.damagedCapsules ?? 0) > 0 ? t.danger : t.text3),
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
    DeliveryStatus.cancelled => t.danger,
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
    // Способ приходит с сервера — называем его прямо. Прежнее «Оплачено»
    // одинаково подписывало наличные, карту и перевод, а это разные деньги:
    // наличные водитель везёт в кассе, остальное уходит на счёт компании.
    final method = row.stop.paymentMethod;
    return Text(
      method?.label(context.l10n) ?? context.l10n.deliveryPaid,
      style: DesktopTypography.tableCell.copyWith(color: t.text),
    );
  }
}

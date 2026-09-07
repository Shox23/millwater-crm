import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/utils/stats_period.dart';
import '../../../../core/widgets/load_more_notifier.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/order.dart';
import '../../../orders/bloc/orders_bloc.dart';
import '../../theme/desktop_typography.dart';
import '../../widgets/desktop_badge.dart';
import '../../widgets/desktop_empty.dart';
import '../../widgets/desktop_table.dart';

/// Раздел «Заказы»: все заказы за всё время таблицей.
///
/// На телефоне это лента карточек, здесь — таблица: десктоп у админа рабочий
/// экран, и разбирать день ему приходится строками, а не пролистыванием.
/// Блок общий с мобильным списком — фильтры, поиск и пагинация те же.
class OrdersDesktopPage extends StatelessWidget {
  const OrdersDesktopPage({super.key, required this.onOpen});

  final ValueChanged<Order> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return BlocBuilder<OrdersBloc, OrdersState>(
      builder: (context, state) {
        if (state.status == OrdersStatus.initial ||
            (state.status == OrdersStatus.loading && state.orders.isEmpty)) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == OrdersStatus.error) {
          return DesktopEmpty(
            icon: Icons.cloud_off_outlined,
            title: l10n.ordersLoadFailed,
          );
        }

        final orders = state.orders;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
              child: _Filters(state: state),
            ),
            Expanded(
              child: LoadMoreNotifier(
                onLoadMore: () => context
                    .read<OrdersBloc>()
                    .add(const OrdersNextPageRequested()),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 32),
                  child: DesktopTable(
                    columns: [
                      DesktopColumn(l10n.desktopColNumber, flex: 7),
                      DesktopColumn(l10n.desktopColCustomer, flex: 20),
                      DesktopColumn(l10n.desktopColDriver, flex: 13),
                      DesktopColumn(l10n.desktopColPurpose, flex: 10),
                      DesktopColumn(l10n.desktopColCapsules, flex: 6),
                      DesktopColumn(l10n.desktopColDamaged, flex: 6),
                      DesktopColumn(l10n.desktopColSum, flex: 10),
                      DesktopColumn(l10n.desktopColPayment, flex: 9),
                      DesktopColumn(l10n.desktopColStatus, flex: 9),
                      const DesktopColumn('', width: 44),
                    ],
                    itemCount: orders.length,
                    onRowTap: (i) => onOpen(orders[i]),
                    empty: DesktopEmpty(
                      icon: Icons.receipt_long_outlined,
                      title: state.isEmptySearch
                          ? l10n.emptySearchTitle(state.query)
                          : l10n.ordersEmpty,
                      hint: state.isEmptySearch
                          ? l10n.emptySearchHint
                          : l10n.ordersTileHint,
                    ),
                    cellsBuilder: (i) {
                      final order = orders[i];

                      return [
                        Text('№${order.number}',
                            style: DesktopTypography.tableCell
                                .copyWith(color: t.text2)),
                        _CustomerCell(order: order),
                        Text(
                          order.driverFullName ?? l10n.routeNoDriver,
                          style: DesktopTypography.tableCell.copyWith(
                              color: order.hasNoDriver ? t.warn : t.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: DesktopBadge(
                            text: order.purpose.shortLabel(l10n),
                            color: t.text2,
                          ),
                        ),
                        Text(
                          '${order.deliveredCapsules ?? 0}',
                          style: DesktopTypography.tableCell
                              .copyWith(color: t.text),
                        ),
                        Text(
                          (order.damagedCapsules ?? 0) == 0
                              ? '—'
                              : '${order.damagedCapsules}',
                          style: DesktopTypography.tableCell.copyWith(
                              color: (order.damagedCapsules ?? 0) > 0
                                  ? t.danger
                                  : t.text3),
                        ),
                        Text(
                          MoneyFormatter.amount(order.orderAmount ?? 0),
                          style: DesktopTypography.tableCell
                              .copyWith(color: t.text),
                        ),
                        Text(
                          order.paymentMethod?.label(l10n) ?? '—',
                          style: DesktopTypography.tableCell.copyWith(
                              color: order.isDebt ? t.danger : t.text2),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: DesktopBadge(
                            text: order.status.label(l10n),
                            color: _statusColor(context, order.status),
                            showDot: true,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 20, color: t.text3),
                      ];
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Color _statusColor(BuildContext context, DeliveryStatus status) {
    final t = context.tokens;
    return switch (status) {
      DeliveryStatus.delivered => t.success,
      DeliveryStatus.failed => t.danger,
      DeliveryStatus.onWay => t.primary,
      DeliveryStatus.pending => t.text3,
    };
  }
}

/// Фильтры статуса и цели — те же, что чипы на телефоне.
class _Filters extends StatelessWidget {
  const _Filters({required this.state});

  final OrdersState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<OrdersBloc>();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _Chip(
          label: l10n.filterAll,
          selected: state.statusFilter == null,
          onTap: () => bloc.add(const OrdersStatusChanged(null)),
        ),
        for (final status in DeliveryStatus.values)
          _Chip(
            label: status.label(l10n),
            selected: state.statusFilter == status,
            onTap: () => bloc.add(OrdersStatusChanged(status)),
          ),
        const SizedBox(width: AppSpacing.lg),
        for (final purpose in OrderPurpose.values)
          _Chip(
            label: purpose.label(l10n),
            selected: state.purposeFilter == purpose,
            // Повторный тап по выбранной цели снимает отбор: отдельного
            // «Все» для целей нет, их всего три и ряд был бы длиннее пользы.
            onTap: () => bloc.add(OrdersPurposeChanged(
                state.purposeFilter == purpose ? null : purpose)),
          ),
        const SizedBox(width: AppSpacing.lg),
        // Отбор по дате — тот же, что на телефоне: «Все», три готовых
        // периода и диапазон из календаря.
        _Chip(
          label: l10n.filterAll,
          selected: state.dateFilter is OrdersAnyDate,
          onTap: () => bloc.add(const OrdersDateChanged(OrdersAnyDate())),
        ),
        for (final period in StatsPeriod.values)
          _Chip(
            label: period.label(l10n),
            selected: state.dateFilter == OrdersPeriodDate(period),
            onTap: () => bloc.add(OrdersDateChanged(OrdersPeriodDate(period))),
          ),
        _DateRangeChip(state: state),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Material(
      color: selected ? t.primary : t.surface2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: DesktopTypography.tableCell
                .copyWith(color: selected ? Colors.white : t.text2),
          ),
        ),
      ),
    );
  }
}

class _CustomerCell extends StatelessWidget {
  const _CustomerCell({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 2,
      children: [
        Text(
          order.customerName,
          style: DesktopTypography.tableCell.copyWith(color: t.text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          order.routeDate == null
              ? order.customerAddress
              : '${DateFormat('dd.MM.yy').format(order.routeDate!)} · '
                  '${order.customerAddress}',
          style: DesktopTypography.tableCellSub.copyWith(color: t.text2),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Чип диапазона: открывает календарь и подписывается выбранными датами.
class _DateRangeChip extends StatelessWidget {
  const _DateRangeChip({required this.state});

  final OrdersState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<OrdersBloc>();
    final filter = state.dateFilter;
    final custom = filter is OrdersCustomDate ? filter : null;

    return _Chip(
      label: custom == null
          ? l10n.ordersDateRange
          : l10n.ordersDateRangeValue(
              custom.labelParts.$1,
              custom.labelParts.$2,
            ),
      selected: custom != null,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 3),
          lastDate: DateTime(now.year, now.month, now.day),
          initialDateRange: custom == null
              ? null
              : DateTimeRange(start: custom.from, end: custom.to),
        );
        if (picked == null) return;
        bloc.add(OrdersDateChanged(OrdersCustomDate.of(picked)));
      },
    );
  }
}

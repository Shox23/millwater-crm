import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/utils/stats_period.dart';
import '../../../../data/models/enums.dart';
import '../../../drivers/bloc/drivers_bloc.dart';
import '../../bloc/expenses_bloc.dart';
import '../../theme/desktop_typography.dart';
import '../../widgets/desktop_badge.dart';
import '../../widgets/desktop_empty.dart';
import '../../widgets/desktop_cards.dart';
import '../../widgets/desktop_table.dart';

/// Раздел «Касса»: расходы водителей за период.
///
/// Мобильному водителю видны только его собственные расходы по текущему
/// маршруту; сводить их по всем и за месяц приходится админу, и делает он
/// это за компьютером — поэтому экран только десктопный.
class CashDesktopPage extends StatelessWidget {
  const CashDesktopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<ExpensesBloc, ExpensesState>(
      builder: (context, state) {
        if (state.status == ExpensesStatus.initial ||
            (state.status == ExpensesStatus.loading &&
                state.expenses.isEmpty)) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == ExpensesStatus.error) {
          return DesktopEmpty(
            icon: Icons.cloud_off_outlined,
            title: l10n.cashDesktopFailed,
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.lg,
            children: [
              _Summary(state: state),
              _Filters(state: state),
              _Table(state: state),
            ],
          ),
        );
      },
    );
  }
}

/// Итог за период и разбивка по категориям.
class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final ExpensesState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final byCategory = state.byCategory;

    // IntrinsicHeight: подписи категорий разной длины и переносятся на две
    // строки — без него карточки в ряду получаются разной высоты. Просто
    // `stretch` здесь нельзя: ряд лежит в прокрутке, и высота не ограничена.
    return IntrinsicHeight(
      child: Row(
        spacing: AppSpacing.md,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 120,
            child: DesktopKpiCard(
              icon: Icons.account_balance_wallet_outlined,
              color: t.danger,
              value: MoneyFormatter.sum(l10n, state.total),
              label: l10n.cashDesktopTotal,
            ),
          ),
          // Категории — те же четыре, что видит водитель в форме расхода.
          // Пустую не прячем: ноль по «Ремонту» — это тоже ответ на вопрос
          // «на что ушли деньги».
          for (final category in ExpenseCategory.values)
            Expanded(
              flex: 90,
              child: DesktopKpiCard(
                icon: _icon(category),
                color: t.text2,
                value: MoneyFormatter.compactSum(
                  l10n,
                  byCategory[category] ?? 0,
                ),
                label: category.label(l10n),
              ),
            ),
        ],
      ),
    );
  }

  static IconData _icon(ExpenseCategory category) => switch (category) {
    ExpenseCategory.fuel => Icons.local_gas_station_outlined,
    ExpenseCategory.lunch => Icons.restaurant_outlined,
    ExpenseCategory.repair => Icons.build_outlined,
    ExpenseCategory.other => Icons.more_horiz_outlined,
  };
}

class _Filters extends StatelessWidget {
  const _Filters({required this.state});

  final ExpensesState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<ExpensesBloc>();
    final drivers = context.watch<DriversBloc>().state.drivers;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final period in StatsPeriod.values)
          _Chip(
            label: period.label(l10n),
            selected: state.period == period,
            onTap: () => bloc.add(ExpensesPeriodChanged(period)),
          ),
        const SizedBox(width: AppSpacing.lg),
        _Chip(
          label: l10n.filterAll,
          selected: state.category == null,
          onTap: () => bloc.add(const ExpensesCategoryChanged(null)),
        ),
        for (final category in ExpenseCategory.values)
          _Chip(
            label: category.label(l10n),
            selected: state.category == category,
            onTap: () => bloc.add(ExpensesCategoryChanged(category)),
          ),
        const SizedBox(width: AppSpacing.lg),
        // Водителей может не быть загружено — тогда остаётся отбор по всем,
        // которым экран и так работает.
        if (drivers.isNotEmpty) ...[
          _Chip(
            label: l10n.reportExportAllDrivers,
            selected: state.driverId == null,
            onTap: () => bloc.add(const ExpensesDriverChanged(null)),
          ),
          for (final driver in drivers)
            _Chip(
              label: driver.fullName,
              selected: state.driverId == driver.id,
              onTap: () => bloc.add(ExpensesDriverChanged(driver.id)),
            ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: DesktopTypography.tableCell.copyWith(
              color: selected ? Colors.white : t.text2,
            ),
          ),
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.state});

  final ExpensesState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final drivers = context.watch<DriversBloc>().state.drivers;
    final expenses = state.expenses;

    String driverName(String id) =>
        drivers.where((d) => d.id == id).firstOrNull?.fullName ?? '—';

    return DesktopTable(
      columns: [
        DesktopColumn(l10n.desktopColDate, flex: 12),
        DesktopColumn(l10n.desktopColDriver, flex: 20),
        DesktopColumn(l10n.desktopColCategory, flex: 14),
        DesktopColumn(l10n.desktopColComment, flex: 30),
        DesktopColumn(l10n.desktopColSum, flex: 14),
      ],
      itemCount: expenses.length,
      empty: DesktopEmpty(
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.cashDesktopEmpty,
        hint: l10n.cashDesktopEmptyHint,
      ),
      cellsBuilder: (i) {
        final expense = expenses[i];

        return [
          Text(
            DateFormat('dd.MM.yy').format(expense.createdAt),
            style: DesktopTypography.tableCell.copyWith(color: t.text2),
          ),
          Text(
            driverName(expense.driverId),
            style: DesktopTypography.tableCell.copyWith(color: t.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: DesktopBadge(
              text: expense.category.label(l10n),
              color: t.text2,
            ),
          ),
          Text(
            expense.comment?.trim().isNotEmpty == true ? expense.comment! : '—',
            style: DesktopTypography.tableCellSub.copyWith(color: t.text2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            MoneyFormatter.amount(expense.amount),
            style: DesktopTypography.tableCell.copyWith(color: t.danger),
          ),
        ];
      },
    );
  }
}

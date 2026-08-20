import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/day.dart';
import '../../../../core/utils/initials.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../data/models/customer.dart';
import '../../../../data/models/reports_summary.dart';
import '../../../customers/bloc/customers_bloc.dart';
import '../../../reports/bloc/reports_bloc.dart';
import '../../bloc/week_revenue_bloc.dart';
import '../../theme/desktop_typography.dart';
import '../../widgets/desktop_cards.dart';
import '../../widgets/desktop_empty.dart';
import '../../widgets/desktop_segmented.dart';

/// Раздел «Отчёты»: показатели периода, график недели и финансовые списки.
class ReportsDesktopPage extends StatelessWidget {
  const ReportsDesktopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      builder: (context, state) {
        final summary = state.summary;

        if (state.status == ReportsStatus.error) {
          return DesktopEmpty(
            icon: Icons.cloud_off_outlined,
            title: context.l10n.reportsLoadFailed,
          );
        }
        if (summary == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.lg,
            children: [
              _PeriodSelector(period: state.period),
              _Kpis(summary: summary),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.lg,
                  children: [
                    const Expanded(flex: 16, child: _RevenueChart()),
                    Expanded(flex: 10, child: _Capsules(summary: summary)),
                  ],
                ),
              ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.lg,
                  children: [
                    Expanded(child: _Debtors(summary: summary)),
                    const Expanded(child: _Prepayments()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period});

  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: DesktopSegmented<ReportPeriod>(
            options: [
              for (final value in ReportPeriod.values)
                (value, value.label(context.l10n)),
            ],
            value: period,
            onChanged: (value) =>
                context.read<ReportsBloc>().add(ReportsPeriodChanged(value)),
          ),
        ),
      ],
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.lg,
        children: [
          Expanded(
            child: DesktopKpiCard(
              icon: Icons.payments_outlined,
              color: t.success,
              value: MoneyFormatter.compactSum(l10n, summary.revenue),
              label: l10n.reportsRevenue,
              large: true,
            ),
          ),
          Expanded(
            child: DesktopKpiCard(
              icon: Icons.local_shipping_outlined,
              color: t.primary,
              value: '${summary.deliveriesDone} / ${summary.deliveriesTotal}',
              label: l10n.reportsDeliveries,
              large: true,
            ),
          ),
          Expanded(
            child: DesktopKpiCard(
              icon: Icons.schedule_outlined,
              color: t.danger,
              value: MoneyFormatter.compactSum(l10n, summary.debtTotal),
              label: l10n.reportsDebts,
              large: true,
            ),
          ),
          Expanded(
            child: DesktopKpiCard(
              icon: Icons.water_drop_outlined,
              color: t.aqua,
              value: '${summary.capsulesActive}',
              label: l10n.reportsCapsules,
              large: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Столбики выручки за семь дней.
class _RevenueChart extends StatelessWidget {
  const _RevenueChart();

  static const _height = 230.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final today = dayOnly(DateTime.now());

    return BlocBuilder<WeekRevenueBloc, WeekRevenueState>(
      builder: (context, state) {
        return DesktopCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.lg,
            children: [
              Text(
                l10n.desktopChartTitle,
                style: DesktopTypography.cardTitle.copyWith(color: t.text),
              ),
              SizedBox(
                height: _height,
                child: state.status == WeekRevenueStatus.ready
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final bar in state.bars)
                            Expanded(
                              child: _Bar(
                                bar: bar,
                                max: state.maxRevenue,
                                isToday: bar.day == today,
                              ),
                            ),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.bar, required this.max, required this.isToday});

  final RevenueBar bar;
  final int max;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Полоса занимает высоту пропорционально максимуму недели; у пустого дня
    // оставляем видимый корешок, иначе столбик исчезает вместе с подписью.
    final ratio = max == 0 ? 0.0 : bar.revenue / max;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 6,
        children: [
          Text(
            bar.revenue == 0 ? '—' : MoneyFormatter.amount(bar.revenue),
            style: DesktopTypography.caption.copyWith(
              color: isToday ? t.primary : t.text3,
            ),
            maxLines: 1,
          ),
          Flexible(
            child: FractionallySizedBox(
              heightFactor: ratio.clamp(0.02, 1.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 52),
                decoration: BoxDecoration(
                  color: isToday ? t.primary : t.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ),
          Text(
            DateFormat.E(
              Localizations.localeOf(context).languageCode,
            ).format(bar.day).toUpperCase(),
            style: DesktopTypography.dateTabWeekday.copyWith(
              color: isToday ? t.primary : t.text3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Где сейчас находятся капсулы.
///
/// «Расход» из макета сводкой не отдаётся — сервер не считает выданные
/// капсулы за период. Показываем то, что действительно известно: сколько
/// капсул на руках и как они распределены между точками с кулером и без.
class _Capsules extends StatelessWidget {
  const _Capsules({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    final customers = context.watch<CustomersBloc>().state.customers;
    final withCooler = customers
        .where((c) => c.hasCooler)
        .fold<int>(0, (sum, c) => sum + c.capsuleBalance);
    final total = summary.capsulesActive;
    final share = total == 0 ? 0.0 : withCooler / total;

    return DesktopCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          Text(
            l10n.reportsCapsules,
            style: DesktopTypography.cardTitle.copyWith(color: t.text),
          ),
          Text(
            '$total',
            style: DesktopTypography.kpiValueLarge.copyWith(color: t.text),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: t.surface3),
                  FractionallySizedBox(
                    widthFactor: share.clamp(0, 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [t.aqua, t.primary]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(color: t.border, height: 1),
          _Segment(
            label: l10n.desktopCapsulesWithCooler,
            value: withCooler,
            total: total,
            color: t.aqua,
          ),
          _Segment(
            label: l10n.desktopCapsulesWithoutCooler,
            value: total - withCooler,
            total: total,
            color: t.primary,
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final percent = total == 0 ? 0 : (value / total * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Row(
          children: [
            Text(
              label,
              style: DesktopTypography.secondary.copyWith(color: t.text2),
            ),
            const Spacer(),
            Text(
              '$percent%',
              style: DesktopTypography.bodyStrong.copyWith(color: t.text),
            ),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : value / total,
            minHeight: 6,
            backgroundColor: t.surface3,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _Debtors extends StatelessWidget {
  const _Debtors({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return _FinanceList(
      title: context.l10n.reportsDebtors,
      total: summary.debtTotal,
      color: t.danger,
      emptyLabel: context.l10n.desktopNoDebtors,
      rows: [
        for (final debtor in summary.debtors)
          (debtor.name, debtor.district, debtor.amount),
      ],
    );
  }
}

class _Prepayments extends StatelessWidget {
  const _Prepayments();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Предоплаты сводка не отдаёт — собираем из справочника заказчиков, как
    // это уже делает `ReportsSummary.from` для должников.
    final paid =
        context
            .watch<CustomersBloc>()
            .state
            .customers
            .where((c) => c.prepayment > 0)
            .toList()
          ..sort((a, b) => b.prepayment.compareTo(a.prepayment));

    return _FinanceList(
      title: context.l10n.desktopPrepayments,
      total: paid.fold<int>(0, (sum, c) => sum + c.prepayment),
      color: t.success,
      emptyLabel: context.l10n.desktopNoPrepayments,
      rows: [
        for (final customer in paid)
          (customer.name, _district(customer), customer.prepayment),
      ],
    );
  }

  /// Тот же способ, что у должников: комментарий, иначе адрес.
  static String _district(Customer customer) =>
      (customer.comment ?? '').isNotEmpty
      ? customer.comment!
      : customer.address;
}

/// Список «кто и сколько» с итогом в шапке.
class _FinanceList extends StatelessWidget {
  const _FinanceList({
    required this.title,
    required this.total,
    required this.color,
    required this.emptyLabel,
    required this.rows,
  });

  final String title;
  final int total;
  final Color color;
  final String emptyLabel;

  /// Имя, район и сумма.
  final List<(String, String, int)> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return DesktopCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: [
          Row(
            children: [
              Text(
                title,
                style: DesktopTypography.cardTitle.copyWith(color: t.text),
              ),
              const Spacer(),
              Text(
                MoneyFormatter.sum(context.l10n, total),
                style: DesktopTypography.cardTitle.copyWith(color: color),
              ),
            ],
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                emptyLabel,
                textAlign: TextAlign.center,
                style: DesktopTypography.secondary.copyWith(color: t.text3),
              ),
            )
          else
            for (final (name, district, amount) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  spacing: AppSpacing.md,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.softOf(color),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        Initials.of(name),
                        style: DesktopTypography.avatarInitials.copyWith(
                          color: color,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 1,
                        children: [
                          Text(
                            name,
                            style: DesktopTypography.tableCell.copyWith(
                              color: t.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            district,
                            style: DesktopTypography.tableCellSub.copyWith(
                              color: t.text3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      MoneyFormatter.amount(amount),
                      style: DesktopTypography.bodyStrong.copyWith(
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

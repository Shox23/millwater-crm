import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/plurals.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/reports_summary.dart';
import '../../../data/repositories/crm_repository.dart';
import '../bloc/reports_bloc.dart';
import 'widgets/debtors_card.dart';
import 'widgets/stat_card.dart';
import 'widgets/weekly_bar_chart.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ReportsBloc(context.read<CrmRepository>())
            ..add(const ReportsRequested()),
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<ReportsBloc, ReportsState>(
          builder: (context, state) {
            final summary = state.summary;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.lg,
                    AppSpacing.page,
                    AppSpacing.lg,
                  ),
                  child: ScreenHeader(
                    label: 'Аналитика',
                    title: 'Отчёты',
                    action: _PeriodSelector(
                      period: state.period,
                      onChanged: (p) => context.read<ReportsBloc>().add(
                        ReportsPeriodChanged(p),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  // Раньше проверялся только `summary == null`, и при ошибке
                  // экран навсегда оставался с крутящимся индикатором.
                  child: switch (state.status) {
                    ReportsStatus.error => ErrorRetryView(
                      onRetry: () => context.read<ReportsBloc>().add(
                        const ReportsRequested(),
                      ),
                      message: 'Не удалось загрузить отчёты',
                    ),
                    _ when summary == null => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    _ => _ReportsBody(summary: summary),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportsBody extends StatelessWidget {
  const _ReportsBody({required this.summary});
  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final deliveryPct = summary.deliveriesTotal == 0
        ? 0
        : (summary.deliveriesDone / summary.deliveriesTotal * 100).round();

    return RefreshIndicator(
      onRefresh: () {
        final bloc = context.read<ReportsBloc>();
        bloc.add(const ReportsRequested());
        return bloc.stream.firstWhere((s) => s.status != ReportsStatus.loading);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        children: [
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.payments_outlined,
                  iconColor: t.primary,
                  // Динамики к прошлому периоду в API нет — показываем при наличии.
                  aux: summary.revenueChangePct == 0
                      ? null
                      : '+${summary.revenueChangePct}%',
                  auxColor: t.success,
                  value: MoneyFormatter.sum(summary.revenueToday),
                  label: 'Выручка',
                ),
              ),
              Expanded(
                child: StatCard(
                  icon: Icons.local_shipping_outlined,
                  iconColor: t.success,
                  aux: '$deliveryPct%',
                  value:
                      '${summary.deliveriesDone} / ${summary.deliveriesTotal}',
                  label: 'Доставки',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: t.danger,
                  aux: Plurals.clients(summary.debtorsCount),
                  auxColor: t.danger,
                  value: MoneyFormatter.sum(summary.debtTotal),
                  label: 'Долги',
                ),
              ),
              Expanded(
                child: StatCard(
                  icon: Icons.water_drop_outlined,
                  iconColor: t.aqua,
                  aux: summary.capsulesTotal == summary.capsulesActive
                      ? null
                      : 'из ${summary.capsulesTotal}',
                  value: '${summary.capsulesActive} шт',
                  label: 'Капсулы у клиентов',
                ),
              ),
            ],
          ),
          // Недельного разреза в API нет — график показываем, только если есть данные.
          if (summary.weekly.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            WeeklyBarChart(
              bars: summary.weekly,
              total: summary.weeklyTotal,
              changePct: summary.weeklyChangePct,
            ),
          ],
          if (summary.debtors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            DebtorsCard(total: summary.debtTotal, debtors: summary.debtors),
          ],
        ],
      ),
    );
  }
}

/// Пилюля-селектор периода в шапке отчётов.
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});

  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopupMenuButton<ReportPeriod>(
      onSelected: onChanged,
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      itemBuilder: (context) => [
        for (final p in ReportPeriod.values)
          PopupMenuItem(
            value: p,
            child: Text(p.label, style: TextStyle(color: t.text)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: t.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Text(
              period.label,
              style: AppTypography.bodyStrong.copyWith(color: t.text),
            ),
            Icon(Icons.keyboard_arrow_down, size: 20, color: t.text2),
          ],
        ),
      ),
    );
  }
}

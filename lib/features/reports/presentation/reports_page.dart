import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/notifications_scope.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/export/file_sharer.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/reports_summary.dart';
import '../../../data/repositories/crm_repository.dart';
import '../bloc/reports_bloc.dart';
import 'widgets/debtors_card.dart';
import 'widgets/stat_card.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, this.fileSharer = const PlatformFileSharer()});

  /// Куда уходит выгруженный Excel. В тестах подменяется: и файловая система,
  /// и лист «Поделиться» — платформенные каналы.
  final FileSharer fileSharer;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportsBloc(
        context.read<CrmRepository>(),
        notifications: context.notificationEvents,
      )..add(const ReportsRequested()),
      child: _ReportsView(fileSharer: fileSharer),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView({required this.fileSharer});

  final FileSharer fileSharer;

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
                    label: context.l10n.reportsLabel,
                    title: context.l10n.reportsTitle,
                    action: Row(
                      spacing: AppSpacing.sm,
                      children: [
                        _ExportButton(
                          period: state.period,
                          fileSharer: fileSharer,
                        ),
                        _PeriodSelector(
                          period: state.period,
                          onChanged: (p) => context.read<ReportsBloc>().add(
                            ReportsPeriodChanged(p),
                          ),
                        ),
                      ],
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
                      message: context.l10n.reportsLoadFailed,
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
                  value: MoneyFormatter.sum(context.l10n, summary.revenue),
                  label: context.l10n.reportsRevenue,
                ),
              ),
              Expanded(
                child: StatCard(
                  icon: Icons.local_shipping_outlined,
                  iconColor: t.success,
                  aux: '$deliveryPct%',
                  value:
                      '${summary.deliveriesDone} / ${summary.deliveriesTotal}',
                  label: context.l10n.reportsDeliveries,
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
                  aux: context.l10n.clientsCount(summary.debtorsCount),
                  auxColor: t.danger,
                  value: MoneyFormatter.sum(context.l10n, summary.debtTotal),
                  label: context.l10n.reportsDebts,
                ),
              ),
              Expanded(
                child: StatCard(
                  icon: Icons.water_drop_outlined,
                  iconColor: t.aqua,
                  value:
                      context.l10n.reportsCapsulesCount(summary.capsulesActive),
                  label: context.l10n.reportsCapsules,
                ),
              ),
            ],
          ),
          if (summary.debtors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            DebtorsCard(total: summary.debtTotal, debtors: summary.debtors),
          ],
        ],
      ),
    );
  }
}

/// Кнопка выгрузки отчёта в Excel.
///
/// Период берётся тот же, что показан на экране: границы считает
/// [ReportsBloc.rangeFor], одна на оба пути.
class _ExportButton extends StatefulWidget {
  const _ExportButton({required this.period, required this.fileSharer});

  final ReportPeriod period;
  final FileSharer fileSharer;

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    final repo = context.read<CrmRepository>();
    final l10n = context.l10n;
    final (from, to) = ReportsBloc.rangeFor(widget.period);

    try {
      final export = await repo.exportSummaryReport(dateFrom: from, dateTo: to);
      await widget.fileSharer.share(
        bytes: export.bytes,
        filename: export.filename,
        subject: l10n.reportsExportSubject,
      );
    } catch (_) {
      // Молча гасить нельзя: админ нажал кнопку и ждёт файл.
      if (mounted) showAppSnackBar(context, l10n.reportsExportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (_busy) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: _export,
      icon: Icon(Icons.file_download_outlined, color: t.text2),
      tooltip: context.l10n.reportsExport,
      visualDensity: VisualDensity.compact,
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
            child: Text(p.label(context.l10n), style: TextStyle(color: t.text)),
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
              period.label(context.l10n),
              style: AppTypography.bodyStrong.copyWith(color: t.text),
            ),
            Icon(Icons.keyboard_arrow_down, size: 20, color: t.text2),
          ],
        ),
      ),
    );
  }
}

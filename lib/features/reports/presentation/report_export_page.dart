import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/export/file_sharer.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/utils/stats_period.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/section_block.dart';
import '../../../core/widgets/segmented_toggle.dart';
import '../../../data/models/driver.dart';
import '../../../data/models/report_export.dart';
import '../../../data/repositories/crm_repository.dart';
import '../bloc/reports_bloc.dart';

/// Какой из трёх отчётов выгружаем.
///
/// Раньше выгрузка была одна и кнопка отправляла её сразу. Сервер заменил
/// `/admin/reports/export` тремя разрезами, и выбирать теперь есть из чего —
/// поэтому шаг выбора, а не три кнопки в шапке.
enum ReportKind {
  general,
  customers,
  drivers;

  String label(AppLocalizations l10n) => switch (this) {
        ReportKind.general => l10n.reportKindGeneral,
        ReportKind.customers => l10n.reportKindCustomers,
        ReportKind.drivers => l10n.reportKindDrivers,
      };

  String hint(AppLocalizations l10n) => switch (this) {
        ReportKind.general => l10n.reportKindGeneralHint,
        ReportKind.customers => l10n.reportKindCustomersHint,
        ReportKind.drivers => l10n.reportKindDriversHint,
      };

  /// Запрос выгрузки. Пути и параметры у всех трёх одинаковые, различается
  /// только разрез, — поэтому выбор живёт здесь, а не тремя ветками на экране.
  Future<ReportExport> export(
    CrmRepository repo, {
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) =>
      switch (this) {
        ReportKind.general => repo.exportGeneralReport(
            dateFrom: dateFrom, dateTo: dateTo, driverId: driverId),
        ReportKind.customers => repo.exportCustomersReport(
            dateFrom: dateFrom, dateTo: dateTo, driverId: driverId),
        ReportKind.drivers => repo.exportDriversReport(
            dateFrom: dateFrom, dateTo: dateTo, driverId: driverId),
      };
}

/// Выбор отчёта перед выгрузкой: разрез, период и — необязательно — водитель.
///
/// Период приходит с экрана отчётов и здесь только показывается: считать его
/// заново значило бы однажды выгрузить не тот период, который админ видит на
/// экране.
class ReportExportPage extends StatefulWidget {
  const ReportExportPage({
    super.key,
    required this.period,
    required this.fileSharer,
    this.initialKind = ReportKind.general,
    this.initialDriverId,
  });

  /// Период, с которым экран открывается. С экрана отчётов приходит тот, что
  /// выбран в шапке; из карточки водителя — месяц по умолчанию.
  final ReportPeriod period;
  final FileSharer fileSharer;

  /// Какой разрез предвыбрать. Из карточки водителя — отчёт по водителям.
  final ReportKind initialKind;

  /// Водитель, по которому сузить выгрузку сразу.
  final String? initialDriverId;

  @override
  State<ReportExportPage> createState() => _ReportExportPageState();
}

class _ReportExportPageState extends State<ReportExportPage> with SubmitState {
  late ReportKind _kind;

  /// `null` — выгружаем по всем водителям.
  String? _driverId;

  /// Период правится здесь же: экран открывают и из карточки водителя, где
  /// селектора периода нет вовсе, — уйти за ним обратно было бы некуда.
  late ReportPeriod _period;

  List<Driver> _drivers = const [];

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _driverId = widget.initialDriverId;
    _period = widget.period;
    _loadDrivers();
  }

  /// Список водителей нужен только для необязательного сужения выгрузки,
  /// поэтому его провал экран не ломает: без списка остаётся вариант
  /// «Все водители», которым выгрузка и так работает.
  Future<void> _loadDrivers() async {
    try {
      final drivers = await context.read<CrmRepository>().getDrivers();
      if (mounted) setState(() => _drivers = drivers);
    } catch (_) {
      // Молча: см. выше.
    }
  }

  Future<void> _export() async {
    final repo = context.read<CrmRepository>();
    final l10n = context.l10n;
    final (from, to) = ReportsBloc.rangeFor(_period);

    // Файл забираем внутрь замыкания: `submit` ведёт флаг занятости и текст
    // ошибки, но результата не возвращает — только «получилось или нет».
    ReportExport? export;
    final ok = await submit(
      () async => export = await _kind.export(
        repo,
        dateFrom: from,
        dateTo: to,
        driverId: _driverId,
      ),
      message: (_) => l10n.reportsExportFailed,
    );
    if (!ok || !mounted) return;

    await widget.fileSharer.share(
      bytes: export!.bytes,
      filename: export!.filename,
      subject: l10n.reportsExportSubject,
    );
    if (mounted) {
      showAppSnackBar(context, l10n.reportExportDone);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;

    return DetailScaffold(
      title: l10n.reportExportTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          SectionBlock(
            label: l10n.reportExportKind,
            child: Column(
              spacing: AppSpacing.md,
              children: [
                for (final kind in ReportKind.values)
                  _KindTile(
                    kind: kind,
                    selected: kind == _kind,
                    onTap:
                        submitting ? null : () => setState(() => _kind = kind),
                  ),
              ],
            ),
          ),
          SectionBlock(
            label: l10n.reportExportPeriod,
            child: SegmentedToggle<ReportPeriod>(
              options: [
                for (final period in StatsPeriod.values)
                  SegmentOption(value: period, label: period.label(l10n)),
              ],
              value: _period,
              columns: 3,
              onChanged: submitting
                  ? (_) {}
                  : (period) => setState(() => _period = period),
            ),
          ),
          SectionBlock(
            label: l10n.reportExportDriver,
            child: Column(
              spacing: AppSpacing.md,
              children: [
                _DriverTile(
                  name: l10n.reportExportAllDrivers,
                  selected: _driverId == null,
                  onTap: submitting ? null : () => setState(() => _driverId = null),
                ),
                for (final driver in _drivers)
                  _DriverTile(
                    name: driver.fullName,
                    selected: _driverId == driver.id,
                    onTap: submitting
                        ? null
                        : () => setState(() => _driverId = driver.id),
                  ),
              ],
            ),
          ),
          if (submitError case final String message)
            Text(
              message,
              style: AppTypography.secondary.copyWith(color: t.danger),
            ),
        ],
      ),
      bottomBar: BottomActionBar(
        child: AppButton(
          label: submitting ? l10n.commonSaving : l10n.reportExportAction,
          onPressed: submitting ? null : _export,
        ),
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final ReportKind kind;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return AppCard(
      onTap: onTap,
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 20,
            color: selected ? t.primary : t.text3,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  kind.label(l10n),
                  style: AppTypography.bodyStrong.copyWith(color: t.text),
                ),
                Text(
                  kind.hint(l10n),
                  style: AppTypography.secondary.copyWith(color: t.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverTile extends StatelessWidget {
  const _DriverTile({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      onTap: onTap,
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 20,
            color: selected ? t.primary : t.text3,
          ),
          Expanded(
            child: Text(
              name,
              style: AppTypography.bodyStrong.copyWith(color: t.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

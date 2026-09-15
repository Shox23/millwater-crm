import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/forms/submit_state.dart';
import '../../../../core/product_config.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/widgets/labeled_text_field.dart';
import '../../../../data/models/price_settings.dart';
import '../../../../data/network/api_envelope.dart';
import '../../../prices/bloc/prices_cubit.dart';
import '../../../prices/presentation/price_rules.dart';
import '../../overlays/desktop_modals.dart';
import '../../overlays/desktop_overlays.dart';
import '../../theme/desktop_typography.dart';
import '../../widgets/desktop_button.dart';
import '../../widgets/desktop_cards.dart';
import '../../widgets/desktop_empty.dart';
import '../../widgets/desktop_table.dart';

/// Раздел «Цены»: действующий прайс, форма новой цены и история.
///
/// Свой экран, а не мобильный `PricesPage` в шторке: прайс — раздел, а не
/// форма по кнопке, и три поля в ряд с историей таблицей справа за столом
/// читаются лучше, чем колонка под палец. Правила при этом одни:
/// загрузка и сохранение — в `PricesCubit`, проверка полей — в `PriceRules`.
class PricesDesktopPage extends StatelessWidget {
  const PricesDesktopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<PricesCubit, PricesState>(
      builder: (context, state) {
        if (state.status == PricesStatus.error) {
          return DesktopEmpty(
            icon: Icons.cloud_off_outlined,
            title: l10n.pricesLoadFailed,
          );
        }
        final current = state.current;
        if (state.status == PricesStatus.loading || current == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.lg,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.lg,
                children: [
                  Expanded(flex: 3, child: _NewPriceForm(current: current)),
                  Expanded(flex: 2, child: _CurrentPriceCard(prices: current)),
                ],
              ),
              _HistoryTable(past: state.past, failed: state.historyFailed),
            ],
          ),
        );
      },
    );
  }
}

/// Форма новой цены: три поля в ряд и кнопка.
///
/// Ключ по `current.id`: после сохранения прайс новый, и поля надо
/// перезаполнить с него — проще пересоздать форму, чем сверять контроллеры.
class _NewPriceForm extends StatefulWidget {
  _NewPriceForm({required this.current}) : super(key: ValueKey(current.id));

  final PriceSettings current;

  @override
  State<_NewPriceForm> createState() => _NewPriceFormState();
}

class _NewPriceFormState extends State<_NewPriceForm> with SubmitState {
  late PriceRules _rules;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rules = PriceRules(context.l10n);
  }

  final _formKey = GlobalKey<FormState>();

  late final _capsule =
      TextEditingController(text: '${widget.current.capsulePrice}');
  late final _fine =
      TextEditingController(text: '${widget.current.damagedBottleFine}');

  @override
  void dispose() {
    _capsule.dispose();
    _fine.dispose();
    super.dispose();
  }

  int get _capsuleValue => PriceRules.parse(_capsule.text);
  int get _fineValue => PriceRules.parse(_fine.text);

  bool get _valid =>
      _rules.capsule(_capsule.text) == null &&
      _rules.price(_fine.text) == null;

  /// Введённое отличается от действующего — есть что сохранять. Без
  /// этого лишний POST завёл бы дубль записи в истории.
  bool get _changed =>
      _capsuleValue != widget.current.capsulePrice ||
      _fineValue != widget.current.damagedBottleFine;

  bool get _canSave => _valid && _changed && !submitting;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = context.l10n;

    // Цена уходит всем водителям сразу — переспрашиваем.
    final confirmed = await showDesktopConfirm(
      context,
      title: l10n.pricesConfirmTitle,
      message: '${l10n.pricesConfirmMessage(
        MoneyFormatter.sum(l10n, _capsuleValue),
      )} ${l10n.pricesConfirmFine(MoneyFormatter.sum(l10n, _fineValue))}',
      confirmLabel: l10n.pricesConfirmAction,
      destructive: false,
    );
    if (!confirmed || !mounted) return;

    final cubit = context.read<PricesCubit>();
    final saved = await submit(
      () => cubit.save(
        capsulePrice: _capsuleValue,
        damagedBottleFine: _fineValue,
      ),
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.pricesSaveFailed)
          : l10n.pricesSaveFailed,
    );
    if (saved && mounted) showDesktopToast(context, l10n.pricesUpdated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;

    return DesktopCard(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUnfocus,
        onChanged: () => setState(() {}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.lg,
          children: [
            Text(
              l10n.pricesNew,
              style: DesktopTypography.navGroup.copyWith(color: t.text2),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.lg,
              children: [
                Expanded(
                  child: _PriceField(
                    label: l10n.pricesCapsule,
                    hint: '20000',
                    helper: l10n.pricesCapsuleHelper(
                        ProductConfig.capsuleVolumeLiters),
                    controller: _capsule,
                    validator: _rules.capsule,
                  ),
                ),
                Expanded(
                  child: _PriceField(
                    label: l10n.pricesDamagedFine,
                    hint: '40000',
                    helper: l10n.pricesDamagedFineHelper,
                    controller: _fine,
                    validator: _rules.price,
                    onSubmitted: (_) => _canSave ? _submit() : null,
                  ),
                ),
              ],
            ),
            if (submitError case final String message)
              Text(
                message,
                style: DesktopTypography.secondary.copyWith(color: t.danger),
              ),
            Row(
              children: [
                const Spacer(),
                DesktopButton(
                  label: submitting ? l10n.commonSaving : l10n.commonSave,
                  onPressed: _canSave ? _submit : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Поле суммы: только цифры, до десяти знаков.
class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.label,
    required this.hint,
    required this.helper,
    required this.controller,
    required this.validator,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final String helper;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return LabeledTextField(
      label: label,
      hint: hint,
      helper: helper,
      helperMaxLines: 2,
      controller: controller,
      validator: validator,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 10,
      textInputAction:
          onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onSubmitted: onSubmitted,
    );
  }
}

/// Действующий прайс: три строки и с какого числа действует.
class _CurrentPriceCard extends StatelessWidget {
  const _CurrentPriceCard({required this.prices});

  final PriceSettings prices;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Text(
            l10n.pricesCurrent,
            style: DesktopTypography.navGroup.copyWith(color: t.text2),
          ),
          _PriceRow(
            icon: Icons.water_drop_outlined,
            label: l10n.pricesCapsuleRow(ProductConfig.capsuleVolumeLiters),
            value: MoneyFormatter.sum(l10n, prices.capsulePrice),
          ),
          Divider(height: 1, color: t.border),
          _PriceRow(
            icon: Icons.report_gmailerrorred_outlined,
            label: l10n.pricesDamagedFineRow,
            value: MoneyFormatter.sum(l10n, prices.damagedBottleFine),
          ),
          Text(
            l10n.pricesEffectiveFrom(
                DateFormat('dd.MM.yyyy').format(prices.createdAt)),
            style: DesktopTypography.secondary.copyWith(color: t.text2),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
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

    return Row(
      spacing: AppSpacing.md,
      children: [
        Icon(icon, size: 18, color: t.text2),
        Expanded(
          child: Text(
            label,
            style: DesktopTypography.body.copyWith(color: t.text2),
          ),
        ),
        Text(
          value,
          style: DesktopTypography.bodyStrong.copyWith(color: t.text),
        ),
      ],
    );
  }
}

/// Прошлые прайсы таблицей: с какого числа и почём.
class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.past, required this.failed});

  final List<PriceSettings> past;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.md,
      children: [
        Text(
          l10n.pricesHistory,
          style: DesktopTypography.navGroup.copyWith(color: t.text2),
        ),
        DesktopTable(
          columns: [
            DesktopColumn(l10n.pricesEffectiveFromColumn, flex: 12),
            DesktopColumn(
              l10n.pricesCapsuleRow(ProductConfig.capsuleVolumeLiters),
              flex: 10,
            ),
            DesktopColumn(l10n.pricesDamagedFineRow, flex: 10),
          ],
          itemCount: past.length,
          empty: Center(
            child: Text(
              failed ? l10n.pricesHistoryFailed : l10n.pricesHistoryEmpty,
              style: DesktopTypography.secondary.copyWith(color: t.text2),
            ),
          ),
          cellsBuilder: (i) {
            final p = past[i];
            return [
              Text(
                DateFormat('dd.MM.yyyy').format(p.createdAt),
                style: DesktopTypography.tableCell.copyWith(color: t.text),
              ),
              Text(
                MoneyFormatter.sum(l10n, p.capsulePrice),
                style: DesktopTypography.tableCell.copyWith(color: t.text),
              ),
              Text(
                MoneyFormatter.sum(l10n, p.damagedBottleFine),
                style: DesktopTypography.tableCell.copyWith(color: t.text),
              ),
            ];
          },
        ),
      ],
    );
  }
}

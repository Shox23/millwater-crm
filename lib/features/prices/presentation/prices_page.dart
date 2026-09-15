import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/product_config.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../core/widgets/section_block.dart';
import '../../../data/models/price_settings.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/crm_repository.dart';
import '../bloc/prices_cubit.dart';
import 'price_rules.dart';

/// Экран «Цены»: действующий прайс и его изменение.
///
/// Только для администратора: `/admin/prices/*` под водительским токеном
/// отвечает 403, да и менять прайс — не его дело.
///
/// Сервер прайс не правит, а копит: `POST /admin/prices` заводит новую
/// запись, действующей становится последняя. Поэтому кнопка называется
/// «Сохранить», но по сути это «назначить новую цену».
class PricesPage extends StatelessWidget {
  const PricesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Кубит свой, а не из дерева: экран открывается отдельным маршрутом из
    // настроек, и держать прайс живым, пока его никто не смотрит, незачем.
    return BlocProvider(
      create: (context) => PricesCubit(context.read<CrmRepository>())..load(),
      child: const _PricesForm(),
    );
  }
}

class _PricesForm extends StatefulWidget {
  const _PricesForm();

  @override
  State<_PricesForm> createState() => _PricesFormState();
}

class _PricesFormState extends State<_PricesForm> with SubmitState {
  /// Правила проверки на языке интерфейса. Пересобираются при смене
  /// локали: `didChangeDependencies` вызывается снова.
  late PriceRules _rules;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rules = PriceRules(context.l10n);
  }

  final _formKey = GlobalKey<FormState>();

  final _capsule = TextEditingController();
  final _fine = TextEditingController();

  final _capsuleFocus = FocusNode();
  final _fineFocus = FocusNode();

  /// Действующий прайс, под который заполнены поля. Нужен, чтобы отличить
  /// «поля пустые, потому что ещё грузимся» от «админ стёр значение».
  PriceSettings? _current;

  @override
  void dispose() {
    _capsule.dispose();
    _fine.dispose();
    _capsuleFocus.dispose();
    _fineFocus.dispose();
    super.dispose();
  }

  /// Заполняет поля действующим прайсом, когда он приехал.
  void _fill(PriceSettings prices) {
    _current = prices;
    _capsule.text = '${prices.capsulePrice}';
    _fine.text = '${prices.damagedBottleFine}';
  }

  /// Поля и их текущие ошибки — один источник и для кнопки, и для перехода
  /// к первой ошибке.
  List<(FocusNode, String?)> get _checks => [
        (_capsuleFocus, _rules.capsule(_capsule.text)),
        (_fineFocus, _rules.price(_fine.text)),
      ];

  bool get _valid => _checks.every((c) => c.$2 == null);

  int get _capsuleValue => PriceRules.parse(_capsule.text);
  int get _fineValue => PriceRules.parse(_fine.text);

  /// Введённое отличается от действующего прайса — есть что сохранять.
  bool get _changed =>
      _current == null ||
      _capsuleValue != _current!.capsulePrice ||
      _fineValue != _current!.damagedBottleFine;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      for (final (node, error) in _checks) {
        if (error != null) {
          node.requestFocus();
          return;
        }
      }
      return;
    }

    // Цена уходит всем водителям сразу — спрашиваем подтверждение.
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.pricesConfirmTitle,
      message: '${context.l10n.pricesConfirmMessage(
        MoneyFormatter.sum(context.l10n, _capsuleValue),
      )} ${context.l10n.pricesConfirmFine(
        MoneyFormatter.sum(context.l10n, _fineValue),
      )}',
      confirmLabel: context.l10n.pricesConfirmAction,
      // Не разрушительное действие: старый прайс остаётся в истории сервера.
      destructive: false,
    );
    if (!confirmed || !mounted) return;

    final cubit = context.read<PricesCubit>();
    final l10n = context.l10n;

    final saved = await submit(
      () => cubit.save(
        capsulePrice: _capsuleValue,
        damagedBottleFine: _fineValue,
      ),
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.pricesSaveFailed)
          : l10n.pricesSaveFailed,
    );

    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PricesCubit, PricesState>(
      // Поля заполняются один раз на приход прайса, а не на каждую
      // перестройку: иначе ввод админа затирался бы ответом сервера.
      listenWhen: (a, b) => a.status != b.status && b.current != null,
      listener: (_, state) => _fill(state.current!),
      builder: (context, state) => _build(context, state),
    );
  }

  Widget _build(BuildContext context, PricesState state) {
    final t = context.tokens;
    final loading = state.status == PricesStatus.loading;
    final loadFailed = state.status == PricesStatus.error;

    return DetailScaffold(
      title: context.l10n.pricesTitle,
      body: loading
          ? const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          : loadFailed
              ? Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: ErrorRetryView(
                    onRetry: context.read<PricesCubit>().load,
                    message: context.l10n.pricesLoadFailed,
                  ),
                )
              : Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  onChanged: () => setState(() {}),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.lg,
                    children: [
                      SectionBlock(
                        label: context.l10n.pricesCurrent,
                        child: _CurrentPriceCard(prices: state.current!),
                      ),
                      SectionBlock(
                        label: context.l10n.pricesNew,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: AppSpacing.lg,
                          children: [
                            LabeledTextField(
                              label: context.l10n.pricesCapsule,
                              hint: '20000',
                              helper: context.l10n.pricesCapsuleHelper(
                                  ProductConfig.capsuleVolumeLiters),
                              // Узбекские подписи единиц длиннее русских и в
                              // одну строку уже не помещаются.
                              helperMaxLines: 2,
                              controller: _capsule,
                              focusNode: _capsuleFocus,
                              validator: _rules.capsule,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              maxLength: 10,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _fineFocus.requestFocus(),
                            ),
                            LabeledTextField(
                              label: context.l10n.pricesDamagedFine,
                              hint: '40000',
                              helper: context.l10n.pricesDamagedFineHelper,
                              helperMaxLines: 2,
                              controller: _fine,
                              focusNode: _fineFocus,
                              validator: _rules.price,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              maxLength: 10,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                            ),
                          ],
                        ),
                      ),
                      SectionBlock(
                        label: context.l10n.pricesHistory,
                        child: _HistoryCard(
                          past: state.past,
                          failed: state.historyFailed,
                        ),
                      ),
                      if (submitError != null)
                        Text(submitError!,
                            style: AppTypography.secondary
                                .copyWith(color: t.danger)),
                    ],
                  ),
                ),
      bottomBar: loading || loadFailed
          ? null
          : BottomActionBar(
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  Expanded(
                    child: AppButton(
                      label: context.l10n.commonCancel,
                      variant: AppButtonVariant.secondary,
                      onPressed:
                          submitting ? null : () => Navigator.of(context).pop(false),
                    ),
                  ),
                  Expanded(
                    child: AppButton(
                      label: submitting ? context.l10n.commonSaving : context.l10n.commonSave,
                      // Кнопка молчит и когда цифры те же: сохранять нечего,
                      // а лишний POST завёл бы дубль записи в истории.
                      enabled: _valid && _changed && !submitting,
                      onPressed:
                          (_valid && _changed && !submitting) ? _submit : null,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Карточка действующего прайса: цены и когда их назначили.
class _CurrentPriceCard extends StatelessWidget {
  const _CurrentPriceCard({required this.prices});

  final PriceSettings prices;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          _Row(
            icon: Icons.water_drop_outlined,
            label: context.l10n
                .pricesCapsuleRow(ProductConfig.capsuleVolumeLiters),
            value: MoneyFormatter.sum(context.l10n, prices.capsulePrice),
          ),
          const Divider(),
          _Row(
            icon: Icons.report_gmailerrorred_outlined,
            label: context.l10n.pricesDamagedFineRow,
            value: MoneyFormatter.sum(context.l10n, prices.damagedBottleFine),
          ),
          Text(
            context.l10n.pricesEffectiveFrom(
                DateFormat('dd.MM.yyyy').format(prices.createdAt)),
            style: AppTypography.secondary.copyWith(color: t.text2),
          ),
        ],
      ),
    );
  }
}

/// Прошлые прайсы: когда действовали и почём.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.past, required this.failed});

  final List<PriceSettings> past;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (failed || past.isEmpty) {
      return AppCard(
        child: Text(
          failed
              ? context.l10n.pricesHistoryFailed
              : context.l10n.pricesHistoryEmpty,
          style: AppTypography.secondary.copyWith(color: t.text2),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          for (var i = 0; i < past.length; i++) ...[
            if (i > 0) const Divider(),
            _HistoryRow(prices: past[i]),
          ],
        ],
      ),
    );
  }
}

/// Одна запись истории: дата слева, цены справа.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.prices});

  final PriceSettings prices;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Row(
      spacing: AppSpacing.md,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat('dd.MM.yyyy').format(prices.createdAt),
            style: AppTypography.secondary.copyWith(color: t.text2)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 2,
            children: [
              // Значения приходят строками произвольной длины — при разборе
              // они насыщаются, поэтому режем строку, а не ломаем вёрстку.
              Text(
                MoneyFormatter.sum(context.l10n, prices.capsulePrice),
                style: AppTypography.bodyStrong.copyWith(color: t.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // У прайсов, заведённых до появления штрафа, он нулевой —
              // показывать строку «штраф 0» в истории незачем.
              if (prices.damagedBottleFine > 0)
                Text(
                  context.l10n.pricesFineRow(
                      MoneyFormatter.sum(context.l10n, prices.damagedBottleFine)),
                  style: AppTypography.secondary.copyWith(color: t.text2),
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

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      spacing: AppSpacing.md,
      children: [
        Icon(icon, size: 20, color: t.primary),
        Expanded(
          child: Text(label,
              style: AppTypography.secondary.copyWith(color: t.text2)),
        ),
        // Сумма приходит строкой произвольной длины: режем, а не ломаем строку.
        Flexible(
          child: Text(
            value,
            style: AppTypography.bodyStrong.copyWith(color: t.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

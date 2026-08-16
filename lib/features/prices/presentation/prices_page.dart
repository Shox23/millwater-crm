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
import '../../../core/utils/idempotency.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/validation/validators.dart';
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

/// Экран «Цены»: действующий прайс и его изменение.
///
/// Только для администратора: `/admin/prices/*` под водительским токеном
/// отвечает 403, да и менять прайс — не его дело.
///
/// Сервер прайс не правит, а копит: `POST /admin/prices` заводит новую
/// запись, действующей становится последняя. Поэтому кнопка называется
/// «Сохранить», но по сути это «назначить новую цену».
class PricesPage extends StatefulWidget {
  const PricesPage({super.key});

  @override
  State<PricesPage> createState() => _PricesPageState();
}

class _PricesPageState extends State<PricesPage> with SubmitState {
  /// Правила проверки на языке интерфейса. Пересобираются при смене
  /// локали: `didChangeDependencies` вызывается снова.
  late Validators _v;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _v = Validators(context.l10n);
  }

  final _formKey = GlobalKey<FormState>();

  final _capsule = TextEditingController();
  final _deposit = TextEditingController();

  final _capsuleFocus = FocusNode();
  final _depositFocus = FocusNode();

  PriceSettings? _current;

  /// Прошлые прайсы, новые первыми. Действующий сюда не попадает — он уже
  /// показан карточкой выше.
  List<PriceSettings> _past = const [];

  /// История не загрузилась. Экран из-за этого не ломаем: главное здесь —
  /// действующая цена и её изменение.
  bool _historyFailed = false;

  bool _loading = true;
  bool _loadFailed = false;

  /// Один ключ на весь экран: повтор после обрыва связи не должен завести
  /// вторую запись прайса.
  final String _idempotencyKey = newIdempotencyKey('price');

  FormFieldValidator<String> get _priceRule => Validators.all([
    _v.notEmpty(context.l10n.pricesEmpty),
    _v.maxLen(10),
  ]);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _capsule.dispose();
    _deposit.dispose();
    _capsuleFocus.dispose();
    _depositFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final repo = context.read<CrmRepository>();
    try {
      final prices = await repo.getPrices();
      final history = await _loadHistory(repo);
      if (!mounted) return;
      setState(() {
        _current = prices;
        // Действующий прайс убираем из списка: он уже в карточке выше.
        _past = history.where((p) => p.id != prices.id).toList();
        _capsule.text = '${prices.capsulePrice}';
        _deposit.text = '${prices.depositPrice}';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  /// История — не повод не показать экран: её отказ гасится здесь, а не
  /// уводит весь экран в «Не удалось загрузить цены».
  Future<List<PriceSettings>> _loadHistory(CrmRepository repo) async {
    try {
      final history = await repo.getPriceHistory();
      _historyFailed = false;
      return history;
    } catch (_) {
      _historyFailed = true;
      return const [];
    }
  }

  /// Поля и их текущие ошибки — один источник и для кнопки, и для перехода
  /// к первой ошибке.
  List<(FocusNode, String?)> get _checks => [
        (_capsuleFocus, _capsuleRule(_capsule.text)),
        (_depositFocus, _priceRule(_deposit.text)),
      ];

  /// Ноль за капсулу — почти наверняка опечатка: воду раздают не бесплатно.
  /// Залог нулевым быть может, поэтому у него правило проще.
  String? _capsuleRule(String? value) {
    final error = _priceRule(value);
    if (error != null) return error;
    return (int.tryParse(value!.trim()) ?? 0) > 0
        ? null
        : context.l10n.pricesZero;
  }

  bool get _valid => _checks.every((c) => c.$2 == null);

  int get _capsuleValue => int.tryParse(_capsule.text.trim()) ?? 0;
  int get _depositValue => int.tryParse(_deposit.text.trim()) ?? 0;

  /// Введённое отличается от действующего прайса — есть что сохранять.
  bool get _changed =>
      _current == null ||
      _capsuleValue != _current!.capsulePrice ||
      _depositValue != _current!.depositPrice;

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
      message: context.l10n.pricesConfirmMessage(
        MoneyFormatter.sum(context.l10n, _capsuleValue),
        MoneyFormatter.sum(context.l10n, _depositValue),
      ),
      confirmLabel: context.l10n.pricesConfirmAction,
      // Не разрушительное действие: старый прайс остаётся в истории сервера.
      destructive: false,
    );
    if (!confirmed || !mounted) return;

    final repo = context.read<CrmRepository>();
    final l10n = context.l10n;

    final saved = await submit(
      () => repo.setPrices(
        capsulePrice: _capsuleValue,
        depositPrice: _depositValue,
        idempotencyKey: _idempotencyKey,
      ),
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.pricesSaveFailed)
          : l10n.pricesSaveFailed,
    );

    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return DetailScaffold(
      title: context.l10n.pricesTitle,
      body: _loading
          ? const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          : _loadFailed
              ? Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: ErrorRetryView(
                    onRetry: _load,
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
                        child: _CurrentPriceCard(prices: _current!),
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
                              controller: _capsule,
                              focusNode: _capsuleFocus,
                              validator: _capsuleRule,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              maxLength: 10,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _depositFocus.requestFocus(),
                            ),
                            LabeledTextField(
                              label: context.l10n.pricesDeposit,
                              hint: '50000',
                              helper: context.l10n.pricesDepositHelper,
                              controller: _deposit,
                              focusNode: _depositFocus,
                              validator: _priceRule,
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
                          past: _past,
                          failed: _historyFailed,
                        ),
                      ),
                      if (submitError != null)
                        Text(submitError!,
                            style: AppTypography.secondary
                                .copyWith(color: t.danger)),
                    ],
                  ),
                ),
      bottomBar: _loading || _loadFailed
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
            icon: Icons.inventory_2_outlined,
            label: context.l10n.pricesDeposit,
            value: MoneyFormatter.sum(context.l10n, prices.depositPrice),
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
              Text(
                context.l10n.pricesDepositRow(
                    MoneyFormatter.sum(context.l10n, prices.depositPrice)),
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

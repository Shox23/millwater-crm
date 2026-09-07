import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../core/widgets/photo_attach_tile.dart';
import '../../../core/widgets/segmented_toggle.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/order.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/crm_repository.dart';

/// Правка оплаты закрытого заказа администратором.
///
/// Сумма здесь — **вся стоимость заказа**, а не доплата: сервер сам считает
/// разницу с уже принятыми деньгами, пишет её отдельной строкой в историю
/// платежей и переносит остаток заказчику в долг или предоплату.
///
/// Насколько именно изменится долг, экран не обещает: сколько по заказу уже
/// принято, сервер наружу не отдаёт (в `OrderResponse` такого поля нет), и
/// посчитать разницу нечем. Поэтому показываем то, что знаем наверняка —
/// сумму «было / станет» и текущий баланс заказчика.
class OrderPaymentPage extends StatefulWidget {
  const OrderPaymentPage({super.key, required this.order});

  final Order order;

  @override
  State<OrderPaymentPage> createState() => _OrderPaymentPageState();
}

class _OrderPaymentPageState extends State<OrderPaymentPage> with SubmitState {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  final _amountFocus = FocusNode();

  late PaymentMethod _method;
  XFile? _photo;

  /// Заказчик — ради текущего баланса. `null`, пока не пришёл или не добыт:
  /// блок с балансом тогда просто не показывается.
  Customer? _customer;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: '${widget.order.orderAmount ?? 0}',
    );
    _note = TextEditingController();
    _method = widget.order.paymentMethod ?? PaymentMethod.cash;
    _loadCustomer();
  }

  /// Молча: баланс здесь — контекст для решения, а не условие сохранения.
  Future<void> _loadCustomer() async {
    try {
      final customer =
          await context.read<CrmRepository>().getCustomer(widget.order.customerId);
      if (mounted) setState(() => _customer = customer);
    } catch (_) {
      // Блока с балансом просто не будет.
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  int? get _amountOrNull => int.tryParse(_amount.text.trim());

  /// Сумма изменилась — иначе сохранять нечего: сервер запишет нулевую
  /// дельту и лишнюю строку в журнал.
  bool get _changed =>
      _amountOrNull != widget.order.orderAmount ||
      _method != widget.order.paymentMethod;

  bool get _valid => (_amountOrNull ?? -1) >= 0;

  /// Форму трогали — уход без сохранения нужно переспросить.
  ///
  /// Шире, чем [_changed]: комментарий на дельту не влияет и кнопку не
  /// включает, но набранный и потерянный свайпом текст — та же потеря
  /// работы, что и сумма.
  bool get _dirty => _changed || _note.text.trim().isNotEmpty;

  /// Закрытие экрана: при тронутой форме спрашиваем подтверждение.
  Future<void> _leave() async {
    if (!_dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    final leave = await showConfirmDialog(
      context,
      title: context.l10n.leaveWithoutSavingTitle,
      message: context.l10n.leaveWithoutSavingMessage,
      confirmLabel: context.l10n.commonLeave,
      cancelLabel: context.l10n.commonStay,
    );
    if (leave && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _submit() async {
    final repo = context.read<CrmRepository>();
    final l10n = context.l10n;

    final saved = await submit(
      () => repo.updateOrderPayment(
        orderId: widget.order.id,
        amount: _amountOrNull ?? 0,
        method: _method,
        note: _note.text,
        photoPath: _photo?.path,
      ),
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.orderPaymentFailed)
          : l10n.orderPaymentFailed,
    );

    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final before = widget.order.orderAmount ?? 0;
    final after = _amountOrNull ?? 0;
    final customer = _customer;

    return PopScope(
      // Не `false`: наглухо запрещённый pop гасит краевой жест «назад» на
      // iOS. Нетронутую форму отпускаем сразу, тронутую перехватываем.
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: DetailScaffold(
      title: l10n.orderPaymentTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          LabeledTextField(
            label: l10n.orderPaymentAmount,
            helper: l10n.orderPaymentAmountHint,
            // В одну строку фраза не влезает и обрезается ровно на том
            // месте, ради которого написана: «разницу сервер посчитает сам».
            helperMaxLines: 2,
            controller: _amount,
            focusNode: _amountFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 12,
            onChanged: (_) => setState(() {}),
            validator: (value) => (int.tryParse((value ?? '').trim()) ?? -1) >= 0
                ? null
                : l10n.orderPaymentAmountEmpty,
          ),
          // «Было / станет» — чтобы правка суммы читалась как правка, а не
          // как ввод с нуля.
          if (_changed && _valid)
            AppCard(
              child: Text(
                l10n.orderPaymentWasBecomes(
                  MoneyFormatter.sum(l10n, before),
                  MoneyFormatter.sum(l10n, after),
                ),
                style: AppTypography.bodyStrong.copyWith(color: t.text),
              ),
            ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: [
                Text(
                  l10n.completionMethod,
                  style: AppTypography.bodyStrong.copyWith(color: t.text),
                ),
                SegmentedToggle<PaymentMethod>(
                  value: _method,
                  onChanged: submitting
                      ? (_) {}
                      : (method) => setState(() {
                            _method = method;
                            // Уход с карты стирает снимок: иначе он ушёл бы
                            // приложенным к оплате, которая его не
                            // предполагает.
                            if (!method.needsPhoto) _photo = null;
                          }),
                  options: [
                    for (final method in PaymentMethod.values)
                      SegmentOption(
                        value: method,
                        label: method.label(l10n),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (customer != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    l10n.orderPaymentBalanceNow,
                    style: AppTypography.secondary.copyWith(color: t.text2),
                  ),
                  Text(
                    customer.debt > 0
                        ? '${l10n.financeDebt}: '
                            '${MoneyFormatter.sum(l10n, customer.debt)}'
                        : '${l10n.financePrepayment}: '
                            '${MoneyFormatter.sum(l10n, customer.prepayment)}',
                    style: AppTypography.bodyStrong.copyWith(
                      color: customer.debt > 0 ? t.danger : t.success,
                    ),
                  ),
                  Text(
                    l10n.orderPaymentBalanceHint,
                    style: AppTypography.secondary.copyWith(color: t.text2),
                  ),
                ],
              ),
            ),
          LabeledTextField(
            label: l10n.orderPaymentNote,
            hint: l10n.orderPaymentNoteHint,
            helper: l10n.commonOptional,
            controller: _note,
            maxLength: 255,
          ),
          if (_method.needsPhoto)
            PhotoAttachTile(
              photo: _photo,
              enabled: !submitting,
              onChanged: (photo) => setState(() => _photo = photo),
            ),
        ],
      ),
      bottomBar: BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.md,
          children: [
            if (submitError != null)
              Text(
                submitError!,
                style: AppTypography.secondary.copyWith(color: t.danger),
                textAlign: TextAlign.center,
              ),
            AppButton(
              label: submitting ? l10n.commonSaving : l10n.commonSave,
              // Кнопка молчит и когда цифры те же: сохранять нечего, а лишний
              // запрос завёл бы пустую строку в истории платежей.
              enabled: _valid && _changed && !submitting,
              onPressed: (_valid && _changed && !submitting) ? _submit : null,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

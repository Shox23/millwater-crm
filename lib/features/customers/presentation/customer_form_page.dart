import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/utils/idempotency.dart';
import '../../../core/utils/uz_phone.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../data/models/customer.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/crm_repository.dart';

/// Форма создания/редактирования заказчика.
class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({super.key, this.customer});

  final Customer? customer;

  bool get isEdit => customer != null;

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> with SubmitState {
  /// Правила проверки на языке интерфейса. Пересобираются при смене
  /// локали: `didChangeDependencies` вызывается снова.
  late Validators _v;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _v = Validators(context.l10n);
  }

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _comment;

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _commentFocus = FocusNode();


  /// Один ключ на весь экран: повтор после обрыва связи не должен завести
  /// второго заказчика. При редактировании не нужен — PATCH идемпотентен.
  final String _idempotencyKey = newIdempotencyKey('customer');

  // Правила живут в полях, чтобы поле и переход к первой ошибке
  // проверялись одним и тем же кодом.
  FormFieldValidator<String> get _nameRule => Validators.all([
    _v.notEmpty(context.l10n.customerFormNameEmpty),
    _v.maxLen(120),
  ]);
  FormFieldValidator<String> get _addressRule => Validators.all([
    _v.notEmpty(context.l10n.customerFormAddressEmpty),
    _v.maxLen(200),
  ]);
  FormFieldValidator<String> get _commentRule => _v.maxLen(300);

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer?.name ?? '');
    // У нового заказчика в поле уже стоит код страны — его не надо набирать.
    _phone = TextEditingController(
      text: customer == null ? UzPhone.prefix : UzPhone.format(customer.phone),
    );
    _address = TextEditingController(text: customer?.address ?? '');
    _comment = TextEditingController(text: customer?.comment ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _comment.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _addressFocus.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  String? get _commentOrNull =>
      _comment.text.trim().isEmpty ? null : _comment.text.trim();

  /// Форму меняли — уход без сохранения нужно подтвердить.
  bool get _dirty {
    final customer = widget.customer;
    return _name.text.trim() != (customer?.name ?? '') ||
        UzPhone.normalize(_phone.text) !=
            UzPhone.normalize(customer?.phone ?? '') ||
        _address.text.trim() != (customer?.address ?? '') ||
        _comment.text.trim() != (customer?.comment ?? '');
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      _focusFirstInvalid();
      return;
    }
    await _save();
  }

  /// Поля и их текущие ошибки — один источник и для кнопки, и для перехода
  /// к первой ошибке. Разъедься эти два списка, кнопка разрешала бы
  /// отправку формы, которую `validate()` тут же отклонит.
  List<(FocusNode, String?)> get _checks => [
        (_nameFocus, _nameRule(_name.text)),
        (_phoneFocus, _v.phone(_phone.text)),
        (_addressFocus, _addressRule(_address.text)),
        (_commentFocus, _commentRule(_comment.text)),
      ];

  /// Все поля заполнены верно — кнопку можно разблокировать.
  bool get _valid => _checks.every((c) => c.$2 == null);

  /// Ставит курсор в первое поле с ошибкой — иначе непонятно, куда смотреть.
  void _focusFirstInvalid() {
    for (final (node, error) in _checks) {
      if (error != null) {
        node.requestFocus();
        return;
      }
    }
  }

  Future<void> _save() async {
    final repo = context.read<CrmRepository>();
    // Строки берём до запроса: после await контекст уже мог уйти.
    final l10n = context.l10n;
    final phone = UzPhone.normalize(_phone.text);

    final saved = await submit(
      () => widget.isEdit
          ? repo.updateCustomer(widget.customer!.copyWith(
              name: _name.text.trim(),
              phone: phone,
              address: _address.text.trim(),
              comment: _commentOrNull,
            ))
          : repo.addCustomer(
              name: _name.text.trim(),
              phone: phone,
              address: _address.text.trim(),
              comment: _commentOrNull,
              idempotencyKey: _idempotencyKey,
            ),
      // Сервер может отклонить и валидные с виду данные: занятый телефон,
      // упавшая сеть.
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.customerFormSaveFailed)
          : l10n.customerFormSaveFailed,
    );

    if (saved && mounted) Navigator.of(context).pop(true);
  }

  /// Закрытие формы: при изменённых данных спрашиваем подтверждение.
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: DetailScaffold(
        title: widget.isEdit ? context.l10n.customerFormEditTitle : context.l10n.customerFormNewTitle,
        body: Form(
          key: _formKey,
          // Ошибка появляется, когда поле закончили заполнять и ушли из него.
          autovalidateMode: AutovalidateMode.onUnfocus,
          // Любое изменение — пересчёт состояния кнопки.
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.lg,
            children: [
              LabeledTextField(
                label: context.l10n.customerFormName,
                hint: context.l10n.customerFormNameHint,
                controller: _name,
                focusNode: _nameFocus,
                validator: _nameRule,
                maxLength: 120,
                autofocus: !widget.isEdit,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _phoneFocus.requestFocus(),
              ),
              LabeledTextField(
                label: context.l10n.loginPhone,
                hint: '+998 90 123 45 67',
                controller: _phone,
                focusNode: _phoneFocus,
                validator: _v.phone,
                keyboardType: TextInputType.phone,
                inputFormatters: const [UzPhoneInputFormatter()],
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _addressFocus.requestFocus(),
              ),
              LabeledTextField(
                label: context.l10n.customerFormAddress,
                hint: context.l10n.customerFormAddressHint,
                controller: _address,
                focusNode: _addressFocus,
                validator: _addressRule,
                maxLength: 200,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _commentFocus.requestFocus(),
              ),
              LabeledTextField(
                label: context.l10n.customerFormComment,
                hint: context.l10n.customerFormCommentHint,
                helper: context.l10n.commonOptional,
                controller: _comment,
                focusNode: _commentFocus,
                validator: _commentRule,
                maxLength: 300,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
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
                  style: AppTypography.secondary
                      .copyWith(color: context.tokens.danger),
                  textAlign: TextAlign.center,
                ),
              Row(
                spacing: AppSpacing.md,
                children: [
                  Expanded(
                    child: AppButton(
                      label: context.l10n.commonCancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: submitting ? null : _leave,
                    ),
                  ),
                  Expanded(
                    child: AppButton(
                      label: submitting
                          ? context.l10n.commonSaving
                          : (widget.isEdit ? context.l10n.commonSave : context.l10n.commonAdd),
                      // Пока в форме есть ошибки, отправлять нечего.
                      enabled: _valid && !submitting,
                      onPressed: (_valid && !submitting) ? _submit : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
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

class _CustomerFormPageState extends State<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _comment;

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _commentFocus = FocusNode();

  bool _saving = false;
  String? _error;

  // Правила живут в полях, чтобы поле и переход к первой ошибке
  // проверялись одним и тем же кодом.
  static final _nameRule = Validators.all([
    Validators.notEmpty('Введите название или имя'),
    Validators.maxLen(120),
  ]);
  static final _addressRule = Validators.all([
    Validators.notEmpty('Введите адрес доставки'),
    Validators.maxLen(200),
  ]);
  static final _commentRule = Validators.maxLen(300);

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

  /// Ставит курсор в первое поле с ошибкой — иначе непонятно, куда смотреть.
  void _focusFirstInvalid() {
    final checks = [
      (_nameFocus, _nameRule(_name.text)),
      (_phoneFocus, Validators.phone(_phone.text)),
      (_addressFocus, _addressRule(_address.text)),
      (_commentFocus, _commentRule(_comment.text)),
    ];
    for (final (node, error) in checks) {
      if (error != null) {
        node.requestFocus();
        return;
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = context.read<CrmRepository>();
    final phone = UzPhone.normalize(_phone.text);
    try {
      if (widget.isEdit) {
        await repo.updateCustomer(widget.customer!.copyWith(
          name: _name.text.trim(),
          phone: phone,
          address: _address.text.trim(),
          comment: _commentOrNull,
        ));
      } else {
        await repo.addCustomer(
          name: _name.text.trim(),
          phone: phone,
          address: _address.text.trim(),
          comment: _commentOrNull,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      // Сервер может отклонить и валидные с виду данные: занятый телефон,
      // упавшая сеть. Экран обязан ожить, а не остаться с серой кнопкой.
      _failed(apiErrorMessage(e, fallback: _saveErrorText));
    } catch (_) {
      _failed(_saveErrorText);
    }
  }

  static const _saveErrorText = 'Не удалось сохранить заказчика.';

  void _failed(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  /// Закрытие формы: при изменённых данных спрашиваем подтверждение.
  Future<void> _leave() async {
    if (!_dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    final leave = await showConfirmDialog(
      context,
      title: 'Выйти без сохранения?',
      message: 'Введённые данные будут потеряны.',
      confirmLabel: 'Выйти',
      cancelLabel: 'Остаться',
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
        title: widget.isEdit ? 'Редактирование заказчика' : 'Новый заказчик',
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.lg,
            children: [
              LabeledTextField(
                label: 'Название / имя',
                hint: 'Например, Кафе «Nasiba»',
                controller: _name,
                focusNode: _nameFocus,
                validator: _nameRule,
                maxLength: 120,
                autofocus: !widget.isEdit,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _phoneFocus.requestFocus(),
              ),
              LabeledTextField(
                label: 'Номер телефона',
                hint: '+998 90 123 45 67',
                controller: _phone,
                focusNode: _phoneFocus,
                validator: Validators.phone,
                keyboardType: TextInputType.phone,
                inputFormatters: const [UzPhoneInputFormatter()],
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _addressFocus.requestFocus(),
              ),
              LabeledTextField(
                label: 'Адрес доставки',
                hint: 'Район, улица, дом',
                controller: _address,
                focusNode: _addressFocus,
                validator: _addressRule,
                maxLength: 200,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _commentFocus.requestFocus(),
              ),
              LabeledTextField(
                label: 'Комментарий',
                hint: 'Например, район или ориентир',
                helper: 'Необязательно',
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
              if (_error != null)
                Text(
                  _error!,
                  style: AppTypography.secondary
                      .copyWith(color: context.tokens.danger),
                  textAlign: TextAlign.center,
                ),
              Row(
                spacing: AppSpacing.md,
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Отменить',
                      variant: AppButtonVariant.secondary,
                      onPressed: _saving ? null : _leave,
                    ),
                  ),
                  Expanded(
                    child: AppButton(
                      label: _saving
                          ? 'Сохранение…'
                          : (widget.isEdit ? 'Сохранить' : 'Добавить'),
                      enabled: !_saving,
                      onPressed: _saving ? null : _submit,
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

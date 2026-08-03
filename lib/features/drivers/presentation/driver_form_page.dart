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
import '../../../data/models/driver.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/crm_repository.dart';

/// Форма создания/редактирования водителя.
class DriverFormPage extends StatefulWidget {
  const DriverFormPage({super.key, this.driver});

  /// null — режим создания, иначе редактирование.
  final Driver? driver;

  bool get isEdit => driver != null;

  @override
  State<DriverFormPage> createState() => _DriverFormPageState();
}

class _DriverFormPageState extends State<DriverFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _password;

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _saving = false;
  String? _error;

  // Правила живут в полях, чтобы поле и переход к первой ошибке
  // проверялись одним и тем же кодом.
  static final _nameRule = Validators.all([
    Validators.notEmpty('Введите имя водителя'),
    Validators.maxLen(120),
  ]);
  static final _emailRule = Validators.all([
    Validators.email,
    Validators.maxLen(120),
  ]);
  static final _passwordRule = Validators.password();

  @override
  void initState() {
    super.initState();
    final driver = widget.driver;
    _name = TextEditingController(text: driver?.fullName ?? '');
    // У нового водителя в поле уже стоит код страны — его не надо набирать.
    _phone = TextEditingController(
      text: driver == null ? UzPhone.prefix : UzPhone.format(driver.phone),
    );
    _email = TextEditingController(text: driver?.email ?? '');
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Форму меняли — уход без сохранения нужно подтвердить.
  bool get _dirty {
    final driver = widget.driver;
    return _name.text.trim() != (driver?.fullName ?? '') ||
        UzPhone.normalize(_phone.text) !=
            UzPhone.normalize(driver?.phone ?? '') ||
        _email.text.trim() != (driver?.email ?? '') ||
        _password.text.isNotEmpty;
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
      (_emailFocus, _emailRule(_email.text)),
      // Пароль задаётся только при создании — это учётная запись водителя.
      if (!widget.isEdit) (_passwordFocus, _passwordRule(_password.text)),
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
        await repo.updateDriver(widget.driver!.copyWith(
          fullName: _name.text.trim(),
          phone: phone,
          email: _email.text.trim(),
        ));
      } else {
        await repo.addDriver(
          fullName: _name.text.trim(),
          phone: phone,
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      // Сервер может отклонить и валидные с виду данные: занятый телефон
      // или почта, упавшая сеть. Экран обязан ожить, а не остаться
      // с серой кнопкой.
      _failed(apiErrorMessage(e, fallback: _saveErrorText));
    } catch (_) {
      _failed(_saveErrorText);
    }
  }

  static const _saveErrorText = 'Не удалось сохранить водителя.';

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
    // В режиме редактирования почта — последнее поле формы.
    final emailIsLast = widget.isEdit;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: DetailScaffold(
        title: widget.isEdit ? 'Редактирование водителя' : 'Новый водитель',
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.lg,
            children: [
              LabeledTextField(
                label: 'Имя водителя',
                hint: 'Например, Азиз Каримов',
                controller: _name,
                focusNode: _nameFocus,
                validator: _nameRule,
                maxLength: 120,
                autofocus: !widget.isEdit,
                autofillHints: const [AutofillHints.name],
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
                onSubmitted: (_) => _emailFocus.requestFocus(),
              ),
              LabeledTextField(
                label: 'Электронная почта',
                hint: 'driver@aqua.uz',
                helper: 'Необязательно',
                controller: _email,
                focusNode: _emailFocus,
                validator: _emailRule,
                keyboardType: TextInputType.emailAddress,
                maxLength: 120,
                autofillHints: const [AutofillHints.email],
                textInputAction:
                    emailIsLast ? TextInputAction.done : TextInputAction.next,
                onSubmitted: (_) =>
                    emailIsLast ? _submit() : _passwordFocus.requestFocus(),
              ),
              if (!widget.isEdit)
                LabeledTextField(
                  label: 'Пароль для входа',
                  hint: '••••••••',
                  helper: 'Минимум 6 символов',
                  controller: _password,
                  focusNode: _passwordFocus,
                  validator: _passwordRule,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
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

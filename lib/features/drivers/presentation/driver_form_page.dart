import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/product_config.dart';
import '../../../core/utils/idempotency.dart';
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

class _DriverFormPageState extends State<DriverFormPage> with SubmitState {
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
  late final TextEditingController _password;

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();


  /// Один ключ на весь экран: повтор после обрыва связи не должен завести
  /// второго водителя. При редактировании не нужен — PATCH и так идемпотентен.
  final String _idempotencyKey = newIdempotencyKey('driver');

  // Правила живут в полях, чтобы поле и переход к первой ошибке
  // проверялись одним и тем же кодом.
  FormFieldValidator<String> get _nameRule => Validators.all([
    _v.notEmpty(context.l10n.driverFormNameEmpty),
    _v.maxLen(120),
  ]);
  FormFieldValidator<String> get _passwordRule => _v.password();

  /// Заготовка пароля для новой учётки — см. [ProductConfig].
  static const String _defaultPassword = ProductConfig.defaultDriverPassword;

  @override
  void initState() {
    super.initState();
    final driver = widget.driver;
    _name = TextEditingController(text: driver?.fullName ?? '');
    // У нового водителя в поле уже стоит код страны — его не надо набирать.
    _phone = TextEditingController(
      text: driver == null ? UzPhone.prefix : UzPhone.format(driver.phone),
    );
    // Стартовый пароль подставлен заранее: сбросить его админ потом не сможет
    // (эндпоинта нет), а водитель меняет его сам после первого входа.
    // Значение можно перебить прямо в поле.
    _password = TextEditingController(
      text: driver == null ? _defaultPassword : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Форму меняли — уход без сохранения нужно подтвердить.
  bool get _dirty {
    final driver = widget.driver;
    return _name.text.trim() != (driver?.fullName ?? '') ||
        UzPhone.normalize(_phone.text) !=
            UzPhone.normalize(driver?.phone ?? '') ||
        // При создании пароль уже заполнен заготовкой — «грязной» форму делает
        // только его правка, иначе выход сразу спрашивал бы подтверждение.
        _password.text != (driver == null ? _defaultPassword : '');
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
        // Пароль задаётся только при создании — это учётная запись водителя.
        if (!widget.isEdit) (_passwordFocus, _passwordRule(_password.text)),
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
          ? repo.updateDriver(widget.driver!.copyWith(
              fullName: _name.text.trim(),
              phone: phone,
            ))
          : repo.addDriver(
              fullName: _name.text.trim(),
              phone: phone,
              password: _password.text,
              idempotencyKey: _idempotencyKey,
            ),
      // Сервер может отклонить и валидные с виду данные: занятый телефон,
      // упавшая сеть.
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.driverFormSaveFailed)
          : l10n.driverFormSaveFailed,
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
        title: widget.isEdit ? context.l10n.driverFormEditTitle : context.l10n.driverFormNewTitle,
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
                label: context.l10n.driverFormName,
                hint: context.l10n.driverFormNameHint,
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
                label: context.l10n.loginPhone,
                hint: '+998 90 123 45 67',
                controller: _phone,
                focusNode: _phoneFocus,
                validator: _v.phone,
                keyboardType: TextInputType.phone,
                inputFormatters: const [UzPhoneInputFormatter()],
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction:
                    widget.isEdit ? TextInputAction.done : TextInputAction.next,
                onSubmitted: (_) =>
                    widget.isEdit ? _submit() : _passwordFocus.requestFocus(),
              ),
              if (!widget.isEdit)
                LabeledTextField(
                  label: context.l10n.driverFormPassword,
                  hint: '••••••••',
                  // Объясняем заготовку: иначе непонятно, откуда взялся пароль
                  // и что водителю его потом менять.
                  helper: context.l10n.driverFormPasswordHelper,
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

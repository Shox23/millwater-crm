import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/utils/driver_password.dart';
import '../../../core/utils/idempotency.dart';
import '../../../core/utils/uz_phone.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/driver.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/crm_repository.dart';
import '../theme/desktop_typography.dart';
import '../widgets/desktop_button.dart';
import '../widgets/desktop_segmented.dart';
import 'desktop_modals.dart';

/// Форма водителя в модальном окне.
///
/// Валидация и работа с сетью — те же, что на мобильном экране: `Validators`
/// по строкам локали, миксин [SubmitState] и один ключ идемпотентности на
/// всю форму. Отличается только раскладка: телефон и пароль стоят в ряд,
/// потому что на 520px им хватает места по половине.
class DriverFormModal extends StatefulWidget {
  const DriverFormModal({super.key, this.driver});

  /// null — создание, иначе правка.
  final Driver? driver;

  bool get isEdit => driver != null;

  @override
  State<DriverFormModal> createState() => _DriverFormModalState();
}

class _DriverFormModalState extends State<DriverFormModal> with SubmitState {
  late Validators _v;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _password;

  /// Повтор после обрыва связи не должен завести второго водителя.
  final String _idempotencyKey = newIdempotencyKey('driver');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _v = Validators(context.l10n);
  }

  @override
  void initState() {
    super.initState();
    final driver = widget.driver;
    _name = TextEditingController(text: driver?.fullName ?? '');
    _phone = TextEditingController(
      text: driver == null ? UzPhone.prefix : UzPhone.format(driver.phone),
    );
    // Сгенерированный пароль подставлен заранее и виден админу до отправки:
    // сбросить его потом не сможет никто, эндпоинта нет. Водитель меняет его
    // сам после первого входа.
    _password = TextEditingController(
      text: driver == null ? DriverPassword.generate() : '',
    );
    _name.addListener(_onChanged);
  }

  @override
  void dispose() {
    _name.removeListener(_onChanged);
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Кнопка оживает вместе с именем — см. [_canSave].
  void _onChanged() => setState(() {});

  bool get _canSave => _name.text.trim().isNotEmpty && !submitting;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final repo = context.read<CrmRepository>();
    final l10n = context.l10n;
    final phone = UzPhone.normalize(_phone.text);
    final name = _name.text.trim();

    final ok = await submit(
      () async {
        if (widget.isEdit) {
          await repo.updateDriver(
            widget.driver!.copyWith(fullName: name, phone: phone),
          );
        } else {
          await repo.addDriver(
            fullName: name,
            phone: phone,
            password: _password.text,
            idempotencyKey: _idempotencyKey,
          );
        }
      },
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.driverFormSaveFailed)
          : l10n.driverFormSaveFailed,
    );

    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return DesktopModalPanel(
      title: widget.isEdit ? l10n.driverFormEditTitle : l10n.driverFormNewTitle,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.lg,
          children: [
            LabeledTextField(
              label: l10n.driverFormName,
              hint: l10n.driverFormNameHint,
              controller: _name,
              validator: Validators.all([
                _v.notEmpty(l10n.driverFormNameEmpty),
                _v.maxLen(120),
              ]),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.lg,
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: l10n.commonPhone,
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [UzPhoneInputFormatter()],
                    validator: _v.phone,
                  ),
                ),
                Expanded(
                  child: widget.isEdit
                      // Пароль меняет только сам водитель — в правке поля нет.
                      ? const SizedBox.shrink()
                      : LabeledTextField(
                          label: l10n.driverFormPassword,
                          helper: l10n.driverFormPasswordHelper,
                          controller: _password,
                          validator: _v.password(),
                          // Пароль сгенерирован и восстановить его нечем —
                          // без копирования его пришлось бы переписывать.
                          copyable: true,
                        ),
                ),
              ],
            ),
            if (submitError != null) _ErrorText(text: submitError!),
          ],
        ),
      ),
      footer: _FormFooter(canSave: _canSave, onSave: _save, saving: submitting),
    );
  }
}

/// Форма заказчика в модальном окне.
class CustomerFormModal extends StatefulWidget {
  const CustomerFormModal({super.key, this.customer});

  final Customer? customer;

  bool get isEdit => customer != null;

  @override
  State<CustomerFormModal> createState() => _CustomerFormModalState();
}

class _CustomerFormModalState extends State<CustomerFormModal>
    with SubmitState {
  late Validators _v;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _comment;
  late bool _hasCooler;

  final String _idempotencyKey = newIdempotencyKey('customer');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _v = Validators(context.l10n);
  }

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer?.name ?? '');
    _phone = TextEditingController(
      text: customer == null ? UzPhone.prefix : UzPhone.format(customer.phone),
    );
    _address = TextEditingController(text: customer?.address ?? '');
    _comment = TextEditingController(text: customer?.comment ?? '');
    _hasCooler = customer?.hasCooler ?? false;
    _name.addListener(_onChanged);
  }

  @override
  void dispose() {
    _name.removeListener(_onChanged);
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _comment.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _canSave => _name.text.trim().isNotEmpty && !submitting;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final repo = context.read<CrmRepository>();
    final l10n = context.l10n;
    final phone = UzPhone.normalize(_phone.text);
    final comment = _comment.text.trim();

    final ok = await submit(
      () async {
        if (widget.isEdit) {
          await repo.updateCustomer(widget.customer!.copyWith(
            name: _name.text.trim(),
            phone: phone,
            address: _address.text.trim(),
            comment: comment.isEmpty ? null : comment,
            hasCooler: _hasCooler,
          ));
        } else {
          await repo.addCustomer(
            name: _name.text.trim(),
            phone: phone,
            address: _address.text.trim(),
            comment: comment.isEmpty ? null : comment,
            hasCooler: _hasCooler,
            idempotencyKey: _idempotencyKey,
          );
        }
      },
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.customerFormSaveFailed)
          : l10n.customerFormSaveFailed,
    );

    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return DesktopModalPanel(
      title:
          widget.isEdit ? l10n.customerFormEditTitle : l10n.customerFormNewTitle,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.lg,
          children: [
            LabeledTextField(
              label: l10n.customerFormName,
              hint: l10n.customerFormNameHint,
              controller: _name,
              validator: Validators.all([
                _v.notEmpty(l10n.customerFormNameEmpty),
                _v.maxLen(160),
              ]),
            ),
            LabeledTextField(
              label: l10n.commonPhone,
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [UzPhoneInputFormatter()],
              validator: _v.phone,
            ),
            // Адрес отдельной строкой: в него влезает «район, улица, дом»,
            // и в половине ширины он обрезался бы на первом же слове.
            LabeledTextField(
              label: l10n.customerFormAddress,
              hint: l10n.customerFormAddressHint,
              controller: _address,
              validator: _v.notEmpty(l10n.customerFormAddressEmpty),
            ),
            // «Тип заказчика» из макета: в API его нет, зато есть кулер —
            // именно он и определяет, что водителю делать на точке.
            // Подпись обязательна: без неё переключатель среди подписанных
            // полей читается как что угодно, только не как кулер.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                Text(
                  l10n.desktopFieldCooler,
                  style: DesktopTypography.secondary.copyWith(
                    color: context.tokens.text2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                DesktopSegmented<bool>(
                  options: [
                    (true, l10n.desktopWithCooler),
                    (false, l10n.desktopWithoutCooler),
                  ],
                  value: _hasCooler,
                  onChanged: (value) => setState(() => _hasCooler = value),
                ),
              ],
            ),
            LabeledTextField(
              label: l10n.customerFormComment,
              hint: l10n.customerFormCommentHint,
              controller: _comment,
            ),
            if (submitError != null) _ErrorText(text: submitError!),
          ],
        ),
      ),
      footer: _FormFooter(canSave: _canSave, onSave: _save, saving: submitting),
    );
  }
}

class _FormFooter extends StatelessWidget {
  const _FormFooter({
    required this.canSave,
    required this.onSave,
    required this.saving,
  });

  final bool canSave;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      spacing: AppSpacing.md,
      children: [
        const Spacer(),
        DesktopButton(
          label: l10n.commonCancel,
          variant: DesktopButtonVariant.soft,
          onPressed: saving ? null : () => Navigator.of(context).pop(),
        ),
        DesktopButton(
          label: saving ? l10n.commonSaving : l10n.commonSave,
          // Пока имени нет, сохранять нечего — кнопка приглушена.
          onPressed: canSave ? onSave : null,
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.dangerBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(text,
          style: DesktopTypography.secondary.copyWith(color: t.danger)),
    );
  }
}

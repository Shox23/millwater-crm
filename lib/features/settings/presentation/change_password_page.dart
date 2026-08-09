import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/auth_repository.dart';

/// Смена собственного пароля.
///
/// Экран общий для админа и водителя: `POST /auth/change-password` работает
/// с учётной записью из токена, а `AuthRepository` лежит над `MaterialApp` и
/// виден обеим оболочкам.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  /// Правила проверки на языке интерфейса. Пересобираются при смене
  /// локали: `didChangeDependencies` вызывается снова.
  late Validators _v;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _v = Validators(context.l10n);
  }

  final _formKey = GlobalKey<FormState>();

  final _current = TextEditingController();
  final _fresh = TextEditingController();
  final _repeat = TextEditingController();

  final _currentFocus = FocusNode();
  final _freshFocus = FocusNode();
  final _repeatFocus = FocusNode();

  bool _saving = false;
  String? _error;

  FormFieldValidator<String> get _currentRule => _v.notEmpty(context.l10n.passwordCurrentEmpty);
  FormFieldValidator<String> get _passwordRule => _v.password();

  @override
  void dispose() {
    _current.dispose();
    _fresh.dispose();
    _repeat.dispose();
    _currentFocus.dispose();
    _freshFocus.dispose();
    _repeatFocus.dispose();
    super.dispose();
  }

  /// Новый пароль обязан отличаться от текущего — иначе сервер примет запрос,
  /// а пользователь решит, что пароль сменился.
  String? _freshRule(String? value) {
    final error = _passwordRule(value);
    if (error != null) return error;
    if ((value ?? '') == _current.text) {
      return context.l10n.passwordSameAsCurrent;
    }
    return null;
  }

  String? _repeatRule(String? value) {
    if ((value ?? '').isEmpty) return context.l10n.passwordRepeat;
    if (value != _fresh.text) return context.l10n.passwordMismatch;
    return null;
  }

  bool get _dirty =>
      _current.text.isNotEmpty ||
      _fresh.text.isNotEmpty ||
      _repeat.text.isNotEmpty;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      _focusFirstInvalid();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().changePassword(
            oldPassword: _current.text,
            newPassword: _fresh.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      _failed(_messageFor(e));
    } catch (_) {
      _failed(_fallback);
    }
  }

  /// Поля и их текущие ошибки — один источник и для кнопки, и для перехода
  /// к первой ошибке.
  List<(FocusNode, String?)> get _checks => [
        (_currentFocus, _currentRule(_current.text)),
        (_freshFocus, _freshRule(_fresh.text)),
        (_repeatFocus, _repeatRule(_repeat.text)),
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

  String get _fallback => context.l10n.passwordChangeFailed;

  /// Отказ сервера здесь означает одно: текущий пароль не подошёл.
  ///
  /// Обновлением токена такой ответ не лечится, и это к лучшему: интерсептор
  /// не трогает `/auth/*`, поэтому опечатка в пароле не может выйти боком —
  /// неудачный refresh разлогинил бы пользователя посреди формы.
  String _messageFor(DioException e) {
    final code = e.response?.statusCode;
    if (code == 400 || code == 401 || code == 403) {
      return context.l10n.passwordWrongCurrent;
    }
    return apiErrorMessage(context.l10n, e, fallback: _fallback);
  }

  void _failed(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  /// Закрытие формы: введённый пароль терять молча нельзя.
  Future<void> _leave() async {
    if (!_dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    final leave = await showConfirmDialog(
      context,
      title: context.l10n.leaveWithoutSavingTitle,
      message: context.l10n.passwordKeepMessage,
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
        title: context.l10n.passwordChangeTitle,
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
                label: context.l10n.passwordCurrent,
                hint: '••••••••',
                controller: _current,
                focusNode: _currentFocus,
                validator: _currentRule,
                obscureText: true,
                autofocus: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _freshFocus.requestFocus(),
              ),
              LabeledTextField(
                label: context.l10n.passwordNew,
                hint: '••••••••',
                helper: context.l10n.minSixChars,
                controller: _fresh,
                focusNode: _freshFocus,
                validator: _freshRule,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _repeatFocus.requestFocus(),
              ),
              LabeledTextField(
                label: context.l10n.passwordRepeat,
                hint: '••••••••',
                controller: _repeat,
                focusNode: _repeatFocus,
                validator: _repeatRule,
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
                      label: context.l10n.commonCancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: _saving ? null : _leave,
                    ),
                  ),
                  Expanded(
                    child: AppButton(
                      label: _saving ? context.l10n.commonSaving : context.l10n.passwordSubmit,
                      // Пока в форме есть ошибки, отправлять нечего.
                      enabled: _valid && !_saving,
                      onPressed: (_valid && !_saving) ? _submit : null,
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

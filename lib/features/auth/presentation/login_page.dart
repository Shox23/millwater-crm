import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/uz_phone.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// Правила проверки на языке интерфейса. Пересобираются при смене
  /// локали: `didChangeDependencies` вызывается снова.
  late Validators _v;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _v = Validators(context.l10n);
  }

  final _formKey = GlobalKey<FormState>();

  final _phone = TextEditingController(text: UzPhone.prefix);
  final _password = TextEditingController();

  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();

  FormFieldValidator<String> get _passwordRule => _v.notEmpty(context.l10n.fieldPasswordEmpty);

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Поля и их текущие ошибки — один источник и для кнопки, и для перехода
  /// к первой ошибке.
  List<(FocusNode, String?)> get _checks => [
        (_phoneFocus, _v.phone(_phone.text)),
        (_passwordFocus, _passwordRule(_password.text)),
      ];

  /// Телефон и пароль заполнены — кнопку можно разблокировать.
  bool get _valid => _checks.every((c) => c.$2 == null);

  void _submit() {
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
    context.read<AuthBloc>().add(
          AuthLoginRequested(
            phone: UzPhone.normalize(_phone.text),
            password: _password.text,
          ),
        );
  }

  /// Текст ошибки входа: блок отдаёт причину кодом, язык знает экран.
  String _errorText(BuildContext context, AuthError error) => switch (error) {
        AuthError.credentials => context.l10n.loginErrorCredentials,
        AuthError.generic => context.l10n.loginErrorGeneric,
        AuthError.failed => context.l10n.loginErrorFailed,
        AuthError.sessionExpired => context.l10n.sessionExpired,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final loading = state.status == AuthStatus.authenticating;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.lg,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t.primary,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: t.accentShadow,
                        ),
                        child: const Icon(Icons.water_drop_rounded,
                            color: Colors.white, size: 32),
                      ),
                    ),
                    Column(
                      spacing: 4,
                      children: [
                        Text(context.l10n.appTitle,
                            style: AppTypography.screenTitle
                                .copyWith(color: t.text),
                            textAlign: TextAlign.center),
                        // Роль определяется по ответу сервера — на этом
                        // экране входят и администратор, и водитель.
                        Text(context.l10n.loginTitle,
                            style: AppTypography.secondary
                                .copyWith(color: t.text2),
                            textAlign: TextAlign.center),
                      ],
                    ),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Form(
                        key: _formKey,
                        // Ошибка появляется, когда поле закончили заполнять
                        // и ушли из него.
                        autovalidateMode: AutovalidateMode.onUnfocus,
                        // Любое изменение — пересчёт состояния кнопки.
                        onChanged: () => setState(() {}),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: AppSpacing.lg,
                          children: [
                            LabeledTextField(
                              label: context.l10n.loginPhone,
                              hint: '+998 90 123 45 67',
                              controller: _phone,
                              focusNode: _phoneFocus,
                              validator: _v.phone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: const [UzPhoneInputFormatter()],
                              autofillHints: const [
                                AutofillHints.telephoneNumber
                              ],
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                            ),
                            LabeledTextField(
                              label: context.l10n.loginPassword,
                              hint: '••••••••',
                              controller: _password,
                              focusNode: _passwordFocus,
                              validator: _passwordRule,
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                            ),
                            if (state.status == AuthStatus.failure &&
                                state.error != null)
                              Text(
                                _errorText(context, state.error!),
                                style: AppTypography.secondary
                                    .copyWith(color: t.danger),
                              ),
                            AppButton(
                              label: loading ? context.l10n.loginSubmitting : context.l10n.loginSubmit,
                              // Пока телефон или пароль не заполнены,
                              // отправлять нечего.
                              enabled: _valid && !loading,
                              onPressed: (_valid && !loading) ? _submit : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

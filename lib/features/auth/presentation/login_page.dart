import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  final _formKey = GlobalKey<FormState>();

  final _phone = TextEditingController(text: UzPhone.prefix);
  final _password = TextEditingController();

  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();

  static final _passwordRule = Validators.notEmpty('Введите пароль');

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (Validators.phone(_phone.text) != null) {
        _phoneFocus.requestFocus();
      } else {
        _passwordFocus.requestFocus();
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
                        Text('CRM Millwater',
                            style: AppTypography.screenTitle
                                .copyWith(color: t.text),
                            textAlign: TextAlign.center),
                        Text('Вход для администратора',
                            style: AppTypography.secondary
                                .copyWith(color: t.text2),
                            textAlign: TextAlign.center),
                      ],
                    ),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: AppSpacing.lg,
                          children: [
                            LabeledTextField(
                              label: 'Номер телефона',
                              hint: '+998 90 123 45 67',
                              controller: _phone,
                              focusNode: _phoneFocus,
                              validator: Validators.phone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: const [UzPhoneInputFormatter()],
                              autofillHints: const [
                                AutofillHints.telephoneNumber
                              ],
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                            ),
                            LabeledTextField(
                              label: 'Пароль',
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
                                state.error!,
                                style: AppTypography.secondary
                                    .copyWith(color: t.danger),
                              ),
                            AppButton(
                              label: loading ? 'Вход…' : 'Войти',
                              enabled: !loading,
                              onPressed: loading ? null : _submit,
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

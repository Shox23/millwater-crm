import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../theme/desktop_theme.dart';
import '../theme/desktop_typography.dart';
import '../widgets/desktop_button.dart';

/// Что видит водитель, открывший приложение на широком экране.
///
/// Десктоп — рабочее место администратора: водительские экраны рассчитаны на
/// телефон в руке у подъезда, и растягивать их на 1728px незачем. Выход
/// оставлен: иначе на чужой машине не сменить учётку.
class DriverDesktopStub extends StatelessWidget {
  const DriverDesktopStub({super.key});

  @override
  Widget build(BuildContext context) {
    return DesktopTheme(child: Builder(builder: _build));
  }

  Widget _build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.lg,
            children: [
              Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(Icons.smartphone_outlined,
                    size: 32, color: t.primary),
              ),
              Text(
                context.l10n.desktopDriverStubTitle,
                textAlign: TextAlign.center,
                style: DesktopTypography.sectionTitle.copyWith(color: t.text),
              ),
              Text(
                context.l10n.desktopDriverStubHint,
                textAlign: TextAlign.center,
                style: DesktopTypography.body.copyWith(color: t.text2),
              ),
              DesktopButton(
                label: context.l10n.settingsLogout,
                variant: DesktopButtonVariant.soft,
                onPressed: () =>
                    context.read<AuthBloc>().add(const AuthLogoutRequested()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

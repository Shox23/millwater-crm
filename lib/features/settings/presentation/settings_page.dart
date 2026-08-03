import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/theme/theme_cubit.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/segmented_toggle.dart';
import '../../auth/bloc/auth_bloc.dart';

/// Настройки: тема и выход из аккаунта.
///
/// До этого переключатель темы жил в шапке «Маршрутов», а выйти из аккаунта
/// было нельзя вообще — событие в блоке было, кнопки не было.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Выйти из аккаунта?',
      message: 'Придётся войти заново по номеру телефона и паролю.',
      confirmLabel: 'Выйти',
    );
    if (!confirmed || !context.mounted) return;
    context.read<AuthBloc>().add(const AuthLogoutRequested());
    // Возврат на логин делает корневой BlocBuilder по состоянию авторизации.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mode = context.watch<ThemeCubit>().state;

    return DetailScaffold(
      title: 'Настройки',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          _Section(
            label: 'ОФОРМЛЕНИЕ',
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.md,
                children: [
                  Row(
                    spacing: AppSpacing.md,
                    children: [
                      Icon(ThemeCubit.iconFor(mode), size: 20, color: t.primary),
                      Expanded(
                        child: Text(
                          'Тема · ${ThemeCubit.labelFor(mode)}',
                          style:
                              AppTypography.bodyStrong.copyWith(color: t.text),
                        ),
                      ),
                    ],
                  ),
                  SegmentedToggle<ThemeMode>(
                    value: mode,
                    columns: 3,
                    onChanged: (m) => context.read<ThemeCubit>().select(m),
                    options: const [
                      SegmentOption(
                          value: ThemeMode.system, label: 'Система'),
                      SegmentOption(value: ThemeMode.light, label: 'Светлая'),
                      SegmentOption(value: ThemeMode.dark, label: 'Тёмная'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _Section(
            label: 'АККАУНТ',
            child: AppCard(
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.softOf(t.primary),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.shield_outlined,
                        size: 20, color: t.primary),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text('Администратор',
                            style: AppTypography.bodyStrong
                                .copyWith(color: t.text)),
                        Text('Сессия активна',
                            style: AppTypography.secondary
                                .copyWith(color: t.text2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.md,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: AppButton(
          label: 'Выйти из аккаунта',
          icon: Icons.logout_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: () => _logout(context),
        ),
      ),
    );
  }
}

/// Блок настроек: капс-подпись и содержимое.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Text(label, style: AppTypography.fieldLabel.copyWith(color: t.text2)),
        child,
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/uz_phone.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/section_block.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../settings/presentation/widgets/change_password_tile.dart';
import '../../settings/presentation/widgets/language_selector_card.dart';
import '../../settings/presentation/widgets/theme_selector_card.dart';

/// Профиль водителя: учётная запись, тема и выход.
class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  UserResponse? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await context.read<AuthRepository>().me();
      if (mounted) setState(() => _user = user);
    } catch (_) {
      // Профиль — не критичный экран: без данных просто покажем роль
      // из сессии, выход из аккаунта продолжит работать.
    }
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.settingsLogoutTitle,
      message: context.l10n.settingsLogoutMessage,
      confirmLabel: context.l10n.commonLeave,
    );
    if (!confirmed || !mounted) return;
    // Возврат на логин делает корневой BlocBuilder по состоянию авторизации.
    context.read<AuthBloc>().add(const AuthLogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final user = _user;
    final phone = user == null ? '—' : UzPhone.format(user.phone);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.lg,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            ScreenHeader(
                label: context.l10n.profileAccountLabel,
                title: context.l10n.profileTitle),
            const SizedBox(height: AppSpacing.lg),
            SectionBlock(
              label: context.l10n.profileAccountSection,
              child: Column(
                spacing: AppSpacing.sm,
                children: [
                  AppCard(
                    child: Row(
                      spacing: AppSpacing.md,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.softOf(t.primary),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(Icons.local_shipping_outlined,
                              size: 22, color: t.primary),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              Text(context.l10n.driverTitle,
                                  style: AppTypography.bodyStrong
                                      .copyWith(color: t.text)),
                              Text(phone,
                                  style: AppTypography.secondary
                                      .copyWith(color: t.text2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const ChangePasswordTile(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionBlock(
              label: context.l10n.languageSection,
              child: const LanguageSelectorCard(),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionBlock(
              label: context.l10n.settingsAppearance,
              child: const ThemeSelectorCard(),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: context.l10n.settingsLogout,
              icon: Icons.logout_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

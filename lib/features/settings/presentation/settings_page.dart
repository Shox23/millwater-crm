import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/section_block.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../prices/presentation/prices_page.dart';
import 'widgets/change_password_tile.dart';
import 'widgets/language_selector_card.dart';
import 'widgets/theme_selector_card.dart';

/// Настройки администратора: прайс, тема, пароль и выход из аккаунта.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.settingsLogoutTitle,
      message: context.l10n.settingsLogoutMessage,
      confirmLabel: context.l10n.commonLeave,
    );
    if (!confirmed || !context.mounted) return;
    context.read<AuthBloc>().add(const AuthLogoutRequested());
    // Возврат на логин делает корневой BlocBuilder по состоянию авторизации.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return DetailScaffold(
      title: context.l10n.settingsTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          SectionBlock(
            label: context.l10n.pricesSection,
            child: const _PricesTile(),
          ),
          SectionBlock(
            label: context.l10n.languageSection,
            child: const LanguageSelectorCard(),
          ),
          SectionBlock(
            label: context.l10n.settingsAppearance,
            child: const ThemeSelectorCard(),
          ),
          SectionBlock(
            label: context.l10n.settingsAccount,
            child: Column(
              spacing: AppSpacing.sm,
              children: [
                AppCard(
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
                            Text(context.l10n.roleAdmin,
                                style: AppTypography.bodyStrong
                                    .copyWith(color: t.text)),
                            Text(context.l10n.settingsSessionActive,
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
          label: context.l10n.settingsLogout,
          icon: Icons.logout_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: () => _logout(context),
        ),
      ),
    );
  }
}

/// Пункт «Цены» — открывает [PricesPage].
///
/// Живёт в настройках админа: экран ходит в `/admin/prices/*`, водителю они
/// закрыты, да и настройки открываются только из админской оболочки.
class _PricesTile extends StatelessWidget {
  const _PricesTile();

  Future<void> _open(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      OverlayPageRoute(builder: (_) => const PricesPage()),
    );
    if (changed == true && context.mounted) {
      showAppSnackBar(context, context.l10n.pricesUpdated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      onTap: () => _open(context),
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
            child: Icon(Icons.sell_outlined, size: 20, color: t.primary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(context.l10n.pricesTitle,
                    style: AppTypography.bodyStrong.copyWith(color: t.text)),
                Text(context.l10n.pricesTileHint,
                    style: AppTypography.secondary.copyWith(color: t.text2)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.text2),
        ],
      ),
    );
  }
}

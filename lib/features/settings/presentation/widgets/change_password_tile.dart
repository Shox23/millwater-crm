import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/overlay_route.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../../core/widgets/app_card.dart';
import '../change_password_page.dart';

/// Пункт «Сменить пароль» — открывает [ChangePasswordPage].
///
/// Один и тот же в настройках админа и в профиле водителя: эндпоинт меняет
/// пароль той учётной записи, чей токен ушёл в запрос.
class ChangePasswordTile extends StatelessWidget {
  const ChangePasswordTile({super.key});

  Future<void> _open(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      OverlayPageRoute(builder: (_) => const ChangePasswordPage()),
    );
    if (changed == true && context.mounted) {
      showAppSnackBar(context, context.l10n.passwordChanged);
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
            child: Icon(Icons.key_outlined, size: 20, color: t.primary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(context.l10n.passwordChangeTile,
                    style: AppTypography.bodyStrong.copyWith(color: t.text)),
                Text(context.l10n.passwordChangeTileHint,
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

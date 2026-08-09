import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/theme_cubit.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/segmented_toggle.dart';

/// Карточка выбора темы — общая для настроек админа и профиля водителя.
class ThemeSelectorCard extends StatelessWidget {
  const ThemeSelectorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mode = context.watch<ThemeCubit>().state;

    return AppCard(
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
                  context.l10n.themeTitle(ThemeCubit.labelFor(context.l10n, mode)),
                  style: AppTypography.bodyStrong.copyWith(color: t.text),
                ),
              ),
            ],
          ),
          SegmentedToggle<ThemeMode>(
            value: mode,
            columns: 3,
            onChanged: (m) => context.read<ThemeCubit>().select(m),
            options: [
              SegmentOption(
                  value: ThemeMode.system, label: context.l10n.themeSystemShort),
              SegmentOption(
                  value: ThemeMode.light, label: context.l10n.themeLight),
              SegmentOption(
                  value: ThemeMode.dark, label: context.l10n.themeDark),
            ],
          ),
        ],
      ),
    );
  }
}

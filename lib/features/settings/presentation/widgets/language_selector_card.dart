import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/locale_cubit.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/segmented_toggle.dart';
import '../../../../l10n/l10n.dart';

/// Карточка выбора языка — общая для настроек админа и профиля водителя.
///
/// Третьего варианта «как в системе» здесь нет намеренно: язык телефона и так
/// подставляется при первом запуске, а водителю нужен понятный выбор из двух,
/// а не объяснение, что показывается сейчас и почему.
class LanguageSelectorCard extends StatelessWidget {
  const LanguageSelectorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    // Фактический язык, а не выбранный: при `null` в кубите показывается
    // системный, и подпись должна говорить именно о нём.
    final current = Localizations.localeOf(context).languageCode;
    final name = current == AppLocales.uz.languageCode
        ? l10n.languageUzbek
        : l10n.languageRussian;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Row(
            spacing: AppSpacing.md,
            children: [
              Icon(Icons.translate_outlined, size: 20, color: t.primary),
              Expanded(
                child: Text(
                  l10n.languageTitle(name),
                  style: AppTypography.bodyStrong.copyWith(color: t.text),
                ),
              ),
            ],
          ),
          SegmentedToggle<String>(
            value: current,
            columns: 2,
            onChanged: (code) => context.read<LocaleCubit>().select(
                  code == AppLocales.uz.languageCode
                      ? AppLocales.uz
                      : AppLocales.ru,
                ),
            options: [
              SegmentOption(
                value: AppLocales.ru.languageCode,
                label: l10n.languageRussian,
              ),
              SegmentOption(
                value: AppLocales.uz.languageCode,
                label: l10n.languageUzbek,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

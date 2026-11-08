import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/locale_cubit.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/theme_cubit.dart';

/// Высота обоих переключателей: рядом они должны читаться одной полосой.
const double _height = 40;

/// Язык и тема прямо на экране входа.
///
/// До входа профиль с настройками недоступен, а водитель, который не читает
/// по-русски, должен переключиться на узбекский раньше, чем разберёт форму.
/// Поэтому язык — открытым переключателем `RU | UZ` без меню: коды языков
/// понятны без перевода. Тема нужна реже и убрана в меню из трёх пунктов.
/// Выбор сохраняется так же, как из профиля, — через те же кубиты.
class LoginPreferences extends StatelessWidget {
  const LoginPreferences({super.key});

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.sm,
        children: [_LanguageSwitch(), _ThemeMenu()],
      );
}

class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    // Фактический язык, а не выбранный: при `null` в кубите показывается
    // системный, и подсвечен должен быть именно он.
    final current = Localizations.localeOf(context).languageCode;

    Widget segment(Locale locale, String code, String name) {
      final selected = current == locale.languageCode;
      return Semantics(
        button: true,
        selected: selected,
        // Читалке экрана — полное название, а не «R U».
        label: name,
        excludeSemantics: true,
        child: InkWell(
          // Нажатие на уже подсвеченный язык тоже запоминает выбор. Без
          // выбора подсвечен язык телефона, а водителю после входа
          // по умолчанию достаётся узбекский ([LocaleCubit.defaultFor]):
          // «нажал RU» должно значить «и после входа русский».
          onTap: () => context.read<LocaleCubit>().select(locale),
          mouseCursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            alignment: Alignment.center,
            color: selected ? t.softOf(t.primary) : null,
            child: Text(
              code,
              style: AppTypography.bodyStrong
                  .copyWith(color: selected ? t.primary : t.text2),
            ),
          ),
        ),
      );
    }

    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            segment(AppLocales.ru, 'RU', l10n.languageRussian),
            segment(AppLocales.uz, 'UZ', l10n.languageUzbek),
          ],
        ),
      ),
    );
  }
}

class _ThemeMenu extends StatelessWidget {
  const _ThemeMenu();

  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final mode = context.watch<ThemeCubit>().state;

    return PopupMenuButton<ThemeMode>(
      tooltip: l10n.themeTitle(ThemeCubit.labelFor(l10n, mode)),
      position: PopupMenuPosition.under,
      initialValue: mode,
      onSelected: context.read<ThemeCubit>().select,
      itemBuilder: (_) => [
        for (final m in _modes)
          PopupMenuItem(
            value: m,
            child: Row(
              spacing: AppSpacing.md,
              children: [
                Icon(ThemeCubit.iconFor(m),
                    size: 20, color: m == mode ? t.primary : t.text2),
                Text(
                  ThemeCubit.labelFor(l10n, m),
                  style: AppTypography.body
                      .copyWith(color: m == mode ? t.primary : t.text),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        width: _height,
        height: _height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: t.border),
        ),
        child: Icon(ThemeCubit.iconFor(mode), size: 20, color: t.text2),
      ),
    );
  }
}

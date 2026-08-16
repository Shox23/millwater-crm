import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/l10n.dart';
import '../settings/settings_storage.dart';

/// Режим темы приложения: по умолчанию следует системе.
///
/// Выбор переживает перезапуск: начальное значение приходит из
/// [SettingsStorage] (его читает `main` до запуска приложения), а каждое
/// переключение туда же и записывается.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit({ThemeMode initial = ThemeMode.system, SettingsStorage? storage})
      : _storage = storage ?? const PrefsSettingsStorage(),
        super(initial);

  final SettingsStorage _storage;

  /// Переключает light → dark → system по кругу.
  void toggle() => select(switch (state) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      });

  /// Явный выбор режима — из настроек.
  ///
  /// Запись не ждём: экран перекрашивается сразу, а неудачная запись
  /// означает лишь то, что следующий запуск начнётся с прежнего значения.
  void select(ThemeMode mode) {
    emit(mode);
    _storage.saveThemeMode(mode);
  }

  /// Иконка текущего режима для кнопки переключения.
  static IconData iconFor(ThemeMode mode) => switch (mode) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };

  /// Подпись режима на языке интерфейса.
  static String labelFor(AppLocalizations l10n, ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => l10n.themeSystem,
        ThemeMode.light => l10n.themeLight,
        ThemeMode.dark => l10n.themeDark,
      };
}

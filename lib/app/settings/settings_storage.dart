import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/l10n.dart';

/// Настройки оформления, которые переживают перезапуск.
///
/// Здесь только то, что выбрал пользователь: `null` в [locale] означает
/// «как в системе», [themeMode] по той же причине умеет `system`.
@immutable
class AppSettings {
  const AppSettings({this.themeMode = ThemeMode.system, this.locale});

  final ThemeMode themeMode;
  final Locale? locale;
}

/// Хранилище настроек оформления.
///
/// Отдельное от [SessionStorage]: выход из аккаунта стирает секретное
/// хранилище целиком (`deleteAll`), и язык с темой уехали бы вместе с
/// токенами. К тому же прятать выбор языка в Keychain незачем.
abstract class SettingsStorage {
  Future<AppSettings> load();

  Future<void> saveThemeMode(ThemeMode mode);

  /// `null` — вернуться к системному языку.
  Future<void> saveLocale(Locale? locale);
}

/// Реализация поверх `SharedPreferences` (NSUserDefaults, SharedPreferences,
/// файл настроек на десктопе).
class PrefsSettingsStorage implements SettingsStorage {
  const PrefsSettingsStorage();

  static const _themeKey = 'settings.theme_mode';
  static const _localeKey = 'settings.locale';

  @override
  Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppSettings(
        themeMode: _themeFrom(prefs.getString(_themeKey)),
        locale: _localeFrom(prefs.getString(_localeKey)),
      );
    } catch (e) {
      // Хранилище недоступно — запускаемся с системными настройками.
      _log(e);
      return const AppSettings();
    }
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) =>
      _write((prefs) => prefs.setString(_themeKey, mode.name));

  @override
  Future<void> saveLocale(Locale? locale) => _write((prefs) => locale == null
      ? prefs.remove(_localeKey)
      : prefs.setString(_localeKey, locale.languageCode));

  /// Ошибка записи ничего не ломает: выбор уже применён на экране, а
  /// потеряется он только до следующего переключения. Ронять из-за этого
  /// приложение (и тесты, где плагина нет) нечем.
  Future<void> _write(Future<bool> Function(SharedPreferences) action) async {
    try {
      await action(await SharedPreferences.getInstance());
    } catch (e) {
      _log(e);
    }
  }

  static void _log(Object error) {
    if (kDebugMode) debugPrint('SettingsStorage: $error');
  }

  /// Неизвестное значение (после отката версии или ручной правки) — не повод
  /// падать: возвращаемся к системным настройкам.
  static ThemeMode _themeFrom(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static Locale? _localeFrom(String? code) => AppLocales.supported
      .where((locale) => locale.languageCode == code)
      .firstOrNull;
}

/// Реализация для тестов: хранит выбор в памяти.
class InMemorySettingsStorage implements SettingsStorage {
  InMemorySettingsStorage([this.settings = const AppSettings()]);

  AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async =>
      settings = AppSettings(themeMode: mode, locale: settings.locale);

  @override
  Future<void> saveLocale(Locale? locale) async =>
      settings = AppSettings(themeMode: settings.themeMode, locale: locale);
}

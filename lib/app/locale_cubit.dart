import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/user_role.dart';
import '../l10n/l10n.dart';
import 'settings/settings_storage.dart';

/// Язык интерфейса. `null` — не выбран: язык роли, а без него — системы.
///
/// По умолчанию язык не задан. Водитель получает узбекский (см.
/// [defaultFor]); у остальных телефон с узбекской локалью открывает
/// приложение на узбекском, всё остальное — на русском (см.
/// [AppLocales.fallback]). Явный выбор из настроек перекрывает и роль, и
/// систему.
///
/// Выбор переживает перезапуск: начальное значение читает `main`, каждое
/// переключение уходит в [SettingsStorage].
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit({Locale? initial, SettingsStorage? storage})
      : _storage = storage ?? const PrefsSettingsStorage(),
        super(initial);

  final SettingsStorage _storage;

  /// Явный выбор языка; `null` возвращает к системному.
  ///
  /// Запись не ждём: интерфейс перерисовывается сразу.
  void select(Locale? locale) {
    emit(locale);
    _storage.saveLocale(locale);
  }

  /// Язык, который роль получает без явного выбора; `null` — как в системе.
  ///
  /// Водители в основном читают по-узбекски, а язык телефона у них часто
  /// русский или английский, поэтому их интерфейс открывается на узбекском.
  /// Экран входа роли ещё не знает и остаётся на языке системы.
  static Locale? defaultFor(UserRole? role) => switch (role) {
        UserRole.driver => AppLocales.uz,
        UserRole.admin || null => null,
      };

  /// Какой язык фактически показывается при системной локали [system].
  static Locale resolve(Locale? selected, Locale? system) {
    if (selected != null) return selected;
    final matched = AppLocales.supported
        .where((l) => l.languageCode == system?.languageCode)
        .firstOrNull;
    return matched ?? AppLocales.fallback;
  }
}

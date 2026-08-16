import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/l10n.dart';
import 'settings/settings_storage.dart';

/// Язык интерфейса. `null` — как в системе.
///
/// По умолчанию язык не задан: телефон с узбекской локалью открывает
/// приложение на узбекском, всё остальное — на русском (см.
/// [AppLocales.fallback]). Явный выбор из настроек перекрывает систему.
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

  /// Какой язык фактически показывается при системной локали [system].
  static Locale resolve(Locale? selected, Locale? system) {
    if (selected != null) return selected;
    final matched = AppLocales.supported
        .where((l) => l.languageCode == system?.languageCode)
        .firstOrNull;
    return matched ?? AppLocales.fallback;
  }
}

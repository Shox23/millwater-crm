import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/l10n.dart';

/// Язык интерфейса. `null` — как в системе.
///
/// По умолчанию язык не задан: телефон с узбекской локалью открывает
/// приложение на узбекском, всё остальное — на русском (см.
/// [AppLocales.fallback]). Явный выбор из настроек перекрывает систему.
///
/// Выбор живёт до перезапуска — как и режим темы: своего хранилища
/// настроек у приложения пока нет.
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit() : super(null);

  /// Явный выбор языка; `null` возвращает к системному.
  void select(Locale? locale) => emit(locale);

  /// Какой язык фактически показывается при системной локали [system].
  static Locale resolve(Locale? selected, Locale? system) {
    if (selected != null) return selected;
    final matched = AppLocales.supported
        .where((l) => l.languageCode == system?.languageCode)
        .firstOrNull;
    return matched ?? AppLocales.fallback;
  }
}

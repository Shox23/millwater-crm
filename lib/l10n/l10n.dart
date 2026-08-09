import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// Короткий доступ к строкам интерфейса: `context.l10n.routesTitle`.
///
/// Делегаты подключены в `CrmApp`, поэтому в дереве приложения значение
/// всегда есть. В тестах виджет нужно оборачивать в `MaterialApp` с
/// `AppLocalizations.localizationsDelegates` — иначе здесь будет исключение,
/// и это правильно: экран без строк показывать нечего.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Языки, между которыми переключается приложение.
///
/// Узбекский — в латинице, как принято в интерфейсах Узбекистана.
abstract class AppLocales {
  static const ru = Locale('ru');
  static const uz = Locale('uz');

  static const supported = [ru, uz];

  /// Язык по умолчанию, если системный не поддерживается.
  static const fallback = ru;
}

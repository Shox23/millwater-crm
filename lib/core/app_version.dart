import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Версия установленной сборки — `versionName+versionCode` из самого пакета.
///
/// Заведена после жалобы 07.11: водитель не мог войти, потому что у него
/// стоял APK от сентября, а все сборки назывались `1.0.0+1` — отличить
/// старую от новой не мог ни он, ни мы. Версия читается из пакета, а не
/// дублируется в коде: подпись на экране и User-Agent не разойдутся с тем,
/// что реально установлено.
abstract final class AppVersion {
  static String? _label;

  /// `1.1.0+2`; `null`, пока не прочитана или если платформа не ответила.
  static String? get label => _label;

  /// User-Agent нативных запросов: по нему журнал nginx покажет сборку.
  ///
  /// В вебе `null`: браузер свой User-Agent подменять не даёт, а лишний
  /// заголовок потребовал бы от сервера разрешить его в CORS — и без этого
  /// разрешения отвалились бы все запросы веб-версии.
  static String? get userAgent {
    final label = _label;
    if (kIsWeb || label == null) return null;
    return 'crm_millwater/$label (${defaultTargetPlatform.name})';
  }

  /// Читает версию. Вызывается один раз до первого кадра и не бросает:
  /// без версии приложение работает как раньше, только без подписи.
  ///
  /// Таймаут — для веба: там версия приходит запросом `version.json`, и
  /// плохая связь не должна задерживать старт.
  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform()
          .timeout(const Duration(seconds: 2));
      final version = info.version.trim();
      final build = info.buildNumber.trim();
      _label = version.isEmpty
          ? null
          : (build.isEmpty ? version : '$version+$build');
    } catch (_) {
      _label = null;
    }
  }
}

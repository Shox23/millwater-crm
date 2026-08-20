import 'app/app.dart';
import 'app/settings/settings_storage.dart';
import 'core/observability/observability.dart';

Future<void> main() {
  // Всё, включая чтение настроек, выполняется под наблюдением: упади оно —
  // приложение показало бы белый экран, и причина не дошла бы никуда.
  // `WidgetsFlutterBinding.ensureInitialized()` вызывается внутри.
  return Observability.run(() async {
    // Тема и язык читаются до первого кадра: иначе приложение стартовало бы
    // с системных значений и на глазах у пользователя перекрашивалось.
    const storage = PrefsSettingsStorage();
    final settings = await storage.load();

    return CrmApp(settings: settings, settingsStorage: storage);
  });
}

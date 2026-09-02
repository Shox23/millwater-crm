import 'package:crm_millwater/app/app.dart';
import 'package:crm_millwater/app/settings/settings_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';

/// Точка входа для смоука живого стенда: то же приложение, но управляемое
/// снаружи через flutter_driver.
///
/// Без `Observability.run`, в отличие от `lib/main.dart`, и намеренно: тот
/// поднимает биндинг внутри своей зоны, а `enableFlutterDriverExtension`
/// поднял бы его в корневой — расхождение зон, ровно то, от которого
/// предостерегает комментарий в observability.dart. Наблюдение смоуку и не
/// нужно: проверяются экраны и ответы сервера, а не отправка отчётов.
Future<void> main() async {
  // Первым и до всего остального: расширение поднимает собственный биндинг,
  // и `WidgetsFlutterBinding.ensureInitialized()` перед ним роняет запуск
  // проверкой «Binding is already initialized».
  enableFlutterDriverExtension();

  const storage = PrefsSettingsStorage();
  final settings = await storage.load();

  runApp(CrmApp(settings: settings, settingsStorage: storage));
}

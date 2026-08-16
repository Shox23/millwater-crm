import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/settings/settings_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Тема и язык читаются до первого кадра: иначе приложение стартовало бы
  // с системных значений и на глазах у пользователя перекрашивалось.
  const storage = PrefsSettingsStorage();
  final settings = await storage.load();

  runApp(CrmApp(settings: settings, settingsStorage: storage));
}

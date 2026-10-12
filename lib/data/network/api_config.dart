/// Конфигурация сетевого слоя.
///
/// Адрес сервера можно переопределить через --dart-define=API_BASE_URL=...
abstract class ApiConfig {
  /// Адрес сервера без пути: от него же отдаются загруженные файлы
  /// (`/uploads/...`), см. [fileUrl].
  static const String serverUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://crm.millwater.uz',
  );

  /// С 2026-10-12 всё API живёт под этим префиксом, а старые пути без него
  /// отвечают 404. Статика (`/uploads/...`) осталась в корне — поэтому
  /// префикс не вшит в [serverUrl], и `dart_defines.json` его не содержит.
  static const String apiPath = '/api/v1';

  /// База для запросов к API.
  static const String baseUrl = '$serverUrl$apiPath';

  /// Полный адрес файла с сервера. Сервер отдаёт путь от корня
  /// (`/uploads/payments/….jpg`), но готовый URL тоже пропускаем как есть.
  static String fileUrl(String path) =>
      Uri.parse(serverUrl).resolve(path).toString();

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

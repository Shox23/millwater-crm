/// Конфигурация сетевого слоя.
///
/// Адрес можно переопределить через --dart-define=API_BASE_URL=...
abstract class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://81.162.55.104',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

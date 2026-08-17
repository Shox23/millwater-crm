import 'package:dio/dio.dart';

import '../models/notification_event.dart';
import '../network/dio_client.dart';
import '../network/sse_client.dart';
import 'notifications_repository.dart';

/// Поток уведомлений поверх Water CRM API (SSE через Dio).
///
/// Вся работа с обрывами, докачкой и фоном живёт в [SseClient] — здесь
/// остаётся разбор тела и отсев кадров, которые событием не оказались.
class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository(
    Dio dio, {
    required this.path,
    AuthTokenStore? tokenStore,
  }) : _client = SseClient(
          dio: dio,
          path: path,
          // При 401 поток обновляет токен сам: интерсептор Dio умеет повторить
          // обычный запрос, а здесь «повторить» — это переоткрыть соединение.
          onUnauthorized: tokenStore == null
              ? null
              : () async => await tokenStore.refreshTokens?.call() ?? false,
        );

  /// Админский поток: события по всем водителям.
  ApiNotificationsRepository.admin(Dio dio, {AuthTokenStore? tokenStore})
      : this(dio, path: adminPath, tokenStore: tokenStore);

  /// Водительский поток: только свои доставки и свои маршруты.
  ApiNotificationsRepository.driver(Dio dio, {AuthTokenStore? tokenStore})
      : this(dio, path: driverPath, tokenStore: tokenStore);

  static const adminPath = '/admin/notifications/stream';
  static const driverPath = '/driver/notifications/stream';

  /// Эндпоинт потока. Публичный, чтобы разводку по ролям можно было
  /// проверить тестом, а не доверием к `app.dart`.
  final String path;

  final SseClient _client;

  @override
  late final Stream<NotificationEvent> events = _client.frames
      .map(NotificationEvent.tryFromFrame)
      .where((e) => e != null)
      .cast<NotificationEvent>();

  @override
  Future<void> dispose() => _client.close();
}

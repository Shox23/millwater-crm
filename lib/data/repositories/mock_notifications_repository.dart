import 'dart:async';

import '../models/notification_event.dart';
import 'notifications_repository.dart';

/// In-memory поток уведомлений (демо-режим и тесты).
///
/// Событие присылает сам тест — реакция экранов на него проверяется без
/// сервера и без сокета.
class MockNotificationsRepository implements NotificationsRepository {
  final _controller = StreamController<NotificationEvent>.broadcast();

  @override
  Stream<NotificationEvent> get events => _controller.stream;

  /// Присылает событие подписчикам.
  void emit(NotificationEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  /// Короткая запись для самого частого случая — события про маршрут.
  void emitRouteEvent(
    String routeId, {
    String type = 'delivery_status_updated',
    String? stopId,
  }) {
    emit(NotificationEvent(
      type: type,
      payload: {'route_id': routeId, 'route_customer_id': ?stopId},
    ));
  }

  @override
  Future<void> dispose() => _controller.close();
}

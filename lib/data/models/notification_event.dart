import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../network/sse_client.dart';

/// Событие из потока уведомлений.
///
/// Тип оставлен строкой, а не перечислением: в OpenAPI тело события описано
/// пустым `{}`, список типов нигде не зафиксирован, и появление нового на
/// сервере не должно означать, что клиент перестал обновлять экраны. Реакция
/// у приложения одна на все типы — перечитать то, чего событие касается.
class NotificationEvent extends Equatable {
  const NotificationEvent({
    required this.type,
    this.id,
    this.payload = const {},
    this.createdAt,
  });

  /// Номер события (`id:` в рамке) — им же продолжается поток после обрыва.
  final String? id;

  /// `type` из тела; совпадает с `event:` в рамке.
  final String type;

  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  /// Маршрут, которого касается событие.
  ///
  /// Ради него разбор тела и нужен: с ним экран перечитывает один маршрут,
  /// без него пришлось бы обновлять всё подряд.
  String? get routeId => payload['route_id'] as String?;

  /// Точка маршрута (route_customer_id), если событие про доставку.
  String? get stopId => payload['route_customer_id'] as String?;

  String? get driverId => payload['driver_id'] as String?;

  /// Разбирает кадр; `null` — тело не похоже на событие.
  ///
  /// Мусор в потоке роняет не приложение, а один кадр: между клиентом и
  /// сервером стоит nginx, и страница ошибки от него — не повод молчать до
  /// перезапуска.
  static NotificationEvent? tryFromFrame(SseFrame frame) {
    if (frame.data.isEmpty) return null;
    try {
      final json = jsonDecode(frame.data);
      if (json is! Map) return null;
      final map = json.cast<String, dynamic>();

      // Тип берём из тела, но `event:` в рамке его дублирует — и переживает
      // тело, в котором поля не оказалось.
      final type = (map['type'] as String?) ?? frame.event;
      if (type == null || type.isEmpty) return null;

      final payload = map['payload'];
      final createdAt = map['created_at'];

      return NotificationEvent(
        // Номер из рамки первичен: именно его сервер ждёт в `Last-Event-ID`.
        id: frame.id ?? map['id']?.toString(),
        type: type,
        payload: payload is Map ? payload.cast<String, dynamic>() : const {},
        createdAt:
            createdAt is String ? DateTime.tryParse(createdAt) : null,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object?> get props => [id, type, payload, createdAt];
}

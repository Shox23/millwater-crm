import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/notification_event.dart';
import '../data/repositories/notifications_repository.dart';

/// Доступ к потоку уведомлений своей роли из дерева виджетов.
extension NotificationsScope on BuildContext {
  /// Поток уведомлений или `null`, если его в дереве нет.
  ///
  /// Читается как `T?`, а не обычным `read<T>()`, намеренно: провайдер кладёт
  /// только боевое дерево под своей ролью (см. `app.dart`), а виджет-тесты
  /// собирают экран вокруг одного репозитория — обязательный провайдер
  /// уронил бы их все. Экран без потока просто не обновляется сам; это
  /// рабочее поведение, а не сбой.
  Stream<NotificationEvent>? get notificationEvents =>
      read<NotificationsRepository?>()?.events;
}

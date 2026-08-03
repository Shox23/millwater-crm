/// Статус доставки (остановки маршрута). Значения совпадают с API.
enum DeliveryStatus {
  pending('pending'),
  onWay('on_way'),
  delivered('delivered'),
  failed('failed'),
  paid('paid');

  const DeliveryStatus(this.wire);

  /// Значение, которым статус называется в API.
  final String wire;

  String get label => switch (this) {
        DeliveryStatus.pending => 'Новый',
        DeliveryStatus.onWay => 'В пути',
        DeliveryStatus.delivered => 'Доставлен',
        DeliveryStatus.failed => 'Не доставлено',
        DeliveryStatus.paid => 'Оплачено',
      };

  static DeliveryStatus fromJson(String value) =>
      DeliveryStatus.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => DeliveryStatus.pending,
      );

  String toJson() => wire;
}

/// Статус маршрута. Значения совпадают с API.
enum RouteStatus {
  created('created'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const RouteStatus(this.wire);

  final String wire;

  String get label => switch (this) {
        RouteStatus.created => 'Создан',
        RouteStatus.inProgress => 'Выполняется',
        RouteStatus.completed => 'Завершён',
        RouteStatus.cancelled => 'Отменён',
      };

  static RouteStatus fromJson(String value) => RouteStatus.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => RouteStatus.created,
      );

  String toJson() => wire;
}

/// Способ оплаты — только для интерфейса завершения доставки.
/// API его не принимает (в CompleteDelivery такого поля нет).
enum PaymentMethod {
  cash,
  card,
  transfer,
  debt;

  String get label => switch (this) {
        PaymentMethod.cash => 'Наличные',
        PaymentMethod.card => 'Карта',
        PaymentMethod.transfer => 'Перечисление',
        PaymentMethod.debt => 'В долг',
      };
}

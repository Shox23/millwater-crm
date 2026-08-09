import '../../l10n/l10n.dart';

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

  /// Подпись статуса на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        DeliveryStatus.pending => l10n.deliveryPending,
        DeliveryStatus.onWay => l10n.deliveryOnWay,
        DeliveryStatus.delivered => l10n.deliveryDelivered,
        DeliveryStatus.failed => l10n.deliveryFailed,
        DeliveryStatus.paid => l10n.deliveryPaid,
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

  /// Подпись статуса на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        RouteStatus.created => l10n.routeCreated,
        RouteStatus.inProgress => l10n.routeInProgress,
        RouteStatus.completed => l10n.routeCompleted,
        RouteStatus.cancelled => l10n.routeCancelled,
      };

  static RouteStatus fromJson(String value) => RouteStatus.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => RouteStatus.created,
      );

  String toJson() => wire;
}

/// Фильтр списка маршрутов (чипы на экране).
///
/// Общий для админского и водительского списков.
enum RouteFilter {
  all,
  inProgress,
  completed,
  created;

  /// Подпись чипа на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        RouteFilter.all => l10n.filterAll,
        RouteFilter.inProgress => l10n.filterInProgress,
        RouteFilter.completed => l10n.filterCompleted,
        RouteFilter.created => l10n.filterNew,
      };

  /// Статус, которому соответствует фильтр. `null` у «Все».
  RouteStatus? get status => switch (this) {
        RouteFilter.all => null,
        RouteFilter.inProgress => RouteStatus.inProgress,
        RouteFilter.completed => RouteStatus.completed,
        RouteFilter.created => RouteStatus.created,
      };
}

/// Способ оплаты — только для интерфейса завершения доставки.
/// API его не принимает (в CompleteDelivery такого поля нет).
enum PaymentMethod {
  cash,
  card,
  transfer,
  debt;

  /// Подпись способа оплаты на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        PaymentMethod.cash => l10n.paymentCash,
        PaymentMethod.card => l10n.paymentCard,
        PaymentMethod.transfer => l10n.paymentTransfer,
        PaymentMethod.debt => l10n.paymentDebt,
      };
}

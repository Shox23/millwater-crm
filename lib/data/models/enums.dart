import '../../l10n/l10n.dart';

/// Статус доставки (остановки маршрута). Значения совпадают с API.
enum DeliveryStatus {
  pending('pending'),
  onWay('on_way'),
  delivered('delivered'),
  failed('failed');

  const DeliveryStatus(this.wire);

  /// Значение, которым статус называется в API.
  final String wire;

  /// Подпись статуса на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        DeliveryStatus.pending => l10n.deliveryPending,
        DeliveryStatus.onWay => l10n.deliveryOnWay,
        DeliveryStatus.delivered => l10n.deliveryDelivered,
        DeliveryStatus.failed => l10n.deliveryFailed,
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

/// Что админ может менять в маршруте с этим статусом.
///
/// Правило живёт одним местом: форма, детальный экран и тесты спрашивают
/// здесь, а не сравнивают статусы каждый у себя — иначе «можно» и «нельзя»
/// однажды разъедутся, и разойдутся они молча.
extension RouteEditRules on RouteStatus {
  /// Дату и водителя меняем только до выхода в рейс: начатый маршрут
  /// водитель уже везёт, и смена исполнителя или дня под ним означает, что
  /// он приедет не туда и не тогда.
  bool get canReschedule => this == RouteStatus.created;

  /// Точку можно досыпать и в начатый маршрут — обычный случай, когда заказ
  /// поступил, пока водитель в пути.
  bool get canAddCustomers =>
      this == RouteStatus.created || this == RouteStatus.inProgress;

  /// Убирать точки — только до выезда: в рейсе доставка может быть уже
  /// выполнена, и удаление стёрло бы её вместе с принятой оплатой.
  bool get canRemoveCustomers => this == RouteStatus.created;

  /// Есть ли вообще что менять — этим включается кнопка «Изменить».
  bool get isEditable => canReschedule || canAddCustomers;

  /// Отменяем только то, что ещё не доехало. У завершённого маршрута отменять
  /// нечего: доставки выполнены, оплаты приняты — кнопка предлагала бы стереть
  /// уже случившееся.
  bool get canCancel =>
      this == RouteStatus.created || this == RouteStatus.inProgress;
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

/// Способ оплаты. Значения совпадают с API (`PaymentMethod`), поле
/// обязательное при завершении доставки.
enum PaymentMethod {
  cash('cash'),
  card('card'),
  transfer('transfer'),
  debt('debt');

  const PaymentMethod(this.wire);

  /// Значение, которым способ называется в API.
  final String wire;

  /// Подпись способа оплаты на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        PaymentMethod.cash => l10n.paymentCash,
        PaymentMethod.card => l10n.paymentCard,
        PaymentMethod.transfer => l10n.paymentTransfer,
        PaymentMethod.debt => l10n.paymentDebt,
      };

  /// Нужно ли фото подтверждения.
  ///
  /// Только у карты: перевод подтверждается чеком из банковского приложения,
  /// а наличные, безнал по счёту и долг фотографировать нечего.
  bool get needsPhoto => this == PaymentMethod.card;

  String toJson() => wire;
}

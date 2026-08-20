part of 'day_deliveries_bloc.dart';

/// Фильтр таблицы доставок.
///
/// Отдельный от `RouteFilter`: тот отбирает маршруты по [RouteStatus], а
/// строки здесь — точки, и статус у них свой.
enum DeliveryFilter {
  all(null),
  onWay(DeliveryStatus.onWay),
  delivered(DeliveryStatus.delivered),
  pending(DeliveryStatus.pending);

  const DeliveryFilter(this.status);

  /// Статус, которому соответствует фильтр. `null` у «Все».
  final DeliveryStatus? status;

  String label(AppLocalizations l10n) => switch (this) {
        DeliveryFilter.all => l10n.filterAll,
        DeliveryFilter.onWay => l10n.filterInProgress,
        DeliveryFilter.delivered => l10n.filterDelivered,
        DeliveryFilter.pending => l10n.filterNew,
      };
}

sealed class DayDeliveriesEvent extends Equatable {
  const DayDeliveriesEvent();

  @override
  List<Object?> get props => [];
}

class DayDeliveriesRequested extends DayDeliveriesEvent {
  const DayDeliveriesRequested();
}

/// Выбран другой день в ленте дат.
class DayDeliveriesDateChanged extends DayDeliveriesEvent {
  const DayDeliveriesDateChanged(this.date);
  final DateTime date;

  @override
  List<Object?> get props => [date];
}

class DayDeliveriesFilterChanged extends DayDeliveriesEvent {
  const DayDeliveriesFilterChanged(this.filter);
  final DeliveryFilter filter;

  @override
  List<Object?> get props => [filter];
}

class DayDeliveriesSearchChanged extends DayDeliveriesEvent {
  const DayDeliveriesSearchChanged(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

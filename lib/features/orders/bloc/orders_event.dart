part of 'orders_bloc.dart';

sealed class OrdersEvent extends Equatable {
  const OrdersEvent();

  @override
  List<Object?> get props => [];
}

/// Перечитать список с первой страницы.
class OrdersRequested extends OrdersEvent {
  const OrdersRequested();
}

class OrdersSearchChanged extends OrdersEvent {
  const OrdersSearchChanged(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Сменить отбор по статусу; `null` — «Все».
class OrdersStatusChanged extends OrdersEvent {
  const OrdersStatusChanged(this.status);
  final DeliveryStatus? status;

  @override
  List<Object?> get props => [status];
}

/// Сменить отбор по цели заказа; `null` — «Все».
class OrdersPurposeChanged extends OrdersEvent {
  const OrdersPurposeChanged(this.purpose);
  final OrderPurpose? purpose;

  @override
  List<Object?> get props => [purpose];
}

/// Дочитать следующую страницу в конец списка.
///
/// Приходит из обработчика прокрутки, когда список подошёл к концу.
class OrdersNextPageRequested extends OrdersEvent {
  const OrdersNextPageRequested();
}

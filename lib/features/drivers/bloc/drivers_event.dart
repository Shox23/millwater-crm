part of 'drivers_bloc.dart';

sealed class DriversEvent extends Equatable {
  const DriversEvent();

  @override
  List<Object?> get props => [];
}

class DriversRequested extends DriversEvent {
  const DriversRequested();
}

class DriversSearchChanged extends DriversEvent {
  const DriversSearchChanged(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Переключить список между работающими и удалёнными водителями.
class DriversActivityChanged extends DriversEvent {
  const DriversActivityChanged({required this.active});
  final bool active;

  @override
  List<Object?> get props => [active];
}

/// Дочитать следующую страницу в конец списка.
///
/// Приходит из обработчика прокрутки, когда список подошёл к концу.
class DriversNextPageRequested extends DriversEvent {
  const DriversNextPageRequested();
}

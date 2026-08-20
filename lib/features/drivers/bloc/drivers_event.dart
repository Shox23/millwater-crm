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

/// Дочитать следующую страницу в конец списка.
///
/// Приходит из обработчика прокрутки, когда список подошёл к концу.
class DriversNextPageRequested extends DriversEvent {
  const DriversNextPageRequested();
}

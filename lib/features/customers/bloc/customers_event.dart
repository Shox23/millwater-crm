part of 'customers_bloc.dart';

sealed class CustomersEvent extends Equatable {
  const CustomersEvent();

  @override
  List<Object?> get props => [];
}

class CustomersRequested extends CustomersEvent {
  const CustomersRequested();
}

class CustomersSearchChanged extends CustomersEvent {
  const CustomersSearchChanged(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Дочитать следующую страницу в конец списка.
///
/// Приходит из обработчика прокрутки, когда список подошёл к концу.
class CustomersNextPageRequested extends CustomersEvent {
  const CustomersNextPageRequested();
}

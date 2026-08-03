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

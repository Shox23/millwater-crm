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

/// Сменить чип отбора. Перезагрузка идёт сразу: это нажатие, а не набор
/// текста, откладывать нечего.
class CustomersFilterChanged extends CustomersEvent {
  const CustomersFilterChanged(this.filter);
  final CustomerFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// Сменить поле, по которому ищем.
class CustomersSearchModeChanged extends CustomersEvent {
  const CustomersSearchModeChanged(this.mode);
  final CustomerSearchMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Дочитать следующую страницу в конец списка.
///
/// Приходит из обработчика прокрутки, когда список подошёл к концу.
class CustomersNextPageRequested extends CustomersEvent {
  const CustomersNextPageRequested();
}

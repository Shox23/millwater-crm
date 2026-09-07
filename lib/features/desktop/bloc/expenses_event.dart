part of 'expenses_bloc.dart';

sealed class ExpensesEvent extends Equatable {
  const ExpensesEvent();

  @override
  List<Object?> get props => [];
}

class ExpensesRequested extends ExpensesEvent {
  const ExpensesRequested();
}

class ExpensesPeriodChanged extends ExpensesEvent {
  const ExpensesPeriodChanged(this.period);
  final StatsPeriod period;

  @override
  List<Object?> get props => [period];
}

/// `null` — «Все категории».
class ExpensesCategoryChanged extends ExpensesEvent {
  const ExpensesCategoryChanged(this.category);
  final ExpenseCategory? category;

  @override
  List<Object?> get props => [category];
}

/// `null` — по всем водителям.
class ExpensesDriverChanged extends ExpensesEvent {
  const ExpensesDriverChanged(this.driverId);
  final String? driverId;

  @override
  List<Object?> get props => [driverId];
}

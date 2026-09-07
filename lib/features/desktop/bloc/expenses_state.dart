part of 'expenses_bloc.dart';

enum ExpensesStatus { initial, loading, ready, error }

class ExpensesState extends Equatable {
  const ExpensesState({
    this.status = ExpensesStatus.initial,
    this.expenses = const [],
    this.period = StatsPeriod.month,
    this.category,
    this.driverId,
  });

  final ExpensesStatus status;
  final List<RouteExpense> expenses;
  final StatsPeriod period;

  /// Отбор по категории; `null` — все.
  final ExpenseCategory? category;

  /// Отбор по водителю; `null` — все.
  final String? driverId;

  /// Сколько потрачено за период, сум.
  int get total => expenses.fold<int>(0, (sum, e) => sum + e.amount);

  /// Расходы по категориям — для сводки над таблицей.
  ///
  /// Считается здесь, а не на экране: то же число показывает и таблица, и
  /// сводка, и разойтись им нельзя.
  Map<ExpenseCategory, int> get byCategory {
    final result = <ExpenseCategory, int>{};
    for (final expense in expenses) {
      result[expense.category] = (result[expense.category] ?? 0) + expense.amount;
    }
    return result;
  }

  /// `clearCategory` и `clearDriver` нужны, потому что `null` у обычного
  /// именованного параметра неотличим от «не передавали», а сброс фильтра —
  /// это как раз передача `null`.
  ExpensesState copyWith({
    ExpensesStatus? status,
    List<RouteExpense>? expenses,
    StatsPeriod? period,
    ExpenseCategory? category,
    bool clearCategory = false,
    String? driverId,
    bool clearDriver = false,
  }) {
    return ExpensesState(
      status: status ?? this.status,
      expenses: expenses ?? this.expenses,
      period: period ?? this.period,
      category: clearCategory ? category : (category ?? this.category),
      driverId: clearDriver ? driverId : (driverId ?? this.driverId),
    );
  }

  @override
  List<Object?> get props => [status, expenses, period, category, driverId];
}

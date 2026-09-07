import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/stats_period.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/route_expense.dart';
import '../../../data/repositories/crm_repository.dart';

part 'expenses_event.dart';
part 'expenses_state.dart';

/// Расходы водителей за период — десктопный раздел «Касса».
///
/// Отдельный блок, а не часть дня маршрутов: период здесь свой (неделя,
/// месяц), и привязывать расходы к выбранному дню значило бы не дать
/// посмотреть их за месяц — ради чего экран и заводится.
class ExpensesBloc extends Bloc<ExpensesEvent, ExpensesState> {
  ExpensesBloc(this._repository) : super(const ExpensesState()) {
    on<ExpensesRequested>(_onRequested);
    on<ExpensesPeriodChanged>(_onPeriodChanged);
    on<ExpensesCategoryChanged>(_onCategoryChanged);
    on<ExpensesDriverChanged>(_onDriverChanged);
  }

  final CrmRepository _repository;

  /// Номер последнего запроса: переключая период, легко получить ответы
  /// вразнобой — медленный первый лёг бы поверх последнего.
  int _requestId = 0;

  Future<void> _onRequested(
    ExpensesRequested event,
    Emitter<ExpensesState> emit,
  ) async {
    final id = ++_requestId;
    emit(state.copyWith(status: ExpensesStatus.loading));

    final (from, to) = state.period.range;
    try {
      // Расходы листаются страницами; за месяц их немного, но полагаться на
      // «влезут в одну» нельзя — у большого парка не влезут.
      final all = <RouteExpense>[];
      for (var page = 1; page <= 20; page++) {
        final chunk = await _repository.getExpensesPage(
          page: page,
          dateFrom: from,
          dateTo: to,
          category: state.category,
          driverId: state.driverId,
        );
        all.addAll(chunk.items);
        if (!chunk.hasMore) break;
      }

      if (id != _requestId) return;
      emit(state.copyWith(status: ExpensesStatus.ready, expenses: all));
    } catch (_) {
      if (id != _requestId) return;
      emit(state.copyWith(status: ExpensesStatus.error));
    }
  }

  void _onPeriodChanged(
    ExpensesPeriodChanged event,
    Emitter<ExpensesState> emit,
  ) {
    if (event.period == state.period) return;
    // Прежние строки убираем сразу: под новой подписью периода они значили
    // бы не то, что написано.
    emit(ExpensesState(
      status: ExpensesStatus.loading,
      period: event.period,
      category: state.category,
      driverId: state.driverId,
    ));
    add(const ExpensesRequested());
  }

  void _onCategoryChanged(
    ExpensesCategoryChanged event,
    Emitter<ExpensesState> emit,
  ) {
    if (event.category == state.category) return;
    emit(state.copyWith(category: event.category, clearCategory: true));
    add(const ExpensesRequested());
  }

  void _onDriverChanged(
    ExpensesDriverChanged event,
    Emitter<ExpensesState> emit,
  ) {
    if (event.driverId == state.driverId) return;
    emit(state.copyWith(driverId: event.driverId, clearDriver: true));
    add(const ExpensesRequested());
  }
}

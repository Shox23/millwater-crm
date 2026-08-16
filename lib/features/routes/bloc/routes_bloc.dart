import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/day.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/route_models.dart';
import '../../../data/repositories/crm_repository.dart';

part 'routes_event.dart';
part 'routes_state.dart';

class RoutesBloc extends Bloc<RoutesEvent, RoutesState> {
  RoutesBloc(this._repository)
      : super(RoutesState(date: dayOnly(DateTime.now()))) {
    on<RoutesRequested>(_onRequested);
    on<RoutesFilterChanged>(_onFilterChanged);
    on<RoutesDateChanged>(_onDateChanged);
  }

  final CrmRepository _repository;

  Future<void> _onRequested(
    RoutesRequested event,
    Emitter<RoutesState> emit,
  ) async {
    emit(state.copyWith(status: RoutesStatus.loading));
    final day = state.date;
    try {
      // Выручки нет в списке маршрутов — берём её из сводного отчёта.
      // Обоим запросам отдаём один и тот же день: иначе подписи экрана
      // («Собрано», «Выполнено доставок») говорили бы про разные периоды.
      // Запросы независимы, поэтому идут параллельно.
      final (routes, report) = await (
        _repository.getRoutes(dateFrom: day, dateTo: day),
        _repository.getSummaryReport(dateFrom: day, dateTo: day),
      ).wait;
      // Пока запрос был в пути, могли переключить день — тогда ответ уже не
      // про то, что на экране, и класть его в состояние нельзя.
      if (state.date != day) return;
      emit(state.copyWith(
        status: RoutesStatus.ready,
        routes: routes,
        collected: report.totalRevenue,
      ));
    } catch (_) {
      if (state.date != day) return;
      emit(state.copyWith(status: RoutesStatus.error));
    }
  }

  void _onFilterChanged(
    RoutesFilterChanged event,
    Emitter<RoutesState> emit,
  ) {
    emit(state.copyWith(filter: event.filter));
  }

  void _onDateChanged(
    RoutesDateChanged event,
    Emitter<RoutesState> emit,
  ) {
    final day = dayOnly(event.date);
    // Повторный тап по уже выбранному табу сеть дёргать не должен.
    if (day == state.date) return;
    // Список чистим сразу: иначе, пока грузится новый день, на экране
    // остаются вчерашние маршруты под новой подписью. Статус переводим здесь
    // же — без него пустой список успевает мигнуть как «маршрутов нет»
    // раньше, чем запрос вообще уйдёт.
    emit(state.copyWith(
      date: day,
      routes: const [],
      collected: 0,
      status: RoutesStatus.loading,
    ));
    add(const RoutesRequested());
  }
}

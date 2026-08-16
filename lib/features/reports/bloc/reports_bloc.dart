import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';
import '../../../data/models/reports_summary.dart';
import '../../../data/repositories/crm_repository.dart';

part 'reports_event.dart';
part 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  ReportsBloc(this._repository) : super(const ReportsState()) {
    on<ReportsRequested>(_onRequested);
    on<ReportsPeriodChanged>(_onPeriodChanged);
  }

  final CrmRepository _repository;

  /// Номер последнего запроса: ответы обогнавших друг друга запросов
  /// не должны затирать более свежий результат.
  ///
  /// Селектор периода это провоцирует: «Сегодня → Неделя → Месяц» тремя
  /// тапами — и медленный первый ответ лёг бы поверх последнего.
  int _requestId = 0;

  Future<void> _onRequested(
    ReportsRequested event,
    Emitter<ReportsState> emit,
  ) async {
    final id = ++_requestId;
    emit(state.copyWith(status: ReportsStatus.loading));
    try {
      final (from, to) = _rangeFor(state.period);
      // Должников и остаток капсул сводка не отдаёт — их приходится выводить
      // из справочника заказчиков. Запросы независимы, поэтому параллельно.
      final (report, customers) = await (
        _repository.getSummaryReport(dateFrom: from, dateTo: to),
        _repository.getCustomers(),
      ).wait;
      if (id != _requestId) return;
      emit(state.copyWith(
        status: ReportsStatus.ready,
        summary: ReportsSummary.from(report, customers),
      ));
    } catch (_) {
      if (id != _requestId) return;
      emit(state.copyWith(status: ReportsStatus.error));
    }
  }

  void _onPeriodChanged(
    ReportsPeriodChanged event,
    Emitter<ReportsState> emit,
  ) {
    // Состояние собираем заново, а не через copyWith: прежние числа надо
    // именно убрать. Иначе, пока идёт запрос, в шапке уже «Месяц», а в
    // карточках всё ещё цифры за сегодня.
    emit(ReportsState(status: ReportsStatus.loading, period: event.period));
    add(const ReportsRequested());
  }

  /// Границы периода для запроса отчёта.
  (DateTime, DateTime) _rangeFor(ReportPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      ReportPeriod.today => (today, today),
      ReportPeriod.week => (today.subtract(const Duration(days: 6)), today),
      ReportPeriod.month => (DateTime(now.year, now.month, 1), today),
    };
  }
}

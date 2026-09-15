import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/date_period.dart';
import '../../../core/utils/stats_period.dart';
import '../../../core/utils/throttle.dart';
import '../../../data/models/notification_event.dart';
import '../../../data/models/reports_summary.dart';
import '../../../data/repositories/crm_repository.dart';

part 'reports_event.dart';
part 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  ReportsBloc(this._repository, {Stream<NotificationEvent>? notifications})
      : super(const ReportsState()) {
    on<ReportsRequested>(_onRequested);
    on<ReportsPeriodChanged>(_onPeriodChanged);

    // Выручка и число доставок меняются ровно теми же событиями, что и
    // список маршрутов, — см. `RoutesBloc`. Пересчёт здесь дороже: вместе с
    // отчётом заново тянется весь справочник заказчиков, поэтому склеивать
    // всплески тем более нужно.
    _notifications = notifications?.listen(
      (_) => _reload(() {
        if (!isClosed) add(const ReportsRequested());
      }),
    );
  }

  final CrmRepository _repository;
  StreamSubscription<NotificationEvent>? _notifications;
  final _reload = Throttle(kNotificationReloadWindow);

  @override
  Future<void> close() async {
    _reload.dispose();
    await _notifications?.cancel();
    return super.close();
  }

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
      final (from, to) = rangeFor(state.period);
      // Долг и остаток капсул — показатели «на сейчас» по всей базе, и ни
      // один отчёт их не отдаёт: отчёт по заказчикам ограничен теми, у кого
      // в периоде была активность, и за пустой день показал бы ноль
      // должников при непустом долге. Поэтому справочник по-прежнему нужен.
      // Запросы независимы, поэтому параллельно.
      final (rows, customers) = await (
        _repository.getGeneralReport(dateFrom: from, dateTo: to),
        _repository.getCustomers(),
      ).wait;
      if (id != _requestId) return;
      emit(state.copyWith(
        status: ReportsStatus.ready,
        summary: ReportsSummary.from(rows, customers),
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
  ///
  /// Публичная, потому что теми же границами выгружается Excel: посчитай их
  /// кнопка экспорта сама — и однажды выгрузила бы не тот период, который
  /// показан на экране. Сам расчёт живёт в [DatePeriod.range].
  static (DateTime, DateTime) rangeFor(ReportPeriod period) => period.range;

}

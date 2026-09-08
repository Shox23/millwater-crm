import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/day.dart';
import '../../../core/utils/throttle.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/notification_event.dart';
import '../../../data/models/route_models.dart';
import '../../../data/repositories/driver_repository.dart';

part 'my_routes_event.dart';
part 'my_routes_state.dart';

/// Маршруты текущего водителя.
///
/// В отличие от админского `RoutesBloc` здесь один запрос: сводный отчёт
/// (`/admin/reports/summary`) водителю недоступен, а денежных показателей
/// на его экране и не предусмотрено.
class MyRoutesBloc extends Bloc<MyRoutesEvent, MyRoutesState> {
  MyRoutesBloc(this._repository, {Stream<NotificationEvent>? notifications})
      : super(MyRoutesState(date: dayOnly(DateTime.now()))) {
    on<MyRoutesRequested>(_onRequested);
    on<MyRoutesFilterChanged>(_onFilterChanged);
    on<MyRoutesDateChanged>(_onDateChanged);

    // Админ досыпал точку в маршрут, статус сменился — прогресс на карточках
    // устаревал молча: подписан был только детальный экран, и до захода
    // внутрь список показывал вчерашние цифры.
    //
    // Цена решения: водительский поток теперь держится открытым всё время,
    // пока открыта вкладка маршрутов, а не только на время карточки.
    _notifications = notifications?.listen(
      (_) => _reload(() {
        if (!isClosed) add(const MyRoutesRequested());
      }),
    );
  }

  final DriverRepository _repository;
  StreamSubscription<NotificationEvent>? _notifications;
  final _reload = Throttle(kNotificationReloadWindow);

  @override
  Future<void> close() async {
    _reload.dispose();
    await _notifications?.cancel();
    return super.close();
  }

  Future<void> _onRequested(
    MyRoutesRequested event,
    Emitter<MyRoutesState> emit,
  ) async {
    emit(state.copyWith(status: MyRoutesStatus.loading));
    try {
      final routes = await _repository.getMyRoutes();
      emit(state.copyWith(status: MyRoutesStatus.ready, routes: routes));
    } catch (_) {
      emit(state.copyWith(status: MyRoutesStatus.error));
    }
  }

  void _onFilterChanged(
    MyRoutesFilterChanged event,
    Emitter<MyRoutesState> emit,
  ) {
    emit(state.copyWith(filter: event.filter));
  }

  /// Смена дня — только пересчёт отбора.
  ///
  /// Запроса здесь нет намеренно: репозиторий отдаёт все маршруты водителя
  /// разом, так что нужный день уже лежит в [state.routes]. Лишний поход в
  /// сеть на каждый таб стоил бы водителю трафика и подвисаний там, где
  /// связь плохая, — а показать всё равно нечего сверх уже загруженного.
  void _onDateChanged(
    MyRoutesDateChanged event,
    Emitter<MyRoutesState> emit,
  ) {
    final day = dayOnly(event.date);
    if (day == state.date) return;
    emit(state.copyWith(date: day));
  }
}

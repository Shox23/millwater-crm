import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/pricing/capsule_price.dart';
import '../../../core/product_config.dart';
import '../../../core/utils/day.dart';
import '../../../core/utils/throttle.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/notification_event.dart';
import '../../../data/models/route_models.dart';
import '../../../data/repositories/crm_repository.dart';
import '../../../l10n/l10n.dart';

part 'day_deliveries_event.dart';
part 'day_deliveries_state.dart';

/// Доставки выбранного дня — строки таблицы десктопа.
///
/// Свой блок, а не `RoutesBloc`: тот держит список маршрутов, а десктопная
/// таблица показывает точки внутри них — заказчик, водитель, капсулы, оплата.
/// Форма данных другая, всё остальное (репозиторий, модели, поток событий)
/// переиспользуется.
///
/// Точки приходится добирать по одной на маршрут: списочный эндпоинт
/// `/admin/routes` отдаёт только счётчики. Запросы идут параллельно и ровно
/// один раз на смену дня, а не на каждую перерисовку.
class DayDeliveriesBloc extends Bloc<DayDeliveriesEvent, DayDeliveriesState> {
  DayDeliveriesBloc(
    this._repository, {
    Stream<NotificationEvent>? notifications,
    CapsulePrice? price,
  })  : _price = price ?? const BuildCapsulePrice(),
        super(DayDeliveriesState(date: dayOnly(DateTime.now()))) {
    on<DayDeliveriesRequested>(_onRequested);
    on<DayDeliveriesDateChanged>(_onDateChanged);
    on<DayDeliveriesFilterChanged>(_onFilterChanged);
    on<DayDeliveriesSearchChanged>(_onSearchChanged);

    // Водитель закрыл точку — таблица под открытым экраном устарела.
    // Самая дорогая перезагрузка в приложении: список маршрутов ленты дат
    // плюс отдельный запрос за деталями каждого маршрута дня. Всплеск из
    // десяти событий обходится в одну.
    _notifications = notifications?.listen(
      (_) => _reload(() {
        if (!isClosed) add(const DayDeliveriesRequested());
      }),
    );
  }

  final CrmRepository _repository;

  /// Цена капсулы для оценки долга. Свой кэш и свой откат на значение сборки
  /// живут внутри источника — см. [CapsulePrice].
  final CapsulePrice _price;

  StreamSubscription<NotificationEvent>? _notifications;
  final _reload = Throttle(kNotificationReloadWindow);

  @override
  Future<void> close() async {
    _reload.dispose();
    await _notifications?.cancel();
    return super.close();
  }

  Future<void> _onRequested(
    DayDeliveriesRequested event,
    Emitter<DayDeliveriesState> emit,
  ) async {
    final day = state.date;
    emit(state.copyWith(status: DayDeliveriesStatus.loading));

    try {
      // Одним запросом берём всю ленту дат, а не только выбранный день:
      // на табах стоят счётчики соседних дней, и пять отдельных запросов
      // ради них — расточительство.
      final window = DayDeliveriesState.dateWindow();
      // Цена идёт рядом со списком, а не отдельным шагом: запросы независимы,
      // а долг за день без неё не посчитать. Источник цены не бросает и своим
      // отказом загрузку дня не рушит.
      final (all, capsulePrice) = await (
        _repository.getRoutes(dateFrom: window.first, dateTo: window.last),
        _price.value(),
      ).wait;
      // Пока список был в пути, могли переключить день.
      if (state.date != day) return;

      final ofDay = all.where((r) => dayOnly(r.date) == day).toList();
      final details = await Future.wait(
        ofDay.map((r) => _repository.getRoute(r.id)),
      );
      if (state.date != day) return;

      final rows = <DeliveryRow>[];
      for (final route in details.whereType<RouteDetail>()) {
        for (final stop in route.stops) {
          rows.add(DeliveryRow(route: route, stop: stop));
        }
      }

      emit(state.copyWith(
        status: DayDeliveriesStatus.ready,
        rows: rows,
        routesCount: ofDay.length,
        dayMeta: _metaByDay(all),
        capsulePrice: capsulePrice,
      ));
    } catch (_) {
      if (state.date != day) return;
      emit(state.copyWith(status: DayDeliveriesStatus.error));
    }
  }

  /// Счётчики по дням ленты — из списочного ответа, без захода в маршруты.
  static Map<DateTime, DayMeta> _metaByDay(List<RouteListItem> routes) {
    final result = <DateTime, DayMeta>{};
    for (final route in routes) {
      final key = dayOnly(route.date);
      final current = result[key] ?? const DayMeta();
      result[key] = DayMeta(
        done: current.done + route.completedCount,
        total: current.total + route.totalCustomers,
        routes: current.routes + 1,
      );
    }
    return result;
  }

  void _onDateChanged(
    DayDeliveriesDateChanged event,
    Emitter<DayDeliveriesState> emit,
  ) {
    final day = dayOnly(event.date);
    if (day == state.date) return;
    // Строки чистим сразу: иначе под новой датой на секунду остаются
    // вчерашние доставки, и цифры KPI считаются по ним же.
    emit(state.copyWith(
      date: day,
      rows: const [],
      routesCount: 0,
      status: DayDeliveriesStatus.loading,
    ));
    add(const DayDeliveriesRequested());
  }

  void _onFilterChanged(
    DayDeliveriesFilterChanged event,
    Emitter<DayDeliveriesState> emit,
  ) {
    emit(state.copyWith(filter: event.filter));
  }

  void _onSearchChanged(
    DayDeliveriesSearchChanged event,
    Emitter<DayDeliveriesState> emit,
  ) {
    // Фильтруем на клиенте: у `/admin/routes` параметра поиска нет, а день
    // и так загружен целиком — гонять сеть ради подстроки незачем.
    emit(state.copyWith(query: event.query));
  }
}

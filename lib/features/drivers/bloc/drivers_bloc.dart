import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/driver.dart';
import '../../../data/repositories/crm_repository.dart';

part 'drivers_event.dart';
part 'drivers_state.dart';

class DriversBloc extends Bloc<DriversEvent, DriversState> {
  /// [active] — с какого списка начать: работающих или удалённых.
  DriversBloc(this._repository, {bool active = true})
      : super(DriversState(active: active)) {
    on<DriversRequested>(_onRequested);
    on<DriversSearchChanged>(_onSearchChanged);
    on<DriversActivityChanged>(_onActivityChanged);
    on<DriversNextPageRequested>(_onNextPage);
  }

  final CrmRepository _repository;

  /// Откладывает запрос, пока пользователь печатает.
  Timer? _debounce;

  /// Номер последнего запроса: ответы обогнавших друг друга запросов
  /// не должны затирать более свежий результат.
  int _requestId = 0;

  static const _debounceDelay = Duration(milliseconds: 300);

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  Future<void> _onRequested(
    DriversRequested event,
    Emitter<DriversState> emit,
  ) async {
    final id = ++_requestId;
    emit(state.copyWith(status: DriversStatus.loading));
    try {
      // Фильтрует сервер, а не мы: локальный фильтр поверх серверного прятал
      // бы часть найденного. Берём первую страницу — остальные догрузит
      // прокрутка, см. [DriversNextPageRequested].
      final page = await _repository.getDriversPage(
        search: state.query,
        active: state.active,
      );
      if (id != _requestId) return;
      emit(state.copyWith(
        status: DriversStatus.ready,
        drivers: page.items,
        page: page.page,
        hasMore: page.hasMore,
        total: page.total,
        loadingMore: false,
      ));
    } catch (_) {
      if (id != _requestId) return;
      emit(state.copyWith(status: DriversStatus.error, loadingMore: false));
    }
  }

  /// Догружает следующую страницу в конец списка.
  ///
  /// Молча выходит, если грузить нечего или загрузка уже идёт: событие
  /// приходит из обработчика прокрутки и повторяется на каждый кадр у края.
  Future<void> _onNextPage(
    DriversNextPageRequested event,
    Emitter<DriversState> emit,
  ) async {
    if (!state.hasMore || state.loadingMore) return;
    if (state.status == DriversStatus.loading) return;

    final id = _requestId;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repository.getDriversPage(
        page: state.page + 1,
        search: state.query,
        active: state.active,
      );
      // Пока страница шла, поиск могли поменять — её содержимое уже не о том.
      if (id != _requestId) return;
      emit(state.copyWith(
        drivers: [...state.drivers, ...page.items],
        page: page.page,
        hasMore: page.hasMore,
        total: page.total,
        loadingMore: false,
      ));
    } catch (_) {
      if (id != _requestId) return;
      // Показанное не рушим: не догрузилось — значит, список остался прежним,
      // а повторить можно ещё одной прокруткой.
      emit(state.copyWith(loadingMore: false));
    }
  }

  void _onSearchChanged(
    DriversSearchChanged event,
    Emitter<DriversState> emit,
  ) {
    emit(state.copyWith(query: event.query));
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!isClosed) add(const DriversRequested());
    });
  }

  void _onActivityChanged(
    DriversActivityChanged event,
    Emitter<DriversState> emit,
  ) {
    if (event.active == state.active) return;
    // Список прошлого режима чистим сразу: иначе под чипом «Неактивные» на
    // время запроса стояли бы работающие водители с кнопками удаления.
    emit(state.copyWith(
      active: event.active,
      status: DriversStatus.loading,
      drivers: const [],
      page: 1,
      hasMore: false,
      total: 0,
      loadingMore: false,
    ));
    add(const DriversRequested());
  }
}

/// Удалённые водители — второй список рядом с основным.
///
/// Нужен десктопу: там [DriversBloc] общий для сайдбара («на линии»), кассы
/// и раздела водителей, и переключать его на удалённых нельзя — уволенные
/// попали бы в фильтр кассы, а «на линии» обнулилось бы. Отдельный тип —
/// чтобы оба списка жили в одном дереве провайдеров. На телефоне у раздела
/// свой блок, и там хватает [DriversActivityChanged].
class InactiveDriversBloc extends DriversBloc {
  InactiveDriversBloc(super.repository) : super(active: false);
}

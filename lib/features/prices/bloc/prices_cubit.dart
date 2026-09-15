import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/idempotency.dart';
import '../../../data/models/price_settings.dart';
import '../../../data/repositories/crm_repository.dart';

enum PricesStatus { loading, ready, error }

/// Действующий прайс и его история.
class PricesState extends Equatable {
  const PricesState({
    this.status = PricesStatus.loading,
    this.current,
    this.past = const [],
    this.historyFailed = false,
  });

  final PricesStatus status;

  /// Действующий прайс; есть, когда [status] — `ready`.
  final PriceSettings? current;

  /// Прошлые прайсы, новые первыми. Действующего среди них нет — он в
  /// [current].
  final List<PriceSettings> past;

  /// История не загрузилась. Экран из-за этого не ломается: главное —
  /// действующая цена и её изменение, а не список прошлых.
  final bool historyFailed;

  PricesState copyWith({
    PricesStatus? status,
    PriceSettings? current,
    List<PriceSettings>? past,
    bool? historyFailed,
  }) =>
      PricesState(
        status: status ?? this.status,
        current: current ?? this.current,
        past: past ?? this.past,
        historyFailed: historyFailed ?? this.historyFailed,
      );

  @override
  List<Object?> get props => [status, current, past, historyFailed];
}

/// Загрузка и смена прайса — общая для телефона и десктопа.
///
/// Вынесено из экрана, когда прайс появился на десктопе: две копии правил
/// «история необязательна», «повтор не заводит дубль» разошлись бы на первой
/// же правке. Проверка полей формы здесь не живёт — она про ввод, а не про
/// данные, см. `PriceRules`.
class PricesCubit extends Cubit<PricesState> {
  PricesCubit(this._repository) : super(const PricesState());

  final CrmRepository _repository;

  /// Один ключ на всё время жизни экрана: повтор после обрыва связи не
  /// должен завести вторую запись прайса. Сохранение меняет ключ — следующая
  /// смена цены уже другое действие.
  String _idempotencyKey = newIdempotencyKey('price');

  Future<void> load() async {
    emit(state.copyWith(status: PricesStatus.loading));
    try {
      final current = await _repository.getPrices();
      final (past, historyFailed) = await _history(current);
      emit(PricesState(
        status: PricesStatus.ready,
        current: current,
        past: past,
        historyFailed: historyFailed,
      ));
    } catch (_) {
      emit(state.copyWith(status: PricesStatus.error));
    }
  }

  /// История — не повод не показать экран: её отказ гасится здесь, а не
  /// уводит всё в «Не удалось загрузить цены».
  Future<(List<PriceSettings>, bool)> _history(PriceSettings current) async {
    try {
      final history = await _repository.getPriceHistory();
      // Действующий прайс убираем из списка: он показан отдельно.
      return (history.where((p) => p.id != current.id).toList(), false);
    } catch (_) {
      return (const <PriceSettings>[], true);
    }
  }

  /// Назначает новую цену. Бросает ошибку сервера — текст для неё подбирает
  /// экран, у кубита языка интерфейса нет.
  ///
  /// Оба значения уходят вместе, хотя сервер принимает и подмножество: на
  /// экране они показаны сразу оба, и «отправлю только изменённое» значило
  /// бы гадать, что админ считал изменением.
  Future<void> save({
    required int capsulePrice,
    required int damagedBottleFine,
  }) async {
    final saved = await _repository.setPrices(
      capsulePrice: capsulePrice,
      damagedBottleFine: damagedBottleFine,
      idempotencyKey: _idempotencyKey,
    );
    _idempotencyKey = newIdempotencyKey('price');
    // Прежний действующий уходит в историю сам, без перечитывания: сервер
    // отвечает новой записью, а история — это всё, что было до неё.
    final previous = state.current;
    emit(state.copyWith(
      current: saved,
      past: [?previous, ...state.past],
    ));
  }
}

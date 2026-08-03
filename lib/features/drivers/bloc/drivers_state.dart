part of 'drivers_bloc.dart';

enum DriversStatus { initial, loading, ready, error }

class DriversState extends Equatable {
  const DriversState({
    this.status = DriversStatus.initial,
    this.drivers = const [],
    this.query = '',
  });

  final DriversStatus status;
  final List<Driver> drivers;
  final String query;

  /// Отфильтрованный список. Поиск выполняет сервер, здесь ничего не режем:
  /// локальный фильтр поверх серверного прятал бы часть найденного.
  List<Driver> get visible => drivers;

  /// Список пуст из-за поиска, а не потому что база пустая.
  bool get isEmptySearch => drivers.isEmpty && query.trim().isNotEmpty;

  DriversState copyWith({
    DriversStatus? status,
    List<Driver>? drivers,
    String? query,
  }) {
    return DriversState(
      status: status ?? this.status,
      drivers: drivers ?? this.drivers,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [status, drivers, query];
}

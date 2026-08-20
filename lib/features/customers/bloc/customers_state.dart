part of 'customers_bloc.dart';

enum CustomersStatus { initial, loading, ready, error }

class CustomersState extends Equatable {
  const CustomersState({
    this.status = CustomersStatus.initial,
    this.customers = const [],
    this.query = '',
    this.page = 1,
    this.hasMore = false,
    this.total = 0,
    this.loadingMore = false,
  });

  final CustomersStatus status;
  final List<Customer> customers;
  final String query;

  /// Номер последней загруженной страницы.
  final int page;

  /// На сервере есть что догрузить.
  final bool hasMore;

  /// Сколько записей всего в выдаче — по нему подписана шапка.
  ///
  /// Раньше там стояла длина списка, но со страничной загрузкой это уже не
  /// одно и то же: «База · 100» на базе из тысячи — неправда.
  final int total;

  /// Идёт догрузка следующей страницы.
  ///
  /// Отдельно от [status]: догрузка не должна гасить уже показанный список
  /// спиннером во весь экран.
  final bool loadingMore;

  /// Отфильтрованный список. Поиск выполняет сервер, здесь ничего не режем:
  /// локальный фильтр поверх серверного прятал бы часть найденного.
  List<Customer> get visible => customers;

  /// Список пуст из-за поиска, а не потому что база пустая.
  bool get isEmptySearch => customers.isEmpty && query.trim().isNotEmpty;

  CustomersState copyWith({
    CustomersStatus? status,
    List<Customer>? customers,
    String? query,
    int? page,
    bool? hasMore,
    int? total,
    bool? loadingMore,
  }) {
    return CustomersState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      query: query ?? this.query,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }

  @override
  List<Object?> get props =>
      [status, customers, query, page, hasMore, total, loadingMore];
}

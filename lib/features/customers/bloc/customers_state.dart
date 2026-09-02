part of 'customers_bloc.dart';

enum CustomersStatus { initial, loading, ready, error }

class CustomersState extends Equatable {
  const CustomersState({
    this.status = CustomersStatus.initial,
    this.customers = const [],
    this.query = '',
    this.filter = CustomerFilter.all,
    this.page = 1,
    this.hasMore = false,
    this.total = 0,
    this.loadingMore = false,
  });

  final CustomersStatus status;
  final List<Customer> customers;
  final String query;

  /// Активный чип отбора. Отбирает сервер, кроме кулеров — см.
  /// [CustomerFilter.filtersCoolerLocally].
  final CustomerFilter filter;

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

  /// Список к показу. Резать здесь нечего: выдачу уже собрал `CustomersBloc`
  /// — серверным поиском и, для чипа «С кулером», клиентским отбором.
  List<Customer> get visible => customers;

  /// Список пуст из-за поиска, а не потому что база пустая.
  bool get isEmptySearch => customers.isEmpty && query.trim().isNotEmpty;

  /// Список пуст из-за чипа отбора: подсказка «очистить поиск» здесь не к
  /// месту — очищать нечего, сбрасывать надо фильтр.
  bool get isEmptyFilter =>
      customers.isEmpty &&
      query.trim().isEmpty &&
      filter != CustomerFilter.all;

  CustomersState copyWith({
    CustomersStatus? status,
    List<Customer>? customers,
    String? query,
    CustomerFilter? filter,
    int? page,
    bool? hasMore,
    int? total,
    bool? loadingMore,
  }) {
    return CustomersState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }

  @override
  List<Object?> get props => [
        status,
        customers,
        query,
        filter,
        page,
        hasMore,
        total,
        loadingMore,
      ];
}

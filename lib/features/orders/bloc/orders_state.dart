part of 'orders_bloc.dart';

enum OrdersStatus { initial, loading, ready, error }

class OrdersState extends Equatable {
  const OrdersState({
    this.status = OrdersStatus.initial,
    this.orders = const [],
    this.query = '',
    this.statusFilter,
    this.purposeFilter,
    this.dateFilter = const OrdersAnyDate(),
    this.page = 1,
    this.hasMore = false,
    this.total = 0,
    this.loadingMore = false,
  });

  final OrdersStatus status;
  final List<Order> orders;
  final String query;

  /// Отбор по статусу доставки; `null` — «Все».
  final DeliveryStatus? statusFilter;

  /// Отбор по цели заказа; `null` — «Все».
  final OrderPurpose? purposeFilter;

  /// Отбор по дате. По умолчанию — за всё время: список заказов тем и
  /// отличается от экрана маршрутов, что не привязан ко дню.
  final OrdersDateFilter dateFilter;

  /// Номер последней загруженной страницы.
  final int page;

  /// На сервере есть что догрузить.
  final bool hasMore;

  /// Сколько заказов всего в выдаче — по нему подписана шапка. Это не длина
  /// списка: страниц может быть больше, чем загружено.
  final int total;

  /// Идёт догрузка следующей страницы — отдельно от [status], чтобы она не
  /// гасила уже показанный список спиннером во весь экран.
  final bool loadingMore;

  /// Отбор задан хоть чем-то, кроме поиска, — по этому признаку в пустом
  /// состоянии предлагается сбросить фильтры, а не очистить запрос.
  bool get hasFilters =>
      statusFilter != null ||
      purposeFilter != null ||
      dateFilter is! OrdersAnyDate;

  /// Список пуст из-за поиска, а не потому что заказов нет вовсе.
  bool get isEmptySearch => orders.isEmpty && query.trim().isNotEmpty;

  /// `clearStatus` и `clearPurpose` нужны, потому что `null` у обычного
  /// именованного параметра неотличим от «не передавали», а сброс фильтра в
  /// «Все» — это как раз передача `null`.
  OrdersState copyWith({
    OrdersStatus? status,
    List<Order>? orders,
    String? query,
    DeliveryStatus? statusFilter,
    bool clearStatus = false,
    OrderPurpose? purposeFilter,
    bool clearPurpose = false,
    OrdersDateFilter? dateFilter,
    int? page,
    bool? hasMore,
    int? total,
    bool? loadingMore,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      query: query ?? this.query,
      statusFilter: clearStatus ? statusFilter : (statusFilter ?? this.statusFilter),
      purposeFilter:
          clearPurpose ? purposeFilter : (purposeFilter ?? this.purposeFilter),
      dateFilter: dateFilter ?? this.dateFilter,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }

  @override
  List<Object?> get props => [
        status,
        orders,
        query,
        statusFilter,
        purposeFilter,
        dateFilter,
        page,
        hasMore,
        total,
        loadingMore,
      ];
}

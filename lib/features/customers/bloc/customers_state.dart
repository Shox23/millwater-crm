part of 'customers_bloc.dart';

enum CustomersStatus { initial, loading, ready, error }

class CustomersState extends Equatable {
  const CustomersState({
    this.status = CustomersStatus.initial,
    this.customers = const [],
    this.query = '',
  });

  final CustomersStatus status;
  final List<Customer> customers;
  final String query;

  /// Отфильтрованный список. Поиск выполняет сервер, здесь ничего не режем:
  /// локальный фильтр поверх серверного прятал бы часть найденного.
  List<Customer> get visible => customers;

  /// Список пуст из-за поиска, а не потому что база пустая.
  bool get isEmptySearch => customers.isEmpty && query.trim().isNotEmpty;

  CustomersState copyWith({
    CustomersStatus? status,
    List<Customer>? customers,
    String? query,
  }) {
    return CustomersState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [status, customers, query];
}

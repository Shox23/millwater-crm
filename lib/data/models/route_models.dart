import 'package:equatable/equatable.dart';

import '../../core/utils/money_parser.dart';
import 'enums.dart';

/// Строка списка маршрутов (AdminRouteListItem).
class RouteListItem extends Equatable {
  const RouteListItem({
    required this.id,
    required this.date,
    required this.status,
    required this.completedCount,
    required this.totalCustomers,
    required this.driverId,
    required this.driverFullName,
  });

  final String id;
  final DateTime date;
  final RouteStatus status;

  /// Сколько остановок уже завершено.
  final int completedCount;
  final int totalCustomers;
  final String driverId;
  final String driverFullName;

  factory RouteListItem.fromJson(Map<String, dynamic> json) => RouteListItem(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        status: RouteStatus.fromJson(json['status'] as String),
        completedCount: json['completed_count'] as int? ?? 0,
        totalCustomers: json['total_customers'] as int? ?? 0,
        driverId: json['driver_id'] as String,
        driverFullName: json['driver_full_name'] as String? ?? '',
      );

  @override
  List<Object?> get props =>
      [id, date, status, completedCount, totalCustomers, driverId];
}

/// Остановка маршрута — доставка конкретному заказчику (RouteCustomerResponse).
class RouteStop extends Equatable {
  const RouteStop({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.status,
    this.deliveredCapsules,
    this.paymentAmount,
    this.paymentPhoto,
    this.completedAt,
  });

  /// Идентификатор остановки (route_customer_id) — им оперируют driver-эндпоинты.
  final String id;
  final String customerId;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final DeliveryStatus status;

  /// Доставленные капсулы (серверное `delivered_bottles`).
  final int? deliveredCapsules;
  final int? paymentAmount;
  final String? paymentPhoto;
  final DateTime? completedAt;

  bool get isCompleted =>
      status == DeliveryStatus.delivered || status == DeliveryStatus.paid;

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        customerName: json['customer_full_name'] as String? ?? '',
        customerAddress: json['customer_address'] as String? ?? '',
        customerPhone: json['customer_phone'] as String? ?? '',
        status: DeliveryStatus.fromJson(json['status'] as String),
        deliveredCapsules: json['delivered_bottles'] as int?,
        paymentAmount: json['payment_amount'] == null
            ? null
            : MoneyParser.toSum(json['payment_amount']),
        paymentPhoto: json['payment_photo'] as String?,
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.parse(json['completed_at'] as String),
      );

  @override
  List<Object?> get props => [
        id,
        customerId,
        customerName,
        status,
        deliveredCapsules,
        paymentAmount,
        completedAt,
      ];
}

/// Маршрут со списком остановок (AdminRouteResponse).
class RouteDetail extends Equatable {
  const RouteDetail({
    required this.id,
    required this.date,
    required this.status,
    required this.completedCount,
    required this.totalCustomers,
    required this.driverId,
    required this.driverFullName,
    required this.stops,
  });

  final String id;
  final DateTime date;
  final RouteStatus status;
  final int completedCount;
  final int totalCustomers;
  final String driverId;
  final String driverFullName;
  final List<RouteStop> stops;

  /// Сумма собранных за маршрут оплат.
  int get collected =>
      stops.fold<int>(0, (sum, s) => sum + (s.paymentAmount ?? 0));

  factory RouteDetail.fromJson(Map<String, dynamic> json) => RouteDetail(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        status: RouteStatus.fromJson(json['status'] as String),
        completedCount: json['completed_count'] as int? ?? 0,
        totalCustomers: json['total_customers'] as int? ?? 0,
        driverId: json['driver_id'] as String,
        driverFullName: json['driver_full_name'] as String? ?? '',
        stops: ((json['route_customers'] as List?) ?? [])
            .map((e) => RouteStop.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  @override
  List<Object?> get props =>
      [id, date, status, completedCount, totalCustomers, driverId, stops];
}

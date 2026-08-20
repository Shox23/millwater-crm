import 'package:equatable/equatable.dart';

import '../../core/utils/money_parser.dart';
import 'json.dart';
import 'enums.dart';

/// Строка списка маршрутов (AdminRouteListItem или водительский RouteListItem).
///
/// Водительские эндпоинты полей водителя не отдают — маршрут и так «свой»,
/// поэтому [driverId] и [driverFullName] необязательны.
class RouteListItem extends Equatable {
  const RouteListItem({
    required this.id,
    required this.date,
    required this.status,
    required this.completedCount,
    required this.totalCustomers,
    this.driverId,
    this.driverFullName,
  });

  final String id;
  final DateTime date;
  final RouteStatus status;

  /// Сколько остановок уже завершено.
  final int completedCount;
  final int totalCustomers;
  final String? driverId;
  final String? driverFullName;

  factory RouteListItem.fromJson(Map<String, dynamic> json) => RouteListItem(
        id: requireString(json['id'], 'id'),
        date: dateOr(json['date'], epoch),
        status: RouteStatus.fromJson(stringOr(json['status'])),
        completedCount: intOr(json['completed_count']),
        totalCustomers: intOr(json['total_customers']),
        driverId: optionalString(json['driver_id']),
        driverFullName: optionalString(json['driver_full_name']),
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
    this.customerLatitude,
    this.customerLongitude,
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

  /// Координаты точки доставки, если их успел зафиксировать водитель.
  ///
  /// Пока на сервере полей нет — null, и маршрут строится по текстовому
  /// адресу через веб-версию Яндекс.Карт. См. [hasCoordinates].
  final double? customerLatitude;
  final double? customerLongitude;

  /// Доставленные капсулы (серверное `delivered_bottles`).
  final int? deliveredCapsules;
  final int? paymentAmount;
  final String? paymentPhoto;
  final DateTime? completedAt;

  /// Доставка выполнена. `failed` сюда не входит: точка закрыта, но привезти
  /// не удалось, и в «выполнено N из M» ей не место.
  bool get isCompleted => status == DeliveryStatus.delivered;

  /// Точку можно отдать нативному приложению карт, а не веб-геокодеру.
  bool get hasCoordinates =>
      customerLatitude != null && customerLongitude != null;

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
        id: requireString(json['id'], 'id'),
        customerId: stringOr(json['customer_id']),
        customerName: stringOr(json['customer_full_name']),
        customerAddress: stringOr(json['customer_address']),
        customerPhone: stringOr(json['customer_phone']),
        status: DeliveryStatus.fromJson(stringOr(json['status'])),
        // `num?`, а не `double?`: целое значение приходит из JSON как int.
        customerLatitude: optionalDouble(json['customer_latitude']),
        customerLongitude: optionalDouble(json['customer_longitude']),
        deliveredCapsules: optionalInt(json['delivered_bottles']),
        paymentAmount: json['payment_amount'] == null
            ? null
            : MoneyParser.toSum(json['payment_amount']),
        paymentPhoto: optionalString(json['payment_photo']),
        completedAt: optionalDate(json['completed_at']),
      );

  @override
  List<Object?> get props => [
        id,
        customerId,
        customerName,
        status,
        customerLatitude,
        customerLongitude,
        deliveredCapsules,
        paymentAmount,
        completedAt,
      ];
}

/// Маршрут со списком остановок (AdminRouteResponse или водительский RouteResponse).
class RouteDetail extends Equatable {
  const RouteDetail({
    required this.id,
    required this.date,
    required this.status,
    required this.completedCount,
    required this.totalCustomers,
    this.driverId,
    this.driverFullName,
    required this.stops,
  });

  final String id;
  final DateTime date;
  final RouteStatus status;
  final int completedCount;
  final int totalCustomers;

  /// См. [RouteListItem.driverId] — у водительских ответов полей нет.
  final String? driverId;
  final String? driverFullName;
  final List<RouteStop> stops;

  /// Сумма собранных за маршрут оплат.
  int get collected =>
      stops.fold<int>(0, (sum, s) => sum + (s.paymentAmount ?? 0));

  factory RouteDetail.fromJson(Map<String, dynamic> json) => RouteDetail(
        id: requireString(json['id'], 'id'),
        date: dateOr(json['date'], epoch),
        status: RouteStatus.fromJson(stringOr(json['status'])),
        completedCount: intOr(json['completed_count']),
        totalCustomers: intOr(json['total_customers']),
        driverId: optionalString(json['driver_id']),
        driverFullName: optionalString(json['driver_full_name']),
        // Точка без идентификатора пропускается: открыть и завершить её всё
        // равно нечем, а из-за неё терялся бы весь маршрут.
        stops: parseList(json['route_customers'], RouteStop.fromJson),
      );

  @override
  List<Object?> get props =>
      [id, date, status, completedCount, totalCustomers, driverId, stops];
}

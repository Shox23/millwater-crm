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
    this.paymentMethod,
    this.paymentPhoto,
    this.completedAt,
    this.customerCoolerCount = 0,
    this.sequence,
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

  /// Чем заплатили (`payment_method`). `null` — точка ещё не закрыта.
  ///
  /// Сервер отдавал это поле и раньше, а модель его не читала — из-за чего
  /// десктоп угадывал «в долг» по нулевой сумме. Угадывание врало на любой
  /// доставке, закрытой с нулевой суммой по другой причине.
  final PaymentMethod? paymentMethod;

  final String? paymentPhoto;
  final DateTime? completedAt;

  /// Сколько кулеров у заказчика (`customer_cooler_count`).
  final int customerCoolerCount;

  /// Порядковый номер точки в маршруте (`sequence`, ранее `order`).
  final int? sequence;

  /// Доставка выполнена. `failed` сюда не входит: точка закрыта, но привезти
  /// не удалось, и в «выполнено N из M» ей не место.
  bool get isCompleted => status == DeliveryStatus.delivered;

  /// У заказчика стоит кулер — производное от [customerCoolerCount], как и
  /// на сервере.
  bool get customerHasCooler => customerCoolerCount > 0;

  /// Доставку закрыли в долг.
  ///
  /// Спрашивать надо здесь, а не сравнивать сумму с нулём: у закрытой в долг
  /// точки сумма оплаты и обязана быть нулевой, но нулевая сумма сама по себе
  /// долга не означает.
  bool get isDebt => paymentMethod == PaymentMethod.debt;

  /// Точку можно отдать нативному приложению карт, а не веб-геокодеру.
  bool get hasCoordinates =>
      customerLatitude != null && customerLongitude != null;

  /// Копия с изменёнными полями.
  ///
  /// Нужна демо-режиму: пересобирать точку конструктором значило бы каждый раз
  /// перечислять все поля, и новое поле молча терялось бы при первом же
  /// изменении статуса — именно так демо и разъезжалось с сервером.
  RouteStop copyWith({
    DeliveryStatus? status,
    double? customerLatitude,
    double? customerLongitude,
    int? deliveredCapsules,
    int? paymentAmount,
    PaymentMethod? paymentMethod,
    String? paymentPhoto,
    DateTime? completedAt,
  }) {
    return RouteStop(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerAddress: customerAddress,
      customerPhone: customerPhone,
      status: status ?? this.status,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      deliveredCapsules: deliveredCapsules ?? this.deliveredCapsules,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentPhoto: paymentPhoto ?? this.paymentPhoto,
      completedAt: completedAt ?? this.completedAt,
      customerCoolerCount: customerCoolerCount,
      sequence: sequence,
    );
  }

  /// Разбор терпим к трём формам ответа.
  ///
  /// Точки маршрута сервер отдаёт то плоскими полями (`customer_full_name`
  /// в корне записи), то вложенным объектом `customer` — сперва с короткими
  /// ключами (`full_name`), затем с префиксными (`customer_full_name`).
  /// На новой форме плоское чтение оставляло точку без имени, адреса и
  /// телефона: водитель видел список пустых карточек и не знал, куда ехать.
  factory RouteStop.fromJson(Map<String, dynamic> json) {
    final customer = objectOr(json['customer']);

    return RouteStop(
        id: requireString(json['id'], 'id'),
        customerId: stringOr(firstNonNull([
          customer['customer_id'],
          customer['id'],
          json['customer_id'],
        ])),
        customerName: stringOr(firstNonNull([
          customer['customer_full_name'],
          customer['full_name'],
          json['customer_full_name'],
        ])),
        customerAddress: stringOr(firstNonNull([
          customer['customer_address'],
          customer['address'],
          json['customer_address'],
        ])),
        customerPhone: stringOr(firstNonNull([
          customer['customer_phone'],
          customer['phone'],
          json['customer_phone'],
        ])),
        status: DeliveryStatus.fromJson(stringOr(json['status'])),
        // `num?`, а не `double?`: целое значение приходит из JSON как int.
        customerLatitude: optionalDouble(json['customer_latitude']),
        customerLongitude: optionalDouble(json['customer_longitude']),
        deliveredCapsules: optionalInt(json['delivered_bottles']),
        // `payment_amount` сервер переименовал в `order_amount`; на новой
        // форме старый ключ отсутствует, и сумма показывалась пустой.
        paymentAmount: _money(firstNonNull([
          json['order_amount'],
          json['payment_amount'],
        ])),
        paymentMethod: _method(json['payment_method']),
        paymentPhoto: optionalString(json['payment_photo']),
        completedAt: optionalDate(json['completed_at']),
        // `customer_has_cooler` сервер отдавал до переименования точек в
        // заказы; сборка с этим кодом может смотреть и на такой стенд.
        customerCoolerCount: optionalInt(firstNonNull([
              customer['customer_cooler_count'],
              customer['cooler_count'],
              json['customer_cooler_count'],
            ])) ??
            (boolOr(json['customer_has_cooler']) ? 1 : 0),
        // `order` — прежнее имя поля. Сервер переименовал его в `sequence`,
        // и оба имени встречаются в зависимости от версии стенда.
        sequence: optionalInt(json['sequence']) ?? optionalInt(json['order']),
      );
  }

  /// Деньги: `null` отличается от нуля — у незакрытой точки суммы нет вовсе.
  static int? _money(Object? value) =>
      value == null ? null : MoneyParser.toSum(value);

  static PaymentMethod? _method(Object? value) {
    final wire = optionalString(value);
    if (wire == null) return null;
    for (final method in PaymentMethod.values) {
      if (method.wire == wire) return method;
    }
    // Незнакомый способ оплаты — не повод терять точку: сумму и статус
    // показать всё ещё можно, а подпись способа просто не появится.
    return null;
  }

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
        paymentMethod,
        completedAt,
        customerCoolerCount,
        sequence,
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
        //
        // Ключей два: `route_customers` был до релиза, `orders` — после
        // переименования точек в заказы. Читать только новый нельзя —
        // приложение с этим кодом обязано работать и со старым стендом; и
        // ровно на этом расхождении маршрут однажды открылся пустым.
        stops: parseList(
          json['orders'] ?? json['route_customers'],
          RouteStop.fromJson,
        ),
      );

  @override
  List<Object?> get props =>
      [id, date, status, completedCount, totalCustomers, driverId, stops];
}

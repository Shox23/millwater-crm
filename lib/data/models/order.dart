import 'package:equatable/equatable.dart';

import '../../core/utils/money_parser.dart';
import 'enums.dart';
import 'json.dart';

/// Query-параметры отбора заказов, общие у `/admin/orders` и `/driver/orders`.
///
/// Живут рядом с моделью, а не в админском репозитории: списки заказов у двух
/// ролей отличаются только тем, что водителю нельзя задать `driver_id` —
/// сервер подставит его сам. Складывать этот словарь в `ApiCrmRepository`
/// значило бы, что водительская реализация импортирует админскую.
///
/// Пустые значения не отправляются: у сервера «не фильтровать» — это
/// отсутствие параметра, а не его пустое значение.
Map<String, dynamic> orderFilterQuery({
  DateTime? dateFrom,
  DateTime? dateTo,
  String? customerId,
  String? driverId,
  String? routeId,
  DeliveryStatus? status,
  OrderPurpose? purpose,
  PaymentMethod? paymentMethod,
  String? search,
}) =>
    {
      if (dateFrom != null) 'date_from': formatApiDate(dateFrom),
      if (dateTo != null) 'date_to': formatApiDate(dateTo),
      'customer_id': ?customerId,
      'driver_id': ?driverId,
      'route_id': ?routeId,
      if (status != null) 'status': status.toJson(),
      if (purpose != null) 'purpose': purpose.toJson(),
      if (paymentMethod != null) 'payment_method': paymentMethod.toJson(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

/// Дата в формате `YYYY-MM-DD`, как ожидают query-параметры API.
String formatApiDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Заказ — то, чем раньше была точка маршрута (`route_customers` → `orders`).
///
/// Отдельная модель, а не расширенный [RouteStop]: сервер отдаёт заказ двумя
/// разными схемами. Внутри маршрута — плоская и короткая (её разбирает
/// `RouteStop`), в списках `/admin/orders` и `/driver/orders` — вот эта, с
/// вложенными `customer` и `route` и с деньгами. Склеивать их в один класс
/// значило бы завести модель, у которой половина полей всегда пустая, и
/// каждый экран гадал бы, какая именно половина.
class Order extends Equatable {
  const Order({
    required this.id,
    required this.number,
    this.sequence,
    required this.status,
    required this.purpose,
    this.paymentMethod,
    this.deliveredCapsules,
    this.returnedCapsules,
    this.damagedCapsules,
    this.capsuleBalanceAfter,
    this.orderAmount,
    this.waterPriceApplied,
    this.damagedFineApplied,
    this.completedAt,
    required this.createdAt,
    required this.customerId,
    required this.customerName,
    this.customerPhone = '',
    this.customerAddress = '',
    this.routeId,
    this.routeDate,
    this.driverId,
    this.driverFullName,
  });

  final String id;

  /// Читаемый номер заказа (`number`) — им заказ называют вслух.
  final int number;

  /// Порядок точки внутри маршрута.
  final int? sequence;

  final DeliveryStatus status;
  final OrderPurpose purpose;
  final PaymentMethod? paymentMethod;

  /// Капсулы: привезли, забрали пустых, забрали повреждённых.
  final int? deliveredCapsules;
  final int? returnedCapsules;
  final int? damagedCapsules;

  /// Остаток капсул у заказчика после заказа (`bottle_balance_after`).
  final int? capsuleBalanceAfter;

  /// Итоговая стоимость заказа, сум.
  final int? orderAmount;

  /// Снимки цен, по которым посчитали. Нужны именно снимки: прайс
  /// накопительный, и отчёт за прошлый месяц обязан показать ту сумму,
  /// которую человек заплатил, а не пересчитанную по сегодняшней цене.
  final int? waterPriceApplied;
  final int? damagedFineApplied;

  final DateTime? completedAt;
  final DateTime createdAt;

  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;

  final String? routeId;
  final DateTime? routeDate;
  final String? driverId;
  final String? driverFullName;

  /// Заказ закрыт доставкой. `failed` сюда не входит — см. `RouteStop`.
  bool get isCompleted => status == DeliveryStatus.delivered;

  /// Заказ закрыли в долг.
  bool get isDebt => paymentMethod == PaymentMethod.debt;

  /// У заказа маршрут без назначенного водителя.
  bool get hasNoDriver => driverId == null;

  /// Разбор терпим: обязателен только `id`. Незнакомая цель, отсутствующие
  /// деньги (заказ ещё не закрыт) и старый плоский ответ не должны стоить
  /// строки в списке.
  factory Order.fromJson(Map<String, dynamic> json) {
    // Списочный ответ вкладывает заказчика и маршрут в объекты, а контракт в
    // docs/tz описывает те же поля плоскими. Читаем оба вида: расхождение
    // живое, и переезд контракта не должен опустошать карточку.
    //
    // Внутри объекта ключи тоже сменились: сперва сервер отдавал `full_name`,
    // теперь `customer_full_name`. На префиксной форме карточка молча
    // осталась бы без имени, телефона и адреса — заказ есть, а чей он,
    // непонятно.
    final customer = objectOr(json['customer']);
    final route = objectOr(json['route']);

    return Order(
      id: requireString(json['id'], 'id'),
      number: intOr(json['number']),
      sequence: optionalInt(json['sequence']) ?? optionalInt(json['order']),
      status: DeliveryStatus.fromJson(stringOr(json['status'])),
      purpose: OrderPurpose.fromJson(stringOr(json['purpose'])),
      paymentMethod: _method(json['payment_method']),
      deliveredCapsules: optionalInt(json['delivered_bottles']),
      returnedCapsules: optionalInt(json['returned_bottles']),
      damagedCapsules: optionalInt(json['damaged_bottles']),
      capsuleBalanceAfter: optionalInt(json['bottle_balance_after']),
      orderAmount: _money(json['order_amount']),
      waterPriceApplied: _money(json['water_price_applied']),
      damagedFineApplied: _money(json['damaged_fine_applied']),
      completedAt: optionalDate(json['completed_at']),
      createdAt: dateOr(json['created_at'], epoch),
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
      customerPhone: stringOr(firstNonNull([
        customer['customer_phone'],
        customer['phone'],
        json['customer_phone'],
      ])),
      customerAddress: stringOr(firstNonNull([
        customer['customer_address'],
        customer['address'],
        json['customer_address'],
      ])),
      routeId: optionalString(firstNonNull([
        route['route_id'],
        route['id'],
        json['route_id'],
      ])),
      routeDate: optionalDate(firstNonNull([
        route['route_date'],
        route['date'],
        json['route_date'],
      ])),
      driverId: optionalString(firstNonNull([
        route['driver_id'],
        json['driver_id'],
      ])),
      // Имя водителя живёт внутри маршрута; плоский вариант остался от
      // прежней формы ответа.
      driverFullName: optionalString(firstNonNull([
        route['driver_full_name'],
        json['driver_full_name'],
      ])),
    );
  }

  /// Деньги: `null` отличается от нуля. У незакрытого заказа суммы нет вовсе,
  /// и показывать её нулём значило бы «привезли бесплатно».
  static int? _money(Object? value) =>
      value == null ? null : MoneyParser.toSum(value);

  static PaymentMethod? _method(Object? value) {
    final wire = optionalString(value);
    if (wire == null) return null;
    for (final method in PaymentMethod.values) {
      if (method.wire == wire) return method;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        number,
        sequence,
        status,
        purpose,
        paymentMethod,
        deliveredCapsules,
        returnedCapsules,
        damagedCapsules,
        capsuleBalanceAfter,
        orderAmount,
        waterPriceApplied,
        damagedFineApplied,
        completedAt,
        createdAt,
        customerId,
        customerName,
        customerPhone,
        customerAddress,
        routeId,
        routeDate,
        driverId,
        driverFullName,
      ];
}

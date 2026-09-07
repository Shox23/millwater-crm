import 'package:equatable/equatable.dart';

import '../../core/utils/money_parser.dart';
import 'enums.dart';
import 'json.dart';

/// Строки трёх отчётов сервера (`GET /admin/reports/{general,customers,drivers}`).
///
/// Отчёты пришли на смену `GET /admin/reports/summary`, которого больше нет.
/// Форма ответа у всех трёх одинаковая и непривычная для этого API: **голый
/// массив строк**, без конверта `{items, total, page}`. Поэтому здесь именно
/// «строки», а не сущности: сервер отдаёт готовый разрез, а не справочник.
///
/// Все три принимают один набор параметров — `date_from`, `date_to`,
/// `driver_id`. Периода в самой строке нет: его задаёт запрос.

/// Строка общего отчёта: одна доставка одного дня.
class GeneralReportRow extends Equatable {
  const GeneralReportRow({
    required this.date,
    required this.driverName,
    required this.customer,
    required this.deliveredCapsules,
    required this.returnedCapsules,
    required this.damagedCapsules,
    required this.coolerCount,
    required this.orderAmount,
  });

  final DateTime date;
  final String driverName;

  /// `customer_name_or_address` — сервер сам решает, что показать. Разбирать
  /// это поле на имя и адрес нельзя: разделителя в нём не гарантировано.
  final String customer;

  final int deliveredCapsules;
  final int returnedCapsules;
  final int damagedCapsules;
  final int coolerCount;

  /// Стоимость заказа, сум.
  final int orderAmount;

  factory GeneralReportRow.fromJson(Map<String, dynamic> json) =>
      GeneralReportRow(
        date: optionalDate(json['date']) ?? epoch,
        driverName: stringOr(json['driver_full_name']),
        customer: stringOr(json['customer_name_or_address']),
        deliveredCapsules: intOr(json['delivered_bottles']),
        returnedCapsules: intOr(json['returned_bottles']),
        damagedCapsules: intOr(json['damaged_bottles']),
        coolerCount: intOr(json['cooler_count']),
        orderAmount: MoneyParser.toSum(json['order_amount']),
      );

  @override
  List<Object?> get props => [
        date,
        driverName,
        customer,
        deliveredCapsules,
        returnedCapsules,
        damagedCapsules,
        coolerCount,
        orderAmount,
      ];
}

/// Строка отчёта по заказчикам: итог одного заказчика за период.
///
/// Заменяет выкачивание всего справочника заказчиков ради должников и
/// остатка капсул: долг, предоплата и остаток теперь приходят готовыми,
/// причём только по тем, кто за период что-то заказывал.
class CustomerReportRow extends Equatable {
  const CustomerReportRow({
    required this.customerId,
    required this.name,
    required this.address,
    required this.phone,
    required this.capsulesPurchased,
    required this.bulkLiters,
    required this.damagedCapsules,
    required this.capsuleBalance,
    required this.coolerCount,
    required this.debt,
    required this.prepayment,
    required this.total,
  });

  final String customerId;
  final String name;
  final String address;
  final String phone;

  /// Куплено капсул 19 л за период (`bottles_purchased_in_period`).
  final int capsulesPurchased;

  /// Опт за период, **в литрах** (`bulk_liters_purchased`), — не в бутылях:
  /// 5 л и 10 л сервер сводит к одному числу.
  final int bulkLiters;

  final int damagedCapsules;

  /// Остаток капсул и кулеры — на момент выгрузки, не на конец периода.
  final int capsuleBalance;
  final int coolerCount;

  /// Долг и предоплата на момент выгрузки, сум.
  final int debt;
  final int prepayment;

  /// Реализация за период, сум (`total_realization`).
  final int total;

  factory CustomerReportRow.fromJson(Map<String, dynamic> json) =>
      CustomerReportRow(
        customerId: stringOr(json['customer_id']),
        name: stringOr(json['full_name']),
        address: stringOr(json['address']),
        phone: stringOr(json['phone']),
        capsulesPurchased: intOr(json['bottles_purchased_in_period']),
        bulkLiters: intOr(json['bulk_liters_purchased']),
        damagedCapsules: intOr(json['damaged_bottles_count']),
        capsuleBalance: intOr(json['current_bottle_balance']),
        coolerCount: intOr(json['current_cooler_count']),
        debt: MoneyParser.toSum(json['debt']),
        prepayment: MoneyParser.toSum(json['prepayment']),
        total: MoneyParser.toSum(json['total_realization']),
      );

  @override
  List<Object?> get props => [
        customerId,
        name,
        address,
        phone,
        capsulesPurchased,
        bulkLiters,
        damagedCapsules,
        capsuleBalance,
        coolerCount,
        debt,
        prepayment,
        total,
      ];
}

/// Строка отчёта по водителям: один заказ одного маршрута.
///
/// Вопреки названию, строка не про водителя целиком, а про заказ; сводку по
/// водителю собирает экран, группируя строки по [driverId].
class DriverReportRow extends Equatable {
  const DriverReportRow({
    required this.routeId,
    required this.date,
    required this.driverId,
    required this.driverName,
    required this.customer,
    required this.purpose,
    required this.deliveredCapsules,
    required this.returnedCapsules,
    this.capsuleBalanceAfter,
    this.paymentMethod,
    required this.orderAmount,
    required this.bulkLiters,
    required this.bulkAmount,
    required this.routeExpenses,
  });

  final String routeId;
  final DateTime date;
  final String driverId;
  final String driverName;
  final String customer;
  final OrderPurpose purpose;

  final int deliveredCapsules;
  final int returnedCapsules;
  final int? capsuleBalanceAfter;
  final PaymentMethod? paymentMethod;

  final int orderAmount;
  final int bulkLiters;
  final int bulkAmount;

  /// Расходы **по всему маршруту**, а не по этой строке: у каждого заказа
  /// одного маршрута число одинаковое. Складывать его по строкам нельзя —
  /// расходы посчитались бы столько раз, сколько в маршруте заказов.
  final int routeExpenses;

  factory DriverReportRow.fromJson(Map<String, dynamic> json) =>
      DriverReportRow(
        routeId: stringOr(json['route_id']),
        date: optionalDate(json['route_date']) ?? epoch,
        driverId: stringOr(json['driver_id']),
        driverName: stringOr(json['driver_full_name']),
        customer: stringOr(json['customer_name_or_address']),
        purpose: OrderPurpose.fromJson(stringOr(json['purpose'])),
        deliveredCapsules: intOr(json['delivered_bottles']),
        returnedCapsules: intOr(json['returned_bottles']),
        capsuleBalanceAfter: optionalInt(json['bottle_balance_after']),
        paymentMethod: PaymentMethod.tryFromJson(json['payment_method']),
        orderAmount: MoneyParser.toSum(json['order_amount']),
        bulkLiters: intOr(json['bulk_liters_sold_count']),
        bulkAmount: MoneyParser.toSum(json['bulk_sale_amount']),
        routeExpenses: MoneyParser.toSum(json['route_expenses_total']),
      );

  @override
  List<Object?> get props => [
        routeId,
        date,
        driverId,
        driverName,
        customer,
        purpose,
        deliveredCapsules,
        returnedCapsules,
        capsuleBalanceAfter,
        paymentMethod,
        orderAmount,
        bulkLiters,
        bulkAmount,
        routeExpenses,
      ];
}

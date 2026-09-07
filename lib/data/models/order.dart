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

/// Строка истории платежей заказа (`PaymentResponse`).
///
/// Правка оплаты админом не переписывает исходный платёж, а дописывает
/// разницу отдельной строкой — поэтому у заказа их может быть несколько, и
/// сумма принятого складывается из всех.
class OrderPayment extends Equatable {
  const OrderPayment({
    required this.id,
    required this.amount,
    this.method,
    this.note,
    this.photoUrl,
    this.recordedByUserId,
    required this.createdAt,
  });

  final String id;

  /// Сумма строки, сум. Отрицательная означает возврат: админ уменьшил
  /// итоговую сумму заказа, и разница вернулась заказчику.
  final int amount;
  final PaymentMethod? method;
  final String? note;
  final String? photoUrl;

  /// Кто провёл платёж. `null` у строк, заведённых до релиза: сервер добавил
  /// колонку с пустым значением и заполнить её задним числом нечем.
  final String? recordedByUserId;
  final DateTime createdAt;

  /// Возврат денег заказчику, а не приём.
  bool get isRefund => amount < 0;

  factory OrderPayment.fromJson(Map<String, dynamic> json) => OrderPayment(
        id: requireString(json['id'], 'id'),
        amount: MoneyParser.toSum(json['amount']),
        method: PaymentMethod.tryFromJson(json['payment_method']),
        note: optionalString(json['note']),
        photoUrl: optionalString(json['photo_url']),
        recordedByUserId: optionalString(json['recorded_by_user_id']),
        createdAt: dateOr(json['created_at'], epoch),
      );

  @override
  List<Object?> get props =>
      [id, amount, method, note, photoUrl, recordedByUserId, createdAt];
}

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
    this.paidAmount,
    this.waterPriceApplied,
    this.damagedFineApplied,
    this.effectiveWaterPrice,
    this.damagedBottleFine,
    this.bulk5lCount,
    this.bulk5lPrice,
    this.bulk10lCount,
    this.bulk10lPrice,
    this.pickedCoolers,
    this.pickedBottles,
    this.payments = const [],
    this.completedAt,
    required this.createdAt,
    required this.customerId,
    required this.customerName,
    this.customerPhone = '',
    this.customerAddress = '',
    this.customerCoolerCount = 0,
    this.customerDebt = 0,
    this.customerPrepayment = 0,
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

  /// Сколько по заказу уже принято — сумма истории платежей.
  ///
  /// Отличается от [orderAmount]: у заказов, закрытых до релиза, стоимость
  /// осталась нулём, а деньги по ним приняты. Экран правки оплаты обязан
  /// показывать именно это число — иначе админ, введя меньшую сумму, молча
  /// вернёт заказчику разницу.
  final int? paidAmount;

  /// Снимки цен, по которым посчитали. Нужны именно снимки: прайс
  /// накопительный, и отчёт за прошлый месяц обязан показать ту сумму,
  /// которую человек заплатил, а не пересчитанную по сегодняшней цене.
  final int? waterPriceApplied;
  final int? damagedFineApplied;

  /// Цена капсулы **для этого заказчика** и общий штраф за брак — их сервер
  /// отдаёт у незакрытого заказа, чтобы водитель считал по той же цене, что
  /// и сервер. У заказчика с индивидуальной ценой общий прайс врёт.
  final int? effectiveWaterPrice;
  final int? damagedBottleFine;

  /// Опт: бутыли 5 л и 10 л. Цена договорная, её вводит водитель.
  final int? bulk5lCount;
  final int? bulk5lPrice;
  final int? bulk10lCount;
  final int? bulk10lPrice;

  /// Вывоз: сколько кулеров и капсул забрали у заказчика.
  final int? pickedCoolers;
  final int? pickedBottles;

  /// История платежей по заказу.
  final List<OrderPayment> payments;

  final DateTime? completedAt;
  final DateTime createdAt;

  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;

  /// Баланс и кулеры заказчика — сервер кладёт их прямо в заказ, и отдельный
  /// запрос карточки заказчика ради двух чисел больше не нужен.
  final int customerCoolerCount;
  final int customerDebt;
  final int customerPrepayment;

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

  /// Заказчику посчитали капсулы не по общему прайсу.
  ///
  /// Сравниваем снимок цены с действующей для этого заказчика: у закрытого
  /// заказа врать может любая из них по отдельности — прайс с тех пор мог
  /// смениться, — а вот их расхождение означает ровно одно, индивидуальную
  /// цену. Пока цены не пришли обе, признака нет: показать «своя цена» по
  /// одной половине данных значило бы гадать.
  bool get hasIndividualPrice {
    final applied = waterPriceApplied;
    final effective = effectiveWaterPrice;
    if (applied == null || effective == null) return false;
    return applied != effective;
  }

  /// Стоимость опта в заказе, сум: 5 л и 10 л по договорной цене.
  int get bulkTotal =>
      (bulk5lCount ?? 0) * (bulk5lPrice ?? 0) +
      (bulk10lCount ?? 0) * (bulk10lPrice ?? 0);

  /// Сколько по заказу осталось получить, сум.
  ///
  /// Отрицательным не бывает: переплата — это предоплата заказчика, а не
  /// «минус долг по заказу», и показывать её здесь значило бы считать одни
  /// и те же деньги дважды.
  int get unpaid {
    final due = (orderAmount ?? 0) - (paidAmount ?? 0);
    return due > 0 ? due : 0;
  }

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
      paymentMethod: PaymentMethod.tryFromJson(json['payment_method']),
      deliveredCapsules: optionalInt(json['delivered_bottles']),
      returnedCapsules: optionalInt(json['returned_bottles']),
      damagedCapsules: optionalInt(json['damaged_bottles']),
      capsuleBalanceAfter: optionalInt(json['bottle_balance_after']),
      orderAmount: _money(json['order_amount']),
      paidAmount: _money(json['paid_amount']),
      waterPriceApplied: _money(json['water_price_applied']),
      damagedFineApplied: _money(json['damaged_fine_applied']),
      effectiveWaterPrice: _money(json['effective_water_price']),
      damagedBottleFine: _money(json['damaged_bottle_fine']),
      bulk5lCount: optionalInt(json['bulk_5l_count']),
      bulk5lPrice: _money(json['bulk_5l_price']),
      bulk10lCount: optionalInt(json['bulk_10l_count']),
      bulk10lPrice: _money(json['bulk_10l_price']),
      pickedCoolers: optionalInt(json['picked_coolers']),
      pickedBottles: optionalInt(json['picked_bottles']),
      // Строка без `id` пропускается, а не роняет заказ: история платежей —
      // справка, из-за неё терять карточку незачем.
      payments: parseList(json['payments'], OrderPayment.fromJson),
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
      customerCoolerCount: intOr(firstNonNull([
        customer['customer_cooler_count'],
        customer['cooler_count'],
        json['customer_cooler_count'],
      ])),
      customerDebt: _money(firstNonNull([
            customer['customer_debt'],
            customer['debt'],
          ])) ??
          0,
      customerPrepayment: _money(firstNonNull([
            customer['customer_prepayment'],
            customer['prepayment'],
          ])) ??
          0,
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
        paidAmount,
        waterPriceApplied,
        damagedFineApplied,
        effectiveWaterPrice,
        damagedBottleFine,
        bulk5lCount,
        bulk5lPrice,
        bulk10lCount,
        bulk10lPrice,
        pickedCoolers,
        pickedBottles,
        payments,
        completedAt,
        createdAt,
        customerId,
        customerName,
        customerPhone,
        customerAddress,
        customerCoolerCount,
        customerDebt,
        customerPrepayment,
        routeId,
        routeDate,
        driverId,
        driverFullName,
      ];
}

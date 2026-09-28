import 'package:equatable/equatable.dart';

import '../../core/utils/money_parser.dart';
import '../../core/utils/visit_order.dart';
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
    this.cashCollected,
    this.cashlessCollected,
    this.debtAmount,
    this.expensesTotal,
    this.cashBalance,  });

  final String id;
  final DateTime date;
  final RouteStatus status;

  /// Сколько остановок уже завершено.
  final int completedCount;
  final int totalCustomers;
  final String? driverId;
  final String? driverFullName;

  /// Касса маршрута, как её посчитал сервер.
  ///
  /// `null` — стенд ещё не отдаёт этих полей; тогда наличные считаются
  /// локально по точкам (см. [collected]). Держать локальный подсчёт
  /// запасным вариантом обязательно: сборка живёт в сторах месяцами.
  final int? cashCollected;
  final int? cashlessCollected;
  final int? debtAmount;
  final int? expensesTotal;

  /// Сколько наличных должно остаться у водителя: собранное минус расходы.
  final int? cashBalance;

  factory RouteListItem.fromJson(Map<String, dynamic> json) => RouteListItem(
        id: requireString(json['id'], 'id'),
        date: dateOr(json['date'], epoch),
        status: RouteStatus.fromJson(stringOr(json['status'])),
        completedCount: intOr(json['completed_count']),
        totalCustomers: intOr(json['total_customers']),
        driverId: optionalString(json['driver_id']),
        driverFullName: optionalString(json['driver_full_name']),
        cashCollected: _money(json['cash_collected']),
        cashlessCollected: _money(json['cashless_collected']),
        debtAmount: _money(json['debt_amount']),
        expensesTotal: _money(json['expenses_total']),
        cashBalance: _money(json['cash_balance']),
      );

  /// Деньги: `null` отличается от нуля — у стенда без кассы полей нет вовсе.
  static int? _money(Object? value) =>
      value == null ? null : MoneyParser.toSum(value);

  @override
  List<Object?> get props => [
        id,
        date,
        status,
        completedCount,
        totalCustomers,
        driverId,
        cashCollected,
        cashlessCollected,
        debtAmount,
        expensesTotal,
        cashBalance,
      ];
}

/// Точка будущего маршрута: кого добавляем и зачем.
///
/// Отдельный тип, а не голый список идентификаторов: сервер принимает
/// `customer_orders: [{customer_id, order_purpose, sequence}]`, и маршрут
/// может быть смешанным — по дороге и капсулы завезли, и кулер забрали.
class RouteOrderInput extends Equatable {
  const RouteOrderInput({
    required this.customerId,
    this.purpose,
    this.sequence,
    this.bottleSellCount,
    this.customPrice,
    this.comment,
  });

  final String customerId;

  /// `null` — берётся цель маршрута. Своя цель нужна только тем точкам,
  /// которые от неё отличаются.
  final OrderPurpose? purpose;

  /// Порядок объезда. `null` — сервер поставит следующим номером.
  final int? sequence;

  /// Сколько капсул везти этому заказчику — задание водителю, а не факт.
  /// Осмысленно только у доставки 19 л: вывозу и опту везти нечего.
  final int? bottleSellCount;

  /// Договорная сумма за **весь** заказ, сум (`order_custom_price`).
  ///
  /// Не цена капсулы: при закрытии сервер записывает её в стоимость заказа
  /// как есть, сколько бы капсул ни привезли, и штраф с возвратом к ней не
  /// добавляет. `null` — считается по прайсу.
  final int? customPrice;

  /// Комментарий водителю к этой точке — «позвонить с парковки», «ключ у
  /// охраны». Необязателен; `null` — комментария нет.
  ///
  /// Задаётся только при добавлении точки: правки комментария у сервера нет,
  /// как нет её у задания в капсулах и договорной цены.
  final String? comment;

  @override
  List<Object?> get props =>
      [customerId, purpose, sequence, bottleSellCount, customPrice, comment];
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
    this.customerBottleBalance,
    this.sequence,
    this.purpose = OrderPurpose.delivery19l,
    this.returnedCapsules,
    this.returnedFullCapsules,
    this.damagedCapsules,
    this.cancelReason,
    this.cancelledAt,
    this.comment,
    this.pickedCoolers,
    this.pickedBottles,
    this.bulk5lCount,
    this.bulk5lPrice,
    this.bulk10lCount,
    this.bulk10lPrice,
    this.capsuleBalanceAfter,
    this.effectiveWaterPrice,
    this.damagedBottleFine,
    this.bottleSellCount,
    this.customPrice,
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

  /// Остаток капсул у заказчика на момент выдачи маршрута
  /// (`customer_bottle_balance`).
  ///
  /// `null` — стенд поля ещё не отдаёт: тогда экран завершения считает остаток
  /// от нуля, то есть отправит одни привезённые.
  final int? customerBottleBalance;

  /// Порядковый номер точки в маршруте (`sequence`, ранее `order`).
  final int? sequence;

  /// Зачем едем: доставка капсул, вывоз или опт. От неё зависит и экран
  /// завершения, и то, как считается сумма.
  final OrderPurpose purpose;

  /// Забрано пустых и повреждённых — заполняются при завершении.
  final int? returnedCapsules;
  final int? damagedCapsules;

  /// Сколько полных капсул заказчик вернул (`returned_full_bottles`).
  /// Пустая тара — это [returnedCapsules]; здесь вода, которая уходит из
  /// остатка заказчика.
  final int? returnedFullCapsules;

  /// Причина и время отмены — у точки со статусом `cancelled`.
  final String? cancelReason;
  final DateTime? cancelledAt;

  /// Комментарий админа водителю (`comment` у заказа), до 255 символов.
  ///
  /// Пишется при добавлении точки в маршрут и дальше только показывается:
  /// менять его сервер не умеет. Пустую строку считаем отсутствием — иначе
  /// карточка показывала бы пустую плашку «Комментарий».
  final String? comment;

  /// Что увезли при цели «вывоз» и что продали при цели «опт».
  ///
  /// Без них закрытая точка вывоза выглядела как «0 капсул»: карточка знала
  /// только про доставленные капсулы, и вся работа водителя — два кулера и
  /// три капсулы — из маршрута пропадала.
  final int? pickedCoolers;
  final int? pickedBottles;
  final int? bulk5lCount;
  final int? bulk10lCount;

  /// Договорные цены опта, по которым закрыли точку. Нужны карточке точки:
  /// без них «12 × 10 л» не превращается в сумму, и проверить расчёт нечем.
  final int? bulk5lPrice;
  final int? bulk10lPrice;

  /// Остаток капсул у заказчика после этой доставки (`bottle_balance_after`).
  final int? capsuleBalanceAfter;

  /// Цена капсулы **для этого заказчика** и штраф за брак, как их посчитал
  /// сервер. У заказчика с индивидуальной ценой общий прайс врёт, и расчёт
  /// водителя разошёлся бы с серверным — разницу сервер записал бы в долг.
  final int? effectiveWaterPrice;
  final int? damagedBottleFine;

  /// Сколько капсул админ назначил к доставке (`bottle_sell_count`).
  ///
  /// Это задание, а не факт: сколько привезли на самом деле, водитель
  /// отмечает сам при завершении. `null` — задание не ставили (так у всех
  /// заказов, заведённых до появления поля).
  final int? bottleSellCount;

  /// Договорная сумма за весь заказ (`custom_price`), сум; `null` — по
  /// прайсу. Сервер при закрытии ставит её в стоимость заказа целиком, не
  /// считая капсулы, штраф и возврат, — и, увы, отдаёт её же в
  /// `effective_water_price`. Поэтому при заданной сумме цена капсулы для
  /// расчёта не используется вовсе.
  final int? customPrice;

  /// Доставка выполнена. `failed` сюда не входит: точка закрыта, но привезти
  /// не удалось, и в «выполнено N из M» ей не место.
  bool get isCompleted => status == DeliveryStatus.delivered;

  /// Точка отменена — админом или самим водителем.
  bool get isCancelled => status == DeliveryStatus.cancelled;

  /// У заказчика стоит кулер — производное от [customerCoolerCount], как и
  /// на сервере.
  bool get customerHasCooler => customerCoolerCount > 0;

  /// Доставку закрыли в долг.
  ///
  /// Спрашивать надо здесь, а не сравнивать сумму с нулём: у закрытой в долг
  /// точки сумма оплаты и обязана быть нулевой, но нулевая сумма сама по себе
  /// долга не означает.
  bool get isDebt => paymentMethod == PaymentMethod.debt;

  /// Сколько капсул ещё ждут с точки: задание админа, пока точка открыта.
  /// У закрытой точки задание сменил факт — см. [deliveredCapsules].
  int get expectedCapsules => status.isOpen ? (bottleSellCount ?? 0) : 0;

  /// Сколько денег ждут с точки, пока она открыта, — «сколько должен
  /// привезти маршрут», а не одни договорные суммы.
  ///
  /// Договорная сумма — как есть: сервер закроет заказ ровно ею. Доставка
  /// по прайсу — задание × цена заказчика (`effective_water_price`, сервер
  /// отдаёт её у открытых заказов; на стенде без неё — [fallbackPrice],
  /// ноль означает «не считать»). Вывоз без договорной суммы бесплатный,
  /// у опта цена появляется только при закрытии — обе дают ноль.
  int expectedAmount({int fallbackPrice = 0}) {
    if (!status.isOpen) return 0;
    if (customPrice case final int price) return price;
    return switch (purpose) {
      OrderPurpose.delivery19l =>
        (bottleSellCount ?? 0) * (effectiveWaterPrice ?? fallbackPrice),
      OrderPurpose.pickup || OrderPurpose.bulkWater => 0,
    };
  }

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
    int? returnedCapsules,
    int? returnedFullCapsules,
    int? damagedCapsules,
    String? cancelReason,
    DateTime? cancelledAt,
    int? pickedCoolers,
    int? pickedBottles,
    int? bulk5lCount,
    int? bulk10lCount,
    int? capsuleBalanceAfter,
    int? paymentAmount,
    PaymentMethod? paymentMethod,
    String? paymentPhoto,
    DateTime? completedAt,
    int? customPrice,
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
      returnedCapsules: returnedCapsules ?? this.returnedCapsules,
      returnedFullCapsules: returnedFullCapsules ?? this.returnedFullCapsules,
      damagedCapsules: damagedCapsules ?? this.damagedCapsules,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      // Меняться ему нечем — но и потеряться при копии он не должен.
      comment: comment,
      pickedCoolers: pickedCoolers ?? this.pickedCoolers,
      pickedBottles: pickedBottles ?? this.pickedBottles,
      bulk5lCount: bulk5lCount ?? this.bulk5lCount,
      bulk10lCount: bulk10lCount ?? this.bulk10lCount,
      bulk5lPrice: bulk5lPrice,
      bulk10lPrice: bulk10lPrice,
      capsuleBalanceAfter: capsuleBalanceAfter ?? this.capsuleBalanceAfter,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentPhoto: paymentPhoto ?? this.paymentPhoto,
      completedAt: completedAt ?? this.completedAt,
      customerCoolerCount: customerCoolerCount,
      customerBottleBalance: customerBottleBalance,
      sequence: sequence,
      purpose: purpose,
      effectiveWaterPrice: effectiveWaterPrice,
      damagedBottleFine: damagedBottleFine,
      bottleSellCount: bottleSellCount,
      customPrice: customPrice ?? this.customPrice,
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
    final completedAt = optionalDate(json['completed_at']);
    final status = DeliveryStatus.fromJson(stringOr(json['status']));

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
        status: status,
        // `num?`, а не `double?`: целое значение приходит из JSON как int.
        customerLatitude: optionalDouble(json['customer_latitude']),
        customerLongitude: optionalDouble(json['customer_longitude']),
        deliveredCapsules: optionalInt(json['delivered_bottles']),
        // `payment_amount` сервер переименовал в `order_amount`; на новой
        // форме старый ключ отсутствует, и сумма показывалась пустой.
        //
        // Только у закрытой точки: до закрытия сервер держит в `order_amount`
        // ноль, а не отсутствие суммы. Экран завершения принимает такой ноль
        // за уже введённую оплату, перестаёт считать по прайсу и показывает
        // водителю «0 сум».
        //
        // У закрытых заказов, заведённых до релиза, стоимость осталась нулём,
        // хотя деньги по ним приняты, — тогда показываем принятое.
        paymentAmount: _closedAmount(json, completedAt, status),
        paymentMethod: PaymentMethod.tryFromJson(json['payment_method']),
        paymentPhoto: optionalString(json['payment_photo']),
        completedAt: completedAt,
        // `customer_has_cooler` сервер отдавал до переименования точек в
        // заказы; сборка с этим кодом может смотреть и на такой стенд.
        customerCoolerCount: optionalInt(firstNonNull([
              customer['customer_cooler_count'],
              customer['cooler_count'],
              json['customer_cooler_count'],
            ])) ??
            (boolOr(json['customer_has_cooler']) ? 1 : 0),
        customerBottleBalance: optionalInt(firstNonNull([
          customer['customer_bottle_balance'],
          customer['bottle_balance'],
          json['customer_bottle_balance'],
        ])),
        // `order` — прежнее имя поля. Сервер переименовал его в `sequence`,
        // и оба имени встречаются в зависимости от версии стенда.
        sequence: optionalInt(json['sequence']) ?? optionalInt(json['order']),
        purpose: OrderPurpose.fromJson(stringOr(json['purpose'])),
        returnedCapsules: optionalInt(json['returned_bottles']),
        returnedFullCapsules: optionalInt(json['returned_full_bottles']),
        damagedCapsules: optionalInt(json['damaged_bottles']),
        cancelReason: optionalString(json['cancel_reason'])?.trim(),
        cancelledAt: optionalDate(json['cancelled_at']),
        comment: _comment(json['comment']),
        pickedCoolers: optionalInt(json['picked_coolers']),
        pickedBottles: optionalInt(json['picked_bottles']),
        bulk5lCount: optionalInt(json['bulk_5l_count']),
        bulk10lCount: optionalInt(json['bulk_10l_count']),
        bulk5lPrice: _money(json['bulk_5l_price']),
        bulk10lPrice: _money(json['bulk_10l_price']),
        capsuleBalanceAfter: optionalInt(json['bottle_balance_after']),
        effectiveWaterPrice: _money(json['effective_water_price']),
        damagedBottleFine: _money(json['damaged_bottle_fine']),
        bottleSellCount: optionalInt(json['bottle_sell_count']),
        customPrice: _money(json['custom_price']),
      );
  }

  /// Комментарий: пробелы по краям срезаем, пустую строку считаем за `null`.
  static String? _comment(Object? value) {
    final text = optionalString(value)?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// Деньги: `null` отличается от нуля — у незакрытой точки суммы нет вовсе.
  static int? _money(Object? value) =>
      value == null ? null : MoneyParser.toSum(value);

  /// Сумма точки, если её вообще уместно показывать.
  ///
  /// До закрытия сервер держит в `order_amount` ноль, а не отсутствие суммы.
  /// Принять этот ноль за введённую оплату нельзя: экран завершения решит,
  /// что доставку уже проводили, перестанет считать по прайсу и покажет
  /// водителю «0 сум» вместо стоимости капсул.
  ///
  /// У закрытых заказов, заведённых до релиза, стоимость осталась нулём,
  /// хотя деньги приняты, — тогда берём принятое.
  static int? _closedAmount(
    Map<String, dynamic> json,
    DateTime? completedAt,
    DeliveryStatus status,
  ) {
    final closed = completedAt != null || !status.isOpen;
    if (!closed) return null;

    final ordered = _money(firstNonNull([
      json['order_amount'],
      json['payment_amount'],
    ]));
    if (ordered != null && ordered != 0) return ordered;
    return _money(json['paid_amount']) ?? ordered;
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
        customerBottleBalance,
        sequence,
        purpose,
        returnedCapsules,
        returnedFullCapsules,
        damagedCapsules,
        cancelReason,
        cancelledAt,
        comment,
        pickedCoolers,
        pickedBottles,
        bulk5lCount,
        bulk10lCount,
        bulk5lPrice,
        bulk10lPrice,
        capsuleBalanceAfter,
        effectiveWaterPrice,
        damagedBottleFine,
        bottleSellCount,
        customPrice,
      ];
}

/// Что ещё ожидается от открытых точек: капсулы к доставке и деньги.
///
/// Считается только по открытым точкам — у закрытых план сменился фактом,
/// и по мере объезда ожидание убывает, а «собрано» растёт. Складывается
/// по точкам маршрута и по маршрутам дня одинаково — см. [ofStops] и [+].
class RouteExpectations extends Equatable {
  const RouteExpectations({this.capsules = 0, this.amount = 0});

  static const none = RouteExpectations();

  /// Сумма заданий по капсулам (`bottle_sell_count`).
  final int capsules;

  /// Сумма денег по правилу [RouteStop.expectedAmount].
  final int amount;

  bool get isEmpty => capsules == 0 && amount == 0;

  RouteExpectations operator +(RouteExpectations other) => RouteExpectations(
        capsules: capsules + other.capsules,
        amount: amount + other.amount,
      );

  /// [fallbackPrice] — цена капсулы для точек без `effective_water_price`;
  /// ноль — такие точки в деньгах не считать.
  static RouteExpectations ofStops(
    Iterable<RouteStop> stops, {
    int fallbackPrice = 0,
  }) {
    var result = none;
    for (final stop in stops) {
      result += RouteExpectations(
        capsules: stop.expectedCapsules,
        amount: stop.expectedAmount(fallbackPrice: fallbackPrice),
      );
    }
    return result;
  }

  @override
  List<Object?> get props => [capsules, amount];
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
    this.cashCollected,
    this.cashlessCollected,
    this.debtAmount,
    this.expensesTotal,
    this.cashBalance,  });

  final String id;
  final DateTime date;
  final RouteStatus status;
  final int completedCount;
  final int totalCustomers;

  /// См. [RouteListItem.driverId] — у водительских ответов полей нет.
  final String? driverId;
  final String? driverFullName;
  final List<RouteStop> stops;

  /// Касса маршрута, как её посчитал сервер.
  ///
  /// `null` — стенд ещё не отдаёт этих полей; тогда наличные считаются
  /// локально по точкам (см. [collected]). Держать локальный подсчёт
  /// запасным вариантом обязательно: сборка живёт в сторах месяцами.
  final int? cashCollected;
  final int? cashlessCollected;
  final int? debtAmount;
  final int? expensesTotal;

  /// Сколько наличных должно остаться у водителя: собранное минус расходы.
  final int? cashBalance;

  /// Точки кончились, а маршрут ещё в работе: сервер сам его не закрывает
  /// (с 2026-09-19 — только по явной команде), и без подсказки день висел
  /// бы «В пути» до следующего утра. Пустой маршрут сюда не попадает —
  /// в нём закрывать нечего.
  bool get awaitsCompletion =>
      status.canComplete &&
      stops.isNotEmpty &&
      stops.every((s) => !s.status.isOpen);

  /// Наличные, собранные за маршрут, — то, что водитель везёт в руках.
  ///
  /// Серверный подсчёт точнее — он видит все платежи, включая правки админа,
  /// — поэтому берём его, когда он есть, и складываем точки, когда нет.
  int get collected =>
      cashCollected ??
      stops.fold<int>(0, (sum, s) => sum + (s.paymentAmount ?? 0));

  /// Вся выручка маршрута: наличные плюс безнал.
  ///
  /// Отдельно от [collected], потому что это разные вопросы. «Сколько
  /// маршрут принёс» — это выручка; «сколько водитель должен сдать» — только
  /// наличные, карта и перевод ушли на счёт компании. Показывать выручку
  /// одними наличными значит занижать день на весь безнал.
  ///
  /// На стенде без блока кассы сумма по точкам и есть вся выручка: способа
  /// оплаты там не разобрать, а деньги приняты все.
  int get revenue {
    if (cashCollected == null && cashlessCollected == null) {
      return stops.fold<int>(0, (sum, s) => sum + (s.paymentAmount ?? 0));
    }
    return (cashCollected ?? 0) + (cashlessCollected ?? 0);
  }

  /// Что ещё ожидается от маршрута — по открытым точкам, см.
  /// [RouteExpectations.ofStops].
  RouteExpectations expected({int fallbackPrice = 0}) =>
      RouteExpectations.ofStops(stops, fallbackPrice: fallbackPrice);

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
        //
        // Точки ставятся в порядок объезда здесь, на разборе: сервер отдаёт их
        // в порядке создания, а `sequence` не сортирует вовсе (см.
        // [inVisitOrder]). Раньше каждый экран видел порядок ответа, то есть
        // заданный админом объезд до водителя не доходил.
        stops: inVisitOrder(
          parseList(
            json['orders'] ?? json['route_customers'],
            RouteStop.fromJson,
          ),
          (stop) => stop.sequence,
        ),
        cashCollected: _money(json['cash_collected']),
        cashlessCollected: _money(json['cashless_collected']),
        debtAmount: _money(json['debt_amount']),
        expensesTotal: _money(json['expenses_total']),
        cashBalance: _money(json['cash_balance']),
      );

  /// Деньги: `null` отличается от нуля — у стенда без кассы полей нет вовсе.
  static int? _money(Object? value) =>
      value == null ? null : MoneyParser.toSum(value);

  @override
  List<Object?> get props => [
        id,
        date,
        status,
        completedCount,
        totalCustomers,
        driverId,
        stops,
        cashCollected,
        cashlessCollected,
        debtAmount,
        expensesTotal,
        cashBalance,
      ];
}

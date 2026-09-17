import 'package:equatable/equatable.dart';

import '../../core/utils/day.dart';
import '../../core/utils/money_parser.dart';
import 'json.dart';
import 'order.dart' show formatApiDate;

/// Давность последнего заказа — по ней список подсвечивает заказчика,
/// которого пора обзванивать.
enum CustomerActivity {
  /// Заказывал в последний месяц.
  recent,

  /// Не заказывал больше месяца.
  stale,

  /// Не заказывал больше двух месяцев.
  dormant,
}

/// Заказчик. Соответствует CustomerResponse из Water CRM API.
///
/// Серверное `bottle_balance` в интерфейсе показывается как «капсулы».
class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.phoneSecondary,
    required this.address,
    this.comment,
    this.capsuleBalance = 0,
    this.prepayment = 0,
    this.debt = 0,
    this.lastOrderDate,
    this.isActive = true,
    this.coolerCount = 0,
    this.customWaterPrice,
    required this.createdAt,
  });

  final String id;

  /// Серверное поле `full_name` (название организации или ФИО).
  final String name;
  final String phone;

  /// Дополнительный телефон (`phone_secondary`) — второй контакт, по
  /// которому дозваниваются, когда основной молчит: бухгалтер офиса, муж
  /// заказчицы. `null` — нет; пустой строкой сервер не отдаёт и не примет
  /// (минимум 5 символов), на провод уходит либо E.164, либо `null`.
  final String? phoneSecondary;
  final String address;
  final String? comment;

  /// Остаток капсул у заказчика (`bottle_balance`).
  final int capsuleBalance;
  final int prepayment;
  final int debt;
  final DateTime? lastOrderDate;
  final bool isActive;

  /// Сколько кулеров стоит у заказчика (`cooler_count`).
  ///
  /// Пришло на смену булеву `has_cooler`: у офисов кулеров бывает несколько,
  /// и водителю на вывозе надо знать, сколько их забирать.
  final int coolerCount;

  /// Индивидуальная цена капсулы (`custom_water_price`), сум.
  ///
  /// `null` — считать по общему прайсу. Ноль осмысленным входом не бывает:
  /// сервер требует цену больше нуля, а «бесплатно» — это не цена, а скидка,
  /// которой в контракте нет.
  final int? customWaterPrice;

  final DateTime createdAt;

  /// У заказчика стоит кулер.
  ///
  /// Производное от [coolerCount], как и на сервере. Влияет на выезд: к
  /// кулеру капсулу ставят, без него воду переливают, — и водителю это надо
  /// знать заранее.
  bool get hasCooler => coolerCount > 0;

  /// У заказчика своя цена, отличная от общего прайса.
  bool get hasIndividualPrice => customWaterPrice != null;

  /// Через сколько дней без заказа заказчик считается «остывшим».
  static const staleAfterDays = 30;

  /// Через сколько дней без заказа — «ушедшим».
  static const dormantAfterDays = 60;

  /// Давность последнего заказа на день [today].
  ///
  /// Точка отсчёта — последняя завершённая доставка (сервер пишет
  /// `last_order_date` при закрытии заказа). У того, кто ещё ни разу не
  /// заказывал, — день, когда его завели: заведён три месяца назад без
  /// единого заказа — та же потеря, что и замолчавший постоянный, а вчерашний
  /// новичок подсветки не заслужил.
  ///
  /// Считаются календарные дни, без часов: доставка в 23:50 и проверка на
  /// следующее утро — это один день разницы, и время суток порог не двигает.
  CustomerActivity activityOn(DateTime today) {
    final since = dayOnly(lastOrderDate ?? createdAt);
    final days = dayOnly(today).difference(since).inDays;
    if (days > dormantAfterDays) return CustomerActivity.dormant;
    if (days > staleAfterDays) return CustomerActivity.stale;
    return CustomerActivity.recent;
  }

  /// Маркер «значение не передавали».
  ///
  /// У [comment] `null` — осмысленный вход: «стереть комментарий». Обычный
  /// `??` их не различает, и форма молча теряла очистку поля: пользователь
  /// стирал текст, видел «Изменения сохранены», а на сервер уходил прежний.
  /// У [customWaterPrice] ровно та же история: `null` значит «вернуть на
  /// общий прайс», и потерять этот вход нельзя — заказчик остался бы на
  /// старой индивидуальной цене. И у [phoneSecondary]: `null` — «второго
  /// телефона больше нет».
  static const Object _unchanged = Object();

  Customer copyWith({
    String? name,
    String? phone,
    Object? phoneSecondary = _unchanged,
    String? address,
    Object? comment = _unchanged,
    int? capsuleBalance,
    int? prepayment,
    int? debt,
    DateTime? lastOrderDate,
    bool? isActive,
    int? coolerCount,
    Object? customWaterPrice = _unchanged,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      phoneSecondary: identical(phoneSecondary, _unchanged)
          ? this.phoneSecondary
          : phoneSecondary as String?,
      address: address ?? this.address,
      comment:
          identical(comment, _unchanged) ? this.comment : comment as String?,
      capsuleBalance: capsuleBalance ?? this.capsuleBalance,
      prepayment: prepayment ?? this.prepayment,
      debt: debt ?? this.debt,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
      isActive: isActive ?? this.isActive,
      coolerCount: coolerCount ?? this.coolerCount,
      customWaterPrice: identical(customWaterPrice, _unchanged)
          ? this.customWaterPrice
          : customWaterPrice as int?,
      createdAt: createdAt,
    );
  }

  /// Разбор терпим к неожиданным типам — см. `json.dart`. Обязателен только
  /// `id`: без него запись не открыть, не изменить и не удалить, и `parseList`
  /// пропустит её, не роняя остальную страницу.
  ///
  /// Кулеры читаются из обоих полей: сервер отдаёт `cooler_count`, но сборка
  /// с этим кодом может смотреть и на стенд, где ещё живёт булев `has_cooler`.
  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: requireString(json['id'], 'id'),
        name: stringOr(json['full_name']),
        phone: stringOr(json['phone']),
        phoneSecondary: optionalString(json['phone_secondary']),
        address: stringOr(json['address']),
        comment: optionalString(json['comment']),
        capsuleBalance: intOr(json['bottle_balance']),
        prepayment: MoneyParser.toSum(json['prepayment']),
        debt: MoneyParser.toSum(json['debt']),
        lastOrderDate: optionalDate(json['last_order_date']),
        isActive: boolOr(json['is_active'], true),
        coolerCount: optionalInt(json['cooler_count']) ??
            (boolOr(json['has_cooler']) ? 1 : 0),
        // Ноль и мусор — это «цены нет»: `MoneyParser.toSum` отдаёт ноль на
        // всём, чего не понял, и считать по нему значило бы выставить
        // заказчику ноль сум за капсулу.
        customWaterPrice: _price(json['custom_water_price']),
        createdAt: dateOr(json['created_at'], epoch),
      );

  static int? _price(Object? value) {
    if (value == null) return null;
    final sum = MoneyParser.toSum(value);
    return sum > 0 ? sum : null;
  }

  /// Тело для PATCH /admin/customers/{id} (частичное обновление).
  ///
  /// [includeBalance] — отправить ещё и долг с предоплатой. По умолчанию
  /// выключено: форма открывается с балансом, каким он был при загрузке, и
  /// пока админ правит название, водитель может закрыть доставку. Отправив
  /// «свои» цифры, форма откатила бы уже принятую оплату — а сервер вдобавок
  /// записал бы это в журнал правок как ручное решение админа.
  ///
  /// [includeCapsules] — то же самое про остаток капсул, и по той же причине:
  /// его ведёт водитель, а сервер присланным числом **заменяет** остаток
  /// целиком. Правка комментария не должна откатывать склад заказчика к
  /// значению, каким оно было при открытии формы.
  ///
  /// [includeLastOrderDate] — и дата последнего заказа туда же: её ставит
  /// закрытие доставки, и форма, открытая до него, держит устаревшую.
  /// Уходит как [lastOrderDateWire] — см. там, почему без времени.
  Map<String, dynamic> toUpdateJson({
    bool includeBalance = false,
    bool includeCapsules = false,
    bool includeLastOrderDate = false,
  }) => {
        'full_name': name,
        'phone': phone,
        // Ключ уходит всегда: `null` — «стереть второй телефон», а сервер
        // непереданное поле оставляет как было.
        'phone_secondary': phoneSecondary,
        'address': address,
        'comment': comment,
        'is_active': isActive,
        'cooler_count': coolerCount,
        'custom_water_price':
            customWaterPrice == null ? null : MoneyParser.toApi(customWaterPrice!),
        if (includeBalance) ...{
          'debt': MoneyParser.toApi(debt),
          'prepayment': MoneyParser.toApi(prepayment),
        },
        if (includeCapsules) 'bottle_balance': capsuleBalance,
        if (includeLastOrderDate && lastOrderDate != null)
          'last_order_date': lastOrderDateWire(lastOrderDate!),
      };

  /// Дата последнего заказа для `CreateCustomer`/`UpdateCustomer`.
  ///
  /// Только день, без времени и зоны. Сервер проверяет «не в будущем»,
  /// сравнивая с наивным `datetime.now()`: метка с зоной (`…Z`) роняет это
  /// сравнение в `TypeError`, то есть в 500 вместо 422. А само время суток
  /// здесь ничего не значит — админ вводит день, когда заказчик брал воду.
  static String lastOrderDateWire(DateTime date) => formatApiDate(date);

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        phoneSecondary,
        address,
        comment,
        capsuleBalance,
        prepayment,
        debt,
        lastOrderDate,
        isActive,
        coolerCount,
        customWaterPrice,
      ];
}

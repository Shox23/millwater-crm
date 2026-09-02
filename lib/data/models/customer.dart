import 'package:equatable/equatable.dart';

import '../../core/utils/money_parser.dart';
import 'json.dart';

/// Заказчик. Соответствует CustomerResponse из Water CRM API.
///
/// Серверное `bottle_balance` в интерфейсе показывается как «капсулы».
class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
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

  /// Маркер «значение не передавали».
  ///
  /// У [comment] `null` — осмысленный вход: «стереть комментарий». Обычный
  /// `??` их не различает, и форма молча теряла очистку поля: пользователь
  /// стирал текст, видел «Изменения сохранены», а на сервер уходил прежний.
  /// У [customWaterPrice] ровно та же история: `null` значит «вернуть на
  /// общий прайс», и потерять этот вход нельзя — заказчик остался бы на
  /// старой индивидуальной цене.
  static const Object _unchanged = Object();

  Customer copyWith({
    String? name,
    String? phone,
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
  Map<String, dynamic> toUpdateJson({bool includeBalance = false}) => {
        'full_name': name,
        'phone': phone,
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
      };

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
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

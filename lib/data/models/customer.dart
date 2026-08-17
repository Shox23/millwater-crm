import 'package:equatable/equatable.dart';

import '../../core/utils/money_parser.dart';

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
    this.hasCooler = false,
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

  /// У заказчика стоит кулер (`has_cooler`).
  ///
  /// Влияет на выезд: к кулеру капсулу ставят, без него воду переливают, — и
  /// водителю это надо знать заранее.
  final bool hasCooler;

  final DateTime createdAt;

  /// Маркер «значение не передавали».
  ///
  /// У [comment] `null` — осмысленный вход: «стереть комментарий». Обычный
  /// `??` их не различает, и форма молча теряла очистку поля: пользователь
  /// стирал текст, видел «Изменения сохранены», а на сервер уходил прежний.
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
    bool? hasCooler,
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
      hasCooler: hasCooler ?? this.hasCooler,
      createdAt: createdAt,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['full_name'] as String,
        phone: json['phone'] as String,
        address: json['address'] as String,
        comment: json['comment'] as String?,
        capsuleBalance: json['bottle_balance'] as int? ?? 0,
        prepayment: MoneyParser.toSum(json['prepayment']),
        debt: MoneyParser.toSum(json['debt']),
        lastOrderDate: json['last_order_date'] == null
            ? null
            : DateTime.parse(json['last_order_date'] as String),
        isActive: json['is_active'] as bool? ?? true,
        hasCooler: json['has_cooler'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// Тело для PATCH /admin/customers/{id} (частичное обновление).
  Map<String, dynamic> toUpdateJson() => {
        'full_name': name,
        'phone': phone,
        'address': address,
        'comment': comment,
        'is_active': isActive,
        'has_cooler': hasCooler,
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
        hasCooler,
      ];
}

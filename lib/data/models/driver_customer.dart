import 'package:equatable/equatable.dart';

import 'json.dart';

/// Заказчик глазами водителя (`CustomerResponseForDriver`).
///
/// Отдельно от `Customer` намеренно: `GET /driver/customers` отдаёт только
/// контакты — ни долга, ни остатка капсул, ни цены. Разобранный в `Customer`
/// ответ показывал бы на их месте нули, и «долга нет» читалось бы как факт.
class DriverCustomer extends Equatable {
  const DriverCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.phoneSecondary,
    this.comment,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final String? phoneSecondary;

  /// Заметка админа о заказчике («Мирабад», «звонить бухгалтеру»).
  final String? comment;

  /// Обязателен только `id` — см. `parseList`: запись без него пропускается,
  /// не роняя остальную страницу.
  factory DriverCustomer.fromJson(Map<String, dynamic> json) => DriverCustomer(
        id: requireString(json['id'], 'id'),
        name: stringOr(json['full_name']),
        phone: stringOr(json['phone']),
        address: stringOr(json['address']),
        phoneSecondary: optionalString(json['phone_secondary']),
        comment: optionalString(json['comment']),
      );

  @override
  List<Object?> get props =>
      [id, name, phone, address, phoneSecondary, comment];
}

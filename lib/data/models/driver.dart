import 'package:equatable/equatable.dart';
import 'json.dart';

/// Водитель. Соответствует DriverResponse из Water CRM API.
///
/// Почты у водителя нет: сервер её не хранит и не принимает — ни в
/// `CreateDriver`, ни в `UpdateDriver`, ни в ответе. Учётка заводится по
/// телефону и паролю.
class Driver extends Equatable {
  const Driver({
    required this.id,
    required this.fullName,
    required this.phone,
    this.userId,
    this.tripCount = 0,
    this.todayTripCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// Связанный пользователь (учётная запись водителя).
  final String? userId;
  final String fullName;
  final String phone;
  final int tripCount;
  final int todayTripCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Driver copyWith({
    String? fullName,
    String? phone,
    int? tripCount,
    int? todayTripCount,
  }) {
    return Driver(
      id: id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      tripCount: tripCount ?? this.tripCount,
      todayTripCount: todayTripCount ?? this.todayTripCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Разбор терпим к неожиданным типам — см. `json.dart`.
  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        id: requireString(json['id'], 'id'),
        userId: optionalString(json['user_id']),
        fullName: stringOr(json['full_name']),
        phone: stringOr(json['phone']),
        tripCount: intOr(json['trip_count']),
        todayTripCount: intOr(json['today_trip_count']),
        createdAt: dateOr(json['created_at'], epoch),
        updatedAt: optionalDate(json['updated_at']),
      );

  /// Тело для PATCH /admin/drivers/{id} (частичное обновление).
  Map<String, dynamic> toUpdateJson() => {
        'full_name': fullName,
        'phone': phone,
      };

  @override
  List<Object?> get props =>
      [id, userId, fullName, phone, tripCount, todayTripCount];
}

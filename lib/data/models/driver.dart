import 'package:equatable/equatable.dart';

/// Водитель. Соответствует DriverResponse из Water CRM API.
class Driver extends Equatable {
  const Driver({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
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
  final String email;
  final int tripCount;
  final int todayTripCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Driver copyWith({
    String? fullName,
    String? phone,
    String? email,
    int? tripCount,
    int? todayTripCount,
  }) {
    return Driver(
      id: id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      tripCount: tripCount ?? this.tripCount,
      todayTripCount: todayTripCount ?? this.todayTripCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        fullName: json['full_name'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String? ?? '',
        tripCount: json['trip_count'] as int? ?? 0,
        todayTripCount: json['today_trip_count'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.parse(json['updated_at'] as String),
      );

  /// Тело для PATCH /admin/drivers/{id} (частичное обновление).
  ///
  /// Почта необязательна: пустую строку сервер не принимает — не шлём ключ.
  Map<String, dynamic> toUpdateJson() => {
        'full_name': fullName,
        'phone': phone,
        if (email.trim().isNotEmpty) 'email': email.trim(),
      };

  @override
  List<Object?> get props =>
      [id, userId, fullName, phone, email, tripCount, todayTripCount];
}

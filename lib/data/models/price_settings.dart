import 'package:equatable/equatable.dart';

import '../../core/utils/money_parser.dart';

/// Прайс компании. Соответствует PriceSettingsResponse из Water CRM API.
///
/// Цены на сервере не редактируются, а добавляются: `POST /admin/prices`
/// создаёт новую запись, текущей считается последняя. Поэтому у записи есть
/// [createdAt] и нет `updatedAt`.
class PriceSettings extends Equatable {
  const PriceSettings({
    required this.id,
    required this.capsulePrice,
    required this.depositPrice,
    required this.createdAt,
  });

  final String id;

  /// Серверное `water_price` — цена одной капсулы, сум.
  final int capsulePrice;

  /// Серверное `deposit_price` — залог за тару, сум.
  final int depositPrice;

  final DateTime createdAt;

  factory PriceSettings.fromJson(Map<String, dynamic> json) => PriceSettings(
        id: json['id'] as String,
        capsulePrice: MoneyParser.toSum(json['water_price']),
        depositPrice: MoneyParser.toSum(json['deposit_price']),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, capsulePrice, depositPrice, createdAt];
}

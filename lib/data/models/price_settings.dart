import 'package:equatable/equatable.dart';

import '../../core/utils/money_parser.dart';
import 'json.dart';

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
    this.damagedBottleFine = 0,
    required this.createdAt,
  });

  final String id;

  /// Серверное `water_price` — цена одной капсулы, сум.
  final int capsulePrice;

  /// Серверное `deposit_price` — залог за тару, сум.
  final int depositPrice;

  /// Серверное `damaged_bottle_fine` — штраф за повреждённую капсулу, сум.
  ///
  /// Ноль по умолчанию честен дважды: у прайсов, заведённых до релиза, штрафа
  /// не было, и старый стенд поля не отдаёт вовсе.
  final int damagedBottleFine;

  final DateTime createdAt;

  factory PriceSettings.fromJson(Map<String, dynamic> json) => PriceSettings(
        id: requireString(json['id'], 'id'),
        capsulePrice: MoneyParser.toSum(json['water_price']),
        depositPrice: MoneyParser.toSum(json['deposit_price']),
        damagedBottleFine: MoneyParser.toSum(json['damaged_bottle_fine']),
        createdAt: dateOr(json['created_at'], epoch),
      );

  @override
  List<Object?> get props =>
      [id, capsulePrice, depositPrice, damagedBottleFine, createdAt];
}

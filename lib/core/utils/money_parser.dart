/// Разбор денежных значений из API.
///
/// Сервер отдаёт суммы строками, иногда с копейками: "20000.00", "0", "1500.5".
abstract class MoneyParser {
  /// Строка/число → целые сумы (копейки отбрасываются округлением).
  static int toSum(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    final parsed = num.tryParse(value.toString().trim());
    return parsed?.round() ?? 0;
  }

  /// Сумма → строка для отправки на сервер.
  static String toApi(int value) => value.toString();
}

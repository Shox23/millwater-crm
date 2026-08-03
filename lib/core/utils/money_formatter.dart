/// Форматирование денежных сумм в стиле макета: `280 000 сум`.
abstract class MoneyFormatter {
  /// Группировка разрядов пробелом: 280000 -> "280 000".
  static String amount(num value) {
    final rounded = value.round();
    final digits = rounded.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return '${rounded < 0 ? '-' : ''}$buf';
  }

  /// С валютой: 280000 -> "280 000 сум".
  static String sum(num value) => '${amount(value)} сум';

  /// Компактная запись больших сумм: 1520000 -> "1,52 млн сум".
  static String compactSum(num value) {
    if (value >= 1000000) {
      final mln = value / 1000000;
      final text = mln.toStringAsFixed(2).replaceAll('.', ',');
      return '$text млн сум';
    }
    return sum(value);
  }
}

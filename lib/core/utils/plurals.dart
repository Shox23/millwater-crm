/// Русские склонения по числу.
abstract class Plurals {
  static String _pick(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }

  /// 1 капсула · 2 капсулы · 5 капсул.
  static String capsules(int n) => '$n ${_pick(n, 'капсула', 'капсулы', 'капсул')}';

  /// 1 поездка · 2 поездки · 5 поездок.
  static String trips(int n) => '$n ${_pick(n, 'поездка', 'поездки', 'поездок')}';

  /// 1 клиент · 2 клиента · 5 клиентов.
  static String clients(int n) => '$n ${_pick(n, 'клиент', 'клиента', 'клиентов')}';
}

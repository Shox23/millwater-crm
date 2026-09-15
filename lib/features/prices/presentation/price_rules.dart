import 'package:flutter/widgets.dart';

import '../../../core/validation/validators.dart';
import '../../../l10n/l10n.dart';

/// Правила проверки полей прайса — общие для телефона и десктопа.
///
/// Пересобираются при смене локали вместе с [Validators]: тексты ошибок
/// на языке интерфейса.
class PriceRules {
  PriceRules(AppLocalizations l10n)
      : _l10n = l10n,
        _v = Validators(l10n);

  final AppLocalizations _l10n;
  final Validators _v;

  /// Залог и штраф: заполнено и не длиннее десяти знаков. Ноль допустим —
  /// залога может не быть.
  FormFieldValidator<String> get price => Validators.all([
        _v.notEmpty(_l10n.pricesEmpty),
        _v.maxLen(10),
      ]);

  /// Цена капсулы строже: ноль — почти наверняка опечатка, воду раздают не
  /// бесплатно.
  String? capsule(String? value) {
    final error = price(value);
    if (error != null) return error;
    return (int.tryParse(value!.trim()) ?? 0) > 0 ? null : _l10n.pricesZero;
  }

  /// Число из поля; пустое и мусор — ноль, как и раньше на экране.
  static int parse(String text) => int.tryParse(text.trim()) ?? 0;
}

import 'package:flutter/services.dart';

/// Телефон Узбекистана: маска ввода `+998 90 123 45 67` и формат API
/// E.164 `+998901234567`.
abstract class UzPhone {
  /// Код страны без «+».
  static const String _code = '998';

  /// Длина абонентской части: код оператора (2) + номер (7).
  static const int subscriberLength = 9;

  /// Видимый префикс маски.
  static const String prefix = '+$_code ';

  static final RegExp _nonDigit = RegExp(r'\D');

  /// Абонентские цифры из произвольного ввода: без кода страны, максимум 9.
  ///
  /// «998» в начале считается кодом страны, только если строка начинается с
  /// «+» либо цифр больше девяти. Иначе это код оператора 99 — например
  /// «998123456» это номер 99 812 34 56, и обрезать начало нельзя.
  static String subscriberDigits(String input) {
    final digits = input.replaceAll(_nonDigit, '');
    final hasPlus = input.trimLeft().startsWith('+');
    final isCountryCode = digits.startsWith(_code) &&
        (hasPlus || digits.length > subscriberLength);
    final rest = isCountryCode ? digits.substring(_code.length) : digits;
    return rest.length > subscriberLength
        ? rest.substring(0, subscriberLength)
        : rest;
  }

  /// Ввод → маска `+998 90 123 45 67`.
  ///
  /// Пустой ввод остаётся пустым, чтобы в поле был виден хинт.
  static String format(String input) {
    final digits = subscriberDigits(input);
    if (digits.isEmpty) return '';
    final buf = StringBuffer(prefix);
    for (var i = 0; i < digits.length; i++) {
      // Группировка 90 · 123 · 45 · 67.
      if (i == 2 || i == 5 || i == 7) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  /// Ввод → формат API `+998901234567`. Пустой ввод → пустая строка.
  static String normalize(String input) {
    final digits = subscriberDigits(input);
    return digits.isEmpty ? '' : '+$_code$digits';
  }

  /// Номер введён полностью.
  static bool isValid(String input) =>
      subscriberDigits(input).length == subscriberLength;
}

/// Маска ввода: приводит текст поля к виду `+998 90 123 45 67`.
///
/// Лишние символы отбрасываются, вставка полного номера (с «+998», с «998»
/// или без кода) распознаётся, курсор остаётся у той же введённой цифры.
class UzPhoneInputFormatter extends TextInputFormatter {
  const UzPhoneInputFormatter();

  static final RegExp _digit = RegExp(r'\d');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = UzPhone.format(newValue.text);
    if (text == newValue.text) return newValue;

    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    final typedBefore =
        UzPhone.subscriberDigits(newValue.text.substring(0, cursor)).length;

    return TextEditingValue(
      text: text,
      selection:
          TextSelection.collapsed(offset: _offsetAfter(text, typedBefore)),
    );
  }

  /// Позиция сразу после [count]-й абонентской цифры в маскированном тексте.
  static int _offsetAfter(String text, int count) {
    if (text.isEmpty) return 0;
    if (count <= 0) return UzPhone.prefix.length;
    var seen = 0;
    for (var i = UzPhone.prefix.length; i < text.length; i++) {
      if (_digit.hasMatch(text[i]) && ++seen == count) return i + 1;
    }
    return text.length;
  }
}

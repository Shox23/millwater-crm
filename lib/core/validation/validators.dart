import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';
import '../utils/uz_phone.dart';

/// Правила проверки полей форм.
///
/// Класс, а не набор статических функций: тексты ошибок зависят от языка,
/// поэтому правило создаётся под текущую локаль —
/// `final v = Validators(context.l10n); ... validator: v.phone`.
class Validators {
  const Validators(this.l10n);

  final AppLocalizations l10n;

  /// Учитывает и «+», и разделители: `user.name+tag@mail.example.uz`.
  static final RegExp _email = RegExp(
    r"^[\w.!#$%&'*+/=?^`{|}~-]+"
    r'@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  /// Обязательное поле. [message] — своя формулировка вместо общей.
  FormFieldValidator<String> notEmpty([String? message]) {
    return (value) => (value == null || value.trim().isEmpty)
        ? (message ?? l10n.fieldRequired)
        : null;
  }

  /// Телефон Узбекистана: «+998» и девять цифр.
  String? phone(String? value) {
    final digits = UzPhone.subscriberDigits(value ?? '');
    if (digits.isEmpty) return l10n.fieldPhoneEmpty;
    if (digits.length < UzPhone.subscriberLength) {
      return l10n.fieldPhoneIncomplete(UzPhone.subscriberLength);
    }
    return null;
  }

  /// Электронная почта. Пустое значение допустимо — поле необязательное.
  String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return _email.hasMatch(v) ? null : l10n.fieldEmailInvalid;
  }

  /// Электронная почта, обязательная к заполнению.
  String? emailRequired(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return l10n.fieldEmailEmpty;
    return email(value);
  }

  /// Пароль учётной записи.
  FormFieldValidator<String> password({int min = 6}) {
    return (value) {
      final v = value ?? '';
      if (v.isEmpty) return l10n.fieldPasswordEmpty;
      if (v.length < min) return l10n.fieldMinLength(min);
      return null;
    };
  }

  /// Ограничение длины — сервер отвергает слишком длинные значения.
  FormFieldValidator<String> maxLen(int max) {
    return (value) => (value != null && value.trim().length > max)
        ? l10n.fieldMaxLength(max)
        : null;
  }

  /// Несколько правил подряд: возвращается первая сработавшая ошибка.
  static FormFieldValidator<String> all(
    List<FormFieldValidator<String>> rules,
  ) {
    return (value) {
      for (final rule in rules) {
        final error = rule(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}

import 'package:flutter/widgets.dart';

import '../utils/uz_phone.dart';

/// Правила проверки полей форм.
///
/// Функции без параметров передаются в `validator:` напрямую
/// (`validator: Validators.phone`), настраиваемые — вызовом
/// (`validator: Validators.maxLen(120)`).
abstract class Validators {
  /// Учитывает и «+», и разделители: `user.name+tag@mail.example.uz`.
  static final RegExp _email = RegExp(
    r"^[\w.!#$%&'*+/=?^`{|}~-]+"
    r'@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  /// Обязательное поле.
  static FormFieldValidator<String> notEmpty([
    String message = 'Заполните поле',
  ]) {
    return (value) => (value == null || value.trim().isEmpty) ? message : null;
  }

  /// Телефон Узбекистана: «+998» и девять цифр.
  static String? phone(String? value) {
    final digits = UzPhone.subscriberDigits(value ?? '');
    if (digits.isEmpty) return 'Введите номер телефона';
    if (digits.length < UzPhone.subscriberLength) {
      return 'Номер неполный — нужно '
          '${UzPhone.subscriberLength} цифр после +998';
    }
    return null;
  }

  /// Электронная почта. Пустое значение допустимо — поле необязательное.
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return _email.hasMatch(v) ? null : 'Неверный формат почты';
  }

  /// Электронная почта, обязательная к заполнению.
  static String? emailRequired(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Введите электронную почту';
    return email(value);
  }

  /// Пароль учётной записи.
  static FormFieldValidator<String> password({int min = 6}) {
    return (value) {
      final v = value ?? '';
      if (v.isEmpty) return 'Введите пароль';
      if (v.length < min) return 'Минимум $min символов';
      return null;
    };
  }

  /// Ограничение длины — сервер отвергает слишком длинные значения.
  static FormFieldValidator<String> maxLen(int max) {
    return (value) => (value != null && value.trim().length > max)
        ? 'Не более $max символов'
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

import 'package:crm_millwater/core/utils/uz_phone.dart';
import 'package:crm_millwater/core/validation/validators.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Прогоняет ввод через маску так же, как это делает поле.
TextEditingValue _type(String oldText, String newText, {int? cursor}) {
  const formatter = UzPhoneInputFormatter();
  return formatter.formatEditUpdate(
    TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: oldText.length),
    ),
    TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor ?? newText.length),
    ),
  );
}

void main() {
  group('UzPhone.subscriberDigits', () {
    test('код страны отбрасывается', () {
      expect(UzPhone.subscriberDigits('+998901234567'), '901234567');
      expect(UzPhone.subscriberDigits('998901234567'), '901234567');
      expect(UzPhone.subscriberDigits('+998 90 123 45 67'), '901234567');
    });

    test('номер без кода страны остаётся как есть', () {
      expect(UzPhone.subscriberDigits('901234567'), '901234567');
      expect(UzPhone.subscriberDigits('90 123 45 67'), '901234567');
    });

    test('оператор 99 не путается с кодом страны', () {
      // 99 812 34 56 — девять цифр, «998» здесь не код страны.
      expect(UzPhone.subscriberDigits('998123456'), '998123456');
      // А с «+» те же цифры — это код страны и неполный номер.
      expect(UzPhone.subscriberDigits('+998123456'), '123456');
    });

    test('лишние цифры обрезаются, мусор игнорируется', () {
      expect(UzPhone.subscriberDigits('+998 90 123 45 67 89'), '901234567');
      expect(UzPhone.subscriberDigits('тел: 90-123-45-67'), '901234567');
      expect(UzPhone.subscriberDigits(''), '');
      expect(UzPhone.subscriberDigits('+998 '), '');
    });
  });

  group('UzPhone.format / normalize', () {
    test('группировка по макету', () {
      expect(UzPhone.format('901234567'), '+998 90 123 45 67');
      expect(UzPhone.format('9012'), '+998 90 12');
      expect(UzPhone.format('9'), '+998 9');
    });

    test('пустой ввод остаётся пустым — виден хинт', () {
      expect(UzPhone.format(''), '');
      expect(UzPhone.format('+998 '), '');
      expect(UzPhone.normalize('+998 '), '');
    });

    test('формат API — E.164', () {
      expect(UzPhone.normalize('+998 90 123 45 67'), '+998901234567');
      expect(UzPhone.normalize('901234567'), '+998901234567');
      expect(UzPhone.normalize('+998901234567'), '+998901234567');
    });

    test('format и normalize обратимы', () {
      const api = '+998998123456';
      expect(UzPhone.normalize(UzPhone.format(api)), api);
    });

    test('isValid — только полные девять цифр', () {
      expect(UzPhone.isValid('+998 90 123 45 67'), isTrue);
      expect(UzPhone.isValid('+998 90 123 45 6'), isFalse);
      expect(UzPhone.isValid(''), isFalse);
    });
  });

  group('UzPhoneInputFormatter', () {
    test('первая цифра подставляет префикс', () {
      expect(_type('', '9').text, '+998 9');
    });

    test('ввод в конец: курсор остаётся в конце', () {
      final v = _type('+998 90 12', '+998 90 123');
      expect(v.text, '+998 90 123');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('разделитель добавляется вместе с цифрой', () {
      expect(_type('+998 9', '+998 90').text, '+998 90');
      expect(_type('+998 90', '+998 901').text, '+998 90 1');
    });

    test('вставка полного номера', () {
      expect(_type('', '+998901234567').text, '+998 90 123 45 67');
      expect(_type('', '998 90 123 45 67').text, '+998 90 123 45 67');
    });

    test('удаление последней цифры очищает поле до пустого', () {
      expect(_type('+998 9', '+998 ').text, '');
    });

    test('правка в середине: курсор у той же цифры', () {
      // Убрали «1» из «+998 90 123 45 67»: хвост подтягивается,
      // курсор остаётся сразу после второй абонентской цифры.
      final v = _type('+998 90 123 45 67', '+998 90 23 45 67', cursor: 8);
      expect(v.text, '+998 90 234 56 7');
      expect(v.selection.baseOffset, '+998 90'.length);
    });

    test('лишние цифры сверх девяти не принимаются', () {
      expect(_type('+998 90 123 45 67', '+998 90 123 45 678').text,
          '+998 90 123 45 67');
    });
  });

  group('Validators.phone', () {
    test('пустое поле', () {
      expect(Validators.phone(''), 'Введите номер телефона');
      expect(Validators.phone(null), 'Введите номер телефона');
      // Один префикс — тоже «пусто» для пользователя.
      expect(Validators.phone('+998 '), 'Введите номер телефона');
    });

    test('неполный номер', () {
      expect(Validators.phone('+998 90 123'), contains('неполный'));
    });

    test('полный номер проходит', () {
      expect(Validators.phone('+998 90 123 45 67'), isNull);
      expect(Validators.phone('901234567'), isNull);
    });
  });

  group('Validators.email', () {
    test('пустое значение допустимо — поле необязательное', () {
      expect(Validators.email(''), isNull);
      expect(Validators.email(null), isNull);
      expect(Validators.email('   '), isNull);
    });

    test('обязательный вариант требует значение', () {
      expect(Validators.emailRequired(''), 'Введите электронную почту');
      expect(Validators.emailRequired('driver@aqua.uz'), isNull);
    });

    test('валидные адреса', () {
      for (final v in [
        'driver@aqua.uz',
        'a.b+tag@mail.example.co',
        'user_1@sub.domain.uz',
      ]) {
        expect(Validators.email(v), isNull, reason: v);
      }
    });

    test('невалидные адреса', () {
      for (final v in [
        'driver',
        'driver@',
        '@aqua.uz',
        'driver@aqua',
        'driver @aqua.uz',
        'driver@aqua..uz',
      ]) {
        expect(Validators.email(v), isNotNull, reason: v);
      }
    });
  });

  group('Validators прочие', () {
    test('notEmpty', () {
      expect(Validators.notEmpty()(''), 'Заполните поле');
      expect(Validators.notEmpty()('   '), 'Заполните поле');
      expect(Validators.notEmpty('Введите имя')(null), 'Введите имя');
      expect(Validators.notEmpty()('Азиз'), isNull);
    });

    test('password', () {
      expect(Validators.password()(''), 'Введите пароль');
      expect(Validators.password()('12345'), 'Минимум 6 символов');
      expect(Validators.password()('123456'), isNull);
      expect(Validators.password(min: 8)('1234567'), 'Минимум 8 символов');
    });

    test('maxLen', () {
      expect(Validators.maxLen(3)('абвг'), 'Не более 3 символов');
      expect(Validators.maxLen(3)('абв'), isNull);
      expect(Validators.maxLen(3)(null), isNull);
    });

    test('all возвращает первую ошибку', () {
      final rule = Validators.all([
        Validators.notEmpty('Заполните имя'),
        Validators.maxLen(3),
      ]);
      expect(rule(''), 'Заполните имя');
      expect(rule('абвг'), 'Не более 3 символов');
      expect(rule('абв'), isNull);
    });
  });
}

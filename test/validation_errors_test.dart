import 'package:crm_millwater/data/network/api_envelope.dart';
import 'package:crm_millwater/data/network/validation_errors.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations ru;
  late AppLocalizations uz;

  setUp(() async {
    ru = await AppLocalizations.delegate.load(AppLocales.ru);
    uz = await AppLocalizations.delegate.load(AppLocales.uz);
  });

  /// Ошибка валидации в том виде, в каком её отдаёт FastAPI.
  Map<String, Object?> error(String type, List<Object> loc, String msg) =>
      {'loc': loc, 'msg': msg, 'type': type};

  DioException badRequest(int status, Object? body) {
    final request = RequestOptions(path: '/admin/customers');
    return DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: request,
        statusCode: status,
        data: body,
      ),
    );
  }

  group('Отлуп валидации переводится по type и loc', () {
    test('пропущенное поле называется по-русски', () {
      final message = validationErrorMessage(ru, [
        error('missing', ['body', 'phone'], 'Field required'),
      ]);
      expect(message, 'Заполните поле «Телефон»');
    });

    test('нечисловое значение', () {
      final message = validationErrorMessage(ru, [
        error('int_parsing', ['body', 'delivered_bottles'],
            'Input should be a valid integer'),
      ]);
      expect(message, 'В поле «Количество капсул» нужно число');
    });

    test('несколько причин склеиваются, но не больше трёх', () {
      final message = validationErrorMessage(ru, [
        error('missing', ['body', 'full_name'], 'Field required'),
        error('string_too_short', ['body', 'address'], 'String too short'),
        error('int_parsing', ['body', 'payment_amount'], 'Not a number'),
        error('missing', ['body', 'comment'], 'Field required'),
      ]);
      expect(message, contains('Имя или название'));
      expect(message, contains('Адрес'));
      expect(message, contains('Сумма оплаты'));
      expect(message, isNot(contains('Комментарий')));
    });

    test('одинаковая причина в двух полях не повторяется', () {
      final message = validationErrorMessage(ru, [
        error('missing', ['body', 'phone'], 'Field required'),
        error('missing', ['body', 'phone'], 'Field required'),
      ]);
      expect(message, 'Заполните поле «Телефон»');
    });

    test('индекс элемента списка пропускается, берётся имя поля', () {
      // FastAPI кладёт в loc путь целиком: ["body", "customer_ids", 0].
      final message = validationErrorMessage(ru, [
        error('uuid_parsing', ['body', 'customer_ids', 0], 'Invalid UUID'),
      ]);
      expect(message, 'Неверный формат в поле «Заказчики»');
    });

    test('незнакомый код причины — общий текст, а не английский msg', () {
      final message = validationErrorMessage(ru, [
        error('some_future_pydantic_code', ['body', 'phone'],
            'Something went sideways'),
      ]);
      expect(message, 'Проверьте правильность заполнения');
      expect(message, isNot(contains('sideways')));
    });

    test('незнакомое поле — общий текст, а не имя поля из API', () {
      final message = validationErrorMessage(ru, [
        error('missing', ['body', 'internal_tracking_ref'], 'Field required'),
      ]);
      expect(message, 'Проверьте правильность заполнения');
      expect(message, isNot(contains('internal_tracking_ref')));
    });

    test('на узбекском — тот же разбор', () {
      final message = validationErrorMessage(uz, [
        error('missing', ['body', 'phone'], 'Field required'),
      ]);
      expect(message, '«Telefon» maydonini to‘ldiring');
    });

    test('не список — разобрать нечего', () {
      expect(validationErrorMessage(ru, null), isNull);
      expect(validationErrorMessage(ru, 'Phone already taken'), isNull);
    });
  });

  group('Английский текст сервера не доходит до пользователя', () {
    test('строковый detail на латинице заменяется общей фразой', () {
      final message = apiErrorMessage(
        ru,
        badRequest(409, {'detail': 'Customer with this phone already exists'}),
        fallback: 'Не удалось сохранить заказчика.',
      );
      expect(message, 'Не удалось сохранить заказчика.');
      expect(message, isNot(contains('phone already exists')));
    });

    test('а написанный по-русски — доходит', () {
      // Такой текст бэкенд пишет осознанно для пользователя, и заменять его
      // общей фразой значило бы потерять смысл.
      final message = apiErrorMessage(
        ru,
        badRequest(409, {'detail': 'Телефон уже занят'}),
        fallback: 'Не удалось сохранить заказчика.',
      );
      expect(message, 'Телефон уже занят');
    });

    test('английский msg из списка валидации не просачивается', () {
      final message = apiErrorMessage(
        ru,
        badRequest(422, {
          'detail': [
            error('int_parsing', ['body', 'payment_amount'],
                'Input should be a valid integer'),
          ],
        }),
        fallback: 'Не удалось завершить доставку.',
      );
      expect(message, 'В поле «Сумма оплаты» нужно число');
      expect(message, isNot(contains('valid integer')));
    });
  });
}

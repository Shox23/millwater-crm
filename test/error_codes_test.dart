import 'package:crm_millwater/data/network/api_envelope.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Коды ошибок сервера.
///
/// До этого разбора клиент показывал только сообщения с кириллицей, а всё
/// остальное глотал и заменял общим «Не удалось» — из-за чего водитель на
/// отказе «в долг сумма должна быть нулём» не понимал ровно ничего.
///
/// Мест, откуда код достаётся, два, потому что у сервера два пути отказа:
/// бизнес-ошибка приходит конвертом `{error: {code, message}}`, а отказ
/// pydantic-валидатора кладёт тот же код в `detail[].msg` строкой вида
/// «Value error, BOTH_BALANCES_SET».
void main() {
  late AppLocalizations ru;
  late AppLocalizations uz;

  setUp(() async {
    ru = await AppLocalizations.delegate.load(AppLocales.ru);
    uz = await AppLocalizations.delegate.load(AppLocales.uz);
  });

  DioException failure(Object? data, {int status = 422}) => DioException(
        requestOptions: RequestOptions(path: '/admin/customers'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/admin/customers'),
          statusCode: status,
          data: data,
        ),
      );

  group('Код достаётся из ответа', () {
    test('из конверта бизнес-ошибки', () {
      expect(
        errorCode({
          'success': false,
          'error': {'code': 'BOTH_BALANCES_SET', 'message': 'nope'},
        }),
        'BOTH_BALANCES_SET',
      );
    });

    test('из текста pydantic-валидатора', () {
      expect(
        errorCode({
          'detail': [
            {
              'loc': ['body'],
              'msg': 'Value error, BOTH_BALANCES_SET',
              'type': 'value_error',
            },
          ],
        }),
        'BOTH_BALANCES_SET',
      );
    });

    test('из строкового detail', () {
      expect(errorCode({'detail': 'ORDER_ALREADY_COMPLETED'}),
          'ORDER_ALREADY_COMPLETED');
    });

    test('обычный текст кодом не считается', () {
      expect(errorCode({'detail': 'Телефон уже занят'}), isNull);
      expect(errorCode({'detail': 'not found'}), isNull);
      expect(errorCode('строка вместо тела'), isNull);
    });
  });

  group('Подпись по коду', () {
    test('известный код объясняется по-русски', () {
      final message = apiErrorMessage(
        ru,
        failure({
          'error': {'code': 'BOTH_BALANCES_SET'},
        }),
      );

      expect(message, ru.errorBothBalances);
      expect(message, isNot(ru.errorGeneric));
    });

    test('и по-узбекски тоже', () {
      final message = apiErrorMessage(
        uz,
        failure({
          'error': {'code': 'ROUTE_NOT_IN_PROGRESS'},
        }),
      );

      expect(message, uz.errorRouteNotInProgress);
    });

    test('код важнее английского текста рядом', () {
      // Текст у сервера написан для разработчика; до водителя ему доходить
      // незачем — он его не прочтёт.
      final message = apiErrorMessage(
        ru,
        failure({
          'detail': [
            {
              'loc': ['body', 'payment_amount'],
              'msg': 'Value error, INVALID_DAMAGED_COUNT',
              'type': 'value_error',
            },
          ],
        }),
      );

      expect(message, ru.errorInvalidDamagedCount);
    });

    test('отказы переноса и правки оплаты объясняются', () {
      // Три случая, в которые админ упирается чаще всего: перенос закрытого
      // заказа, правка оплаты у незакрытого и дата в прошлом.
      expect(
        apiErrorMessage(ru, failure({'error': {'code': 'ORDER_ALREADY_COMPLETED'}})),
        ru.errorOrderCompleted,
      );
      expect(
        apiErrorMessage(ru, failure({'error': {'code': 'ORDER_NOT_COMPLETED'}})),
        ru.errorOrderNotCompleted,
      );
      expect(
        apiErrorMessage(ru, failure({'error': {'code': 'DATE_IN_PAST'}})),
        ru.errorDateInPast,
      );
    });

    test('русский текст сервера остаётся, если кода нет', () {
      final message = apiErrorMessage(ru, failure({'detail': 'Телефон занят'}));
      expect(message, 'Телефон занят');
    });

    test('незнакомый код падает на общую подпись, а не выдумывает своей', () {
      // Список кодов у сервера открытый: сочинять подпись под неизвестное
      // значит однажды соврать пользователю.
      final message = apiErrorMessage(
        ru,
        failure({
          'error': {'code': 'SOMETHING_NEW'},
        }),
        fallback: 'Не удалось сохранить',
      );

      expect(message, 'Не удалось сохранить');
    });
  });
}

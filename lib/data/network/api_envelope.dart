import 'package:dio/dio.dart';

import '../../l10n/l10n.dart';
import 'validation_errors.dart';

/// Разбор ответов Water CRM API.
///
/// Ответы встречались в двух видах — «голом» и в конверте
/// `{ success, data }` / `{ success, error: { code, message } }`. В самой
/// OpenAPI-схеме конверта нет: там все ответы описаны голыми, а единственная
/// описанная ошибка — `HTTPValidationError { detail }`.
///
/// Расхождение не разрешено (боевые ответы не снимались), поэтому хелперы
/// понимают все три формы. Убирать терпимость к конверту без сверки с живым
/// сервером нельзя: если он всё-таки оборачивает, отвалится сразу весь разбор.

/// Возвращает полезную нагрузку: разворачивает `data`, если пришёл конверт.
dynamic unwrapData(dynamic body) {
  if (body is Map<String, dynamic> && body.containsKey('data')) {
    return body['data'];
  }
  return body;
}

/// Приводит нагрузку к `Map<String, dynamic>` (с распаковкой конверта).
Map<String, dynamic> asMap(dynamic body) {
  final data = unwrapData(body);
  return (data as Map).cast<String, dynamic>();
}

/// Текст, написанный сервером, — если он написан для пользователя.
///
/// Признак — кириллица. Английский текст сервер пишет для разработчика:
/// `msg` у Pydantic всегда английский («Input should be a valid integer»),
/// и до водителя ему доходить незачем — он его не прочтёт. Русский же
/// `detail` бэкенд пишет осознанно («Телефон уже занят»), и заменять его
/// общей фразой значило бы потерять смысл.
///
/// Костыль ровно до тех пор, пока в API не появятся коды ошибок: тогда
/// текст будет собираться по коду, а не угадываться по алфавиту.
final _cyrillic = RegExp(r'[А-Яа-яЁё]');

String? _serverWrittenMessage(Object? detail) {
  if (detail is! String || detail.isEmpty) return null;
  return _cyrillic.hasMatch(detail) ? detail : null;
}

/// Достаёт человекочитаемое сообщение об ошибке из ответа API.
String apiErrorMessage(
  AppLocalizations l10n,
  DioException e, {
  String? fallback,
}) {
  final data = e.response?.data;
  if (data is Map) {
    final detail = data['detail'];

    // `{ detail: [{ loc, msg, type }] }` — единственная ошибка, описанная в
    // схеме. Текст собирается заново по `type` и `loc`; английский `msg`
    // наружу не идёт, он уходит в лог и в отчёт об ошибке.
    final validation = validationErrorMessage(l10n, detail);
    if (validation != null) return validation;

    // `{ detail: "текст" }` — так бэкенд отвечает на бизнес-отказы.
    final written = _serverWrittenMessage(detail);
    if (written != null) return written;

    // Конверта `{ error: { code, message } }` в схеме нет вовсе. Ветка
    // оставлена на случай, если он всё-таки где-то отвечает, но и здесь
    // наружу идёт только текст, написанный для пользователя.
    if (data['error'] is Map) {
      final message = _serverWrittenMessage((data['error'] as Map)['message']);
      if (message != null) return message;
    }
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.connectionError:
      return l10n.errorNoConnection;
    default:
      return fallback ?? l10n.errorGeneric;
  }
}

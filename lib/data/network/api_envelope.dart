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

/// Подпись к стабильному коду ошибки сервера.
///
/// Коды — единственная часть ответа, на которую можно опереться: текст рядом
/// с ними английский и написан для разработчика. До этого разбора клиент
/// показывал только кириллические сообщения, а всё остальное глотал и
/// заменял общим «Не удалось» — из-за чего водитель на отказе «в долг сумма
/// должна быть нулём» не понимал ровно ничего.
///
/// Незнакомый код возвращает `null`: список у сервера открытый, и выдумывать
/// подпись под неизвестное значит однажды соврать.
String? _messageForCode(AppLocalizations l10n, String? code) =>
    switch (code) {
      'BOTH_BALANCES_SET' => l10n.errorBothBalances,
      'BULK_PRICE_REQUIRED' => l10n.errorBulkPriceRequired,
      'INVALID_DAMAGED_COUNT' => l10n.errorInvalidDamagedCount,
      'ORDER_ALREADY_COMPLETED' => l10n.errorOrderCompleted,
      'ORDER_NOT_COMPLETED' => l10n.errorOrderNotCompleted,
      'DATE_IN_PAST' => l10n.errorDateInPast,
      'ROUTE_NOT_IN_PROGRESS' => l10n.errorRouteNotInProgress,
      'CUSTOMER_PHONE_ALREADY_EXISTS' => l10n.errorCustomerPhoneExists,
      'PHONE_ALREADY_EXISTS' || 'USER_ALREADY_EXISTS' => l10n.errorPhoneExists,
      'DRIVER_BUSY' => l10n.errorDriverBusy,
      'ROUTE_ALREADY_STARTED' => l10n.errorRouteStarted,
      'ROUTE_ALREADY_COMPLETED' => l10n.errorRouteCompleted,
      'FORBIDDEN' || 'ACCESS_DENIED' => l10n.errorAccessDenied,
      'NOT_FOUND' ||
      'ORDER_NOT_FOUND' ||
      'ROUTE_CUSTOMER_NOT_FOUND' ||
      'EXPENSE_NOT_FOUND' =>
        l10n.errorNotFound,
      _ => null,
    };

/// Достаёт код ошибки из ответа, в каком бы виде он ни пришёл.
///
/// Мест два, потому что у сервера два пути отказа. Бизнес-ошибка приходит
/// конвертом `{error: {code, message}}`. А отказ pydantic-валидатора кладёт
/// тот же код в `detail[].msg` строкой вида «Value error, BOTH_BALANCES_SET»
/// — это не стиль, а факт: `BOTH_BALANCES_SET` проверяется и сервисом, и
/// схемой, и по какому из путей ответ придёт, зависит от эндпоинта.
String? errorCode(Object? data) {
  if (data is! Map) return null;

  final error = data['error'];
  if (error is Map) {
    final code = error['code'];
    if (code is String && code.isNotEmpty) return code;
  }

  final detail = data['detail'];
  final texts = <String>[
    if (detail is String) detail,
    if (detail is List)
      for (final item in detail)
        if (item is Map && item['msg'] is String) item['msg'] as String,
  ];
  for (final text in texts) {
    final match = RegExp(r'\b([A-Z][A-Z0-9_]{3,})\b').firstMatch(text);
    if (match != null) return match.group(1);
  }
  return null;
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

    // Код первее всего остального: это единственная часть ответа, которую
    // сервер обещает не менять, и подпись к ней написана на языке
    // пользователя, а не разработчика.
    final byCode = _messageForCode(l10n, errorCode(data));
    if (byCode != null) return byCode;

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

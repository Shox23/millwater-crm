import 'package:dio/dio.dart';

import '../../l10n/l10n.dart';

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

/// Текст из поля `detail` FastAPI; `null` — разобрать не вышло.
///
/// Список валидационных ошибок склеивается в одну строку: показывать
/// водителю только первую из трёх причин — значит гонять его по кругу.
String? _detailMessage(dynamic detail) {
  if (detail is String && detail.isNotEmpty) return detail;

  if (detail is List) {
    final messages = detail
        .whereType<Map>()
        .map((item) => item['msg'])
        .whereType<String>()
        .where((msg) => msg.isNotEmpty)
        .toList();
    if (messages.isNotEmpty) return messages.join('. ');
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
    // Конверт бизнес-ошибки: `{ error: { code, message } }`.
    if (data['error'] is Map) {
      final message = (data['error'] as Map)['message'] as String?;
      if (message != null && message.isNotEmpty) return message;
    }
    // FastAPI: `{ detail: "текст" }` либо `{ detail: [{ loc, msg, type }] }`.
    // Только этот вид и описан в схеме, а раньше он не разбирался — и
    // отлуп валидации доходил до пользователя безликим «Ошибка запроса».
    final detail = _detailMessage(data['detail']);
    if (detail != null) return detail;
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

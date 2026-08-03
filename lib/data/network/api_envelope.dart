import 'package:dio/dio.dart';

/// Сервер отвечает конвертом:
///   успех:  `{ "success": true,  "data": <payload> }`
///   ошибка: `{ "success": false, "error": { code, message, details } }`
///
/// Хелперы ниже терпимы к обоим вариантам (обёрнутый и «голый» ответ),
/// чтобы парсинг не зависел от несоответствий OpenAPI-схемы.

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

/// Достаёт человекочитаемое сообщение об ошибке из конверта API.
String apiErrorMessage(DioException e, {String fallback = 'Ошибка запроса.'}) {
  final data = e.response?.data;
  if (data is Map && data['error'] is Map) {
    final err = (data['error'] as Map);
    final message = err['message'] as String?;
    if (message != null && message.isNotEmpty) return message;
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.connectionError:
      return 'Нет связи с сервером.';
    default:
      return fallback;
  }
}

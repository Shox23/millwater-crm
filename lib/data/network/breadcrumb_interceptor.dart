import 'package:dio/dio.dart';

import '../../core/observability/observability.dart';

/// Оставляет в отчёте след запросов — чем приложение занималось до падения.
///
/// Этим закрываются все три случая, ради которых след и нужен: вход
/// (`POST /auth/login`), смена прайса (`POST /admin/prices`) и завершение
/// доставки (`POST /driver/routes/customers/{id}/complete`). Когда придёт
/// жалоба на неверную сумму, последовательность будет видна.
///
/// Записываются только метод, путь и код ответа. Ни тел, ни заголовков, ни
/// query-параметров:
/// * в теле входа лежит пароль, в ответе — пара токенов;
/// * в заголовке `Authorization` — рабочий токен сессии;
/// * в `search` — имя или адрес заказчика, то есть чужие личные данные.
///
/// Путь оставляем целиком: идентификаторы в нём — UUID, по ним и находится
/// нужная запись, когда жалоба дойдёт.
class BreadcrumbInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _record(
      response.requestOptions,
      status: response.statusCode,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(
      err.requestOptions,
      status: err.response?.statusCode,
      // Ответа может не быть вовсе — тогда полезен вид сбоя: таймаут это
      // был или обрыв.
      failure: err.response == null ? err.type.name : null,
    );
    handler.next(err);
  }

  void _record(
    RequestOptions options, {
    int? status,
    String? failure,
  }) {
    Observability.breadcrumb(
      category: 'http',
      message: '${options.method} ${options.path}',
      data: {
        'status': ?status,
        'failure': ?failure,
      },
    );
  }
}

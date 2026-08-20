import 'dart:io';

import 'package:crm_millwater/core/observability/error_noise.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final request = RequestOptions(path: '/admin/customers');

  DioException dio(
    DioExceptionType type, {
    int? status,
    Object? error,
  }) =>
      DioException(
        requestOptions: request,
        type: type,
        error: error,
        response: status == null
            ? null
            : Response<dynamic>(
                requestOptions: request,
                statusCode: status,
              ),
      );

  group('Что не попадает в трекер', () {
    test('обрывы связи — их у водителя десятки за смену', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(isReportableError(dio(type)), isFalse, reason: type.name);
      }
    });

    test('SocketException, завёрнутый dio в unknown', () {
      // Именно так до приложения доходит «сеть недоступна»: отдельного типа
      // у dio для этого нет.
      final error = dio(
        DioExceptionType.unknown,
        error: const SocketException('Network is unreachable'),
      );
      expect(isReportableError(error), isFalse);
    });

    test('отмена — её инициируем мы сами', () {
      // Остановка потока уведомлений, уход с экрана до ответа.
      expect(isReportableError(dio(DioExceptionType.cancel)), isFalse);
    });

    test('4xx — сервер ответил, пользователь увидел текст', () {
      for (final status in [400, 401, 403, 404, 409, 422]) {
        expect(isReportableError(dio(DioExceptionType.badResponse,
                status: status)),
            isFalse,
            reason: '$status');
      }
    });

    test('null вместо ошибки', () {
      expect(isReportableError(null), isFalse);
    });
  });

  group('Что попадает', () {
    test('5xx — сломался сервер, само не исправится', () {
      for (final status in [500, 502, 503, 504]) {
        expect(
            isReportableError(dio(DioExceptionType.badResponse, status: status)),
            isTrue,
            reason: '$status');
      }
    });

    test('ошибки не из сети — ради них всё и затевалось', () {
      expect(isReportableError(StateError('Unknown user role: manager')), isTrue);
      expect(isReportableError(TypeError()), isTrue);
      expect(
        isReportableError(const FormatException('неожиданный ответ')),
        isTrue,
      );
    });

    test('сертификату нельзя верить — это не «нет сети»', () {
      // Сеть жива: либо на сервере просрочен сертификат, либо между нами и
      // сервером кто-то стоит. Повод разобраться, а не молча повторить.
      expect(isReportableError(dio(DioExceptionType.badCertificate)), isTrue);
    });

    test('разбор ответа не уложился в срок — это наш код, а не сеть', () {
      expect(isReportableError(dio(DioExceptionType.transformTimeout)), isTrue);
    });
  });
}

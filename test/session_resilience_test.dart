import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/user_role.dart';
import 'package:crm_millwater/data/network/dio_client.dart';
import 'package:crm_millwater/data/network/session_storage.dart';
import 'package:crm_millwater/data/repositories/api_driver_repository.dart';
import 'package:crm_millwater/data/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Сессия, уже лежащая на диске после прошлого входа.
InMemorySessionStorage storedSession() => InMemorySessionStorage({
      'access_token': 'stored-access',
      'refresh_token': 'stored-refresh',
      'role': 'driver',
    });

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Сервер, до которого запрос не доходит.
class _OfflineAdapter implements HttpClientAdapter {
  _OfflineAdapter(this.type);

  final DioExceptionType type;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(requestOptions: options, type: type);
  }
}

/// Отвечает 401 на первый рабочий запрос, пускает refresh и считает, сколько
/// байт тела дошло до сервера в каждой попытке.
class _ExpiredTokenAdapter implements HttpClientAdapter {
  final List<int> bodyBytes = [];
  int completeCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/auth/refresh')) {
      return _json(const {
        'access_token': 'fresh-access',
        'refresh_token': 'fresh-refresh',
        'token_type': 'bearer',
        'role': 'driver',
      }, 200);
    }

    // Тело читаем целиком: именно его пустота и означала бы потерянное фото.
    var length = 0;
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        length += chunk.length;
      }
    }
    bodyBytes.add(length);
    completeCalls++;

    // Первый заход — протухший токен, второй (после refresh) принимаем.
    return completeCalls == 1
        ? _json(const {'detail': 'Token expired'}, 401)
        : _json(const {}, 204);
  }
}

void main() {
  group('Восстановление сессии', () {
    test('недоступный сервер не выкидывает на экран входа', () async {
      final storage = storedSession();
      final store = AuthTokenStore(storage);
      final dio = Dio()..httpClientAdapter = _OfflineAdapter(
          DioExceptionType.connectionError,
        );

      final role = await AuthRepository(dio, store).restoreSession();

      // Роль поднялась с диска, а токены остались на месте: водителю в
      // подвале нечем заново ввести пароль.
      expect(role, UserRole.driver);
      expect(await storage.read('access_token'), 'stored-access');
    });

    test('таймаут тоже не считается отказом сессии', () async {
      final storage = storedSession();
      final dio = Dio()..httpClientAdapter = _OfflineAdapter(
          DioExceptionType.connectionTimeout,
        );

      final role =
          await AuthRepository(dio, AuthTokenStore(storage)).restoreSession();

      expect(role, UserRole.driver);
      expect(await storage.read('refresh_token'), 'stored-refresh');
    });

    test('отказ сервера сессию стирает', () async {
      final storage = storedSession();
      final dio = Dio()
        ..httpClientAdapter = _StatusAdapter(401)
        // Без refresh-токена интерсептора нет — 401 доходит как есть.
        ;

      final role = await AuthRepository(dio, AuthTokenStore(storage))
          .restoreSession();

      expect(role, isNull);
      expect(await storage.read('access_token'), isNull);
    });

    test('пустое хранилище — сразу вход, без запроса к серверу', () async {
      final adapter = _StatusAdapter(200);
      final dio = Dio()..httpClientAdapter = adapter;

      final role = await AuthRepository(dio, AuthTokenStore(
        InMemorySessionStorage(),
      )).restoreSession();

      expect(role, isNull);
      expect(adapter.calls, 0);
    });
  });

  group('Повтор запроса после обновления токена', () {
    test('завершение доставки с фото переживает 401', () async {
      final adapter = _ExpiredTokenAdapter();
      final store = AuthTokenStore(storedSession());
      await store.restore();

      final dio = buildDio(store, adapter: adapter);

      // Файл нужен настоящий: MultipartFile.fromFile читает его с диска,
      // и именно повторное чтение проверяется.
      final photo = File('${Directory.systemTemp.path}/receipt.jpg')
        ..writeAsBytesSync(List<int>.filled(2048, 7));
      addTearDown(() => photo.deleteSync());

      await ApiDriverRepository(dio).completeDelivery(
        stopId: 'stop-1',
        capsules: 2,
        amount: 40000,
        bottleBalance: 2,
        method: PaymentMethod.card,
        photoPath: photo.path,
      );

      // Две попытки — и вторая унесла столько же байт, сколько первая.
      // Без FormData.clone() повтор ушёл бы пустым.
      expect(adapter.completeCalls, 2);
      expect(adapter.bodyBytes.length, 2);
      expect(adapter.bodyBytes[1], adapter.bodyBytes[0]);
      expect(adapter.bodyBytes[1], greaterThan(2048));
    });
  });
}

/// Отвечает заданным статусом и считает обращения.
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;
  int calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return _json(const {'detail': 'nope'}, status);
  }
}

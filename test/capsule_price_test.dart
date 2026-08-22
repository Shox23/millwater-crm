import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/core/product_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Отвечает тем, что задали, и считает обращения.
class _PriceAdapter implements HttpClientAdapter {
  _PriceAdapter(this.respond);

  /// Что вернуть на очередной запрос. Бросок означает ответ сервера ошибкой.
  final ResponseBody Function(int call) respond;

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
    return respond(calls);
  }
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Прайс, как его отдаёт `/admin/prices/current`: деньги строками.
Object _price(String water) => {
      'id': 'price-1',
      'water_price': water,
      'deposit_price': '50000.00',
      'created_at': '2026-08-20T10:00:00Z',
    };

Dio _dio(_PriceAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://example.test',
    // Иначе dio сам бросает на 4xx до того, как это увидит источник цены.
    validateStatus: (_) => true,
  ));
  dio.httpClientAdapter = adapter;
  return dio;
}

/// Dio, повторяющий боевую настройку: 4xx приходят исключением.
Dio _strictDio(_PriceAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  final build = ProductConfig.capsulePrice;

  group('Цена берётся с сервера', () {
    test('прайс сервера важнее значения сборки', () async {
      final adapter = _PriceAdapter((_) => _json(_price('25000.00')));
      final price = ApiCapsulePrice(_strictDio(adapter));

      expect(await price.value(), 25000);
      expect(await price.value(), 25000);
      // Второй вызов обслужен кэшем: точки маршрута открывают подряд, и
      // спрашивать прайс на каждую незачем.
      expect(adapter.calls, 1);
    });

    test('параллельные вызовы делят один запрос', () async {
      final adapter = _PriceAdapter((_) => _json(_price('25000.00')));
      final price = ApiCapsulePrice(_strictDio(adapter));

      final values = await Future.wait([price.value(), price.value()]);

      expect(values, [25000, 25000]);
      expect(adapter.calls, 1);
    });

    test('цена протухает и запрашивается заново', () async {
      var now = DateTime(2026, 8, 20, 10);
      final adapter = _PriceAdapter(
        (call) => _json(_price(call == 1 ? '20000.00' : '25000.00')),
      );
      final price = ApiCapsulePrice(_strictDio(adapter), now: () => now);

      expect(await price.value(), 20000);
      now = now.add(ApiCapsulePrice.ttl + const Duration(minutes: 1));
      // Прайс меняют приказом среди дня, а приложение водитель не
      // перезапускает — иначе новая цена дошла бы до него только назавтра.
      expect(await price.value(), 25000);
      expect(adapter.calls, 2);
    });
  });

  group('Отказ сервера гасится молча', () {
    test('403 у водителя — считаем по сборке и больше не спрашиваем', () async {
      final adapter = _PriceAdapter((_) => _json({'detail': 'Forbidden'}, 403));
      final price = ApiCapsulePrice(_strictDio(adapter));

      expect(await price.value(), build);
      expect(await price.value(), build);
      // Роль в пределах сессии не меняется: второй запрос получил бы тот же
      // отказ, а водителю каждый лишний запрос — это трафик в дороге.
      expect(adapter.calls, 1);
    });

    test('обрыв связи не запоминается — следующая точка пробует снова',
        () async {
      final adapter = _PriceAdapter((call) {
        if (call == 1) {
          throw DioException.connectionError(
            requestOptions: RequestOptions(path: '/admin/prices/current'),
            reason: 'нет сети',
          );
        }
        return _json(_price('25000.00'));
      });
      final price = ApiCapsulePrice(_strictDio(adapter));

      expect(await price.value(), build);
      expect(await price.value(), 25000);
      expect(adapter.calls, 2);
    });

    test('5xx не запоминается: сервер чинят, роль ни при чём', () async {
      final adapter = _PriceAdapter(
        (call) => call == 1 ? _json({'detail': 'oops'}, 500) : _json(_price('25000.00')),
      );
      final price = ApiCapsulePrice(_strictDio(adapter));

      expect(await price.value(), build);
      expect(await price.value(), 25000);
    });

    test('неразобранный ответ не превращается в нулевую цену', () async {
      // `MoneyParser` отдаёт ноль на всём, чего не понял, — считать по нему
      // значило бы тихо выставить заказчику ноль сум.
      final adapter = _PriceAdapter((_) => _json(_price('не число')));
      final price = ApiCapsulePrice(_dio(adapter));

      expect(await price.value(), build);
    });

    test('ответ не той формы — тоже откат на сборку', () async {
      final adapter = _PriceAdapter((_) => _json('<html>502 Bad Gateway</html>'));
      final price = ApiCapsulePrice(_dio(adapter));

      expect(await price.value(), build);
    });
  });

  test('источник сборки ходит только в сборку', () async {
    expect(await const BuildCapsulePrice().value(), build);
  });
}

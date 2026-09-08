import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/core/maps/address_geocoder.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Отвечает заранее заданным ответом и запоминает параметры запросов.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.answers);

  /// Ответы по порядку: `null` — «ничего не найдено».
  final List<Object?> answers;

  final List<Map<String, dynamic>> queries = [];
  int _call = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    queries.add(Map<String, dynamic>.from(options.queryParameters));
    final answer = _call < answers.length ? answers[_call] : null;
    _call++;
    return ResponseBody.fromString(
      jsonEncode(answer ?? const []),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Dio _dio(_FakeAdapter adapter) =>
    Dio(BaseOptions(responseType: ResponseType.json))
      ..httpClientAdapter = adapter;

void main() {
  group('NominatimGeocoder', () {
    test('находит адрес и отдаёт координаты', () async {
      final adapter = _FakeAdapter([
        [
          {'lat': '41.3252553', 'lon': '69.2868505'}
        ]
      ]);

      final point = await NominatimGeocoder(dio: _dio(adapter))
          .locate('Улица Ниёзбек Йули, 42/5');

      expect(point, isNotNull);
      expect(point!.latitude, closeTo(41.325, 0.001));
      expect(point.longitude, closeTo(69.287, 0.001));
      // Ищем только по Узбекистану: одноимённых улиц в мире достаточно.
      expect(adapter.queries.single['countrycodes'], 'uz');
    });

    test('сначала в границах Ташкента, потом по всей стране', () async {
      final adapter = _FakeAdapter([
        null,
        [
          {'lat': '41.15', 'lon': '69.11'}
        ],
      ]);

      final point =
          await NominatimGeocoder(dio: _dio(adapter)).locate('корасу 1/6');

      expect(point, isNotNull);
      expect(adapter.queries.map((q) => q['bounded']), [1, 0]);
    });

    test('второй раз тот же адрес в сеть не идёт', () async {
      final adapter = _FakeAdapter([
        [
          {'lat': '41.31', 'lon': '69.24'}
        ]
      ]);
      final geocoder = NominatimGeocoder(dio: _dio(adapter));

      await geocoder.locate('Шофиркон 5');
      await geocoder.locate('Шофиркон 5');

      // Публичный сервис пускает не чаще запроса в секунду — повторов быть
      // не должно.
      expect(adapter.queries, hasLength(1));
    });

    test('ненайденный адрес больше не спрашивается', () async {
      final adapter = _FakeAdapter([null, null]);
      final geocoder = NominatimGeocoder(dio: _dio(adapter));

      expect(await geocoder.locate('Такого адреса нет'), isNull);
      expect(await geocoder.locate('Такого адреса нет'), isNull);

      // Два запроса первой попытки (в границах и без), и ни одного второй.
      expect(adapter.queries, hasLength(2));
    });

    test('чушь в ответе не превращается в точку', () async {
      // Координаты вне рамки правдоподобия: перепутанный порядок или мусор
      // увёл бы водителя за тысячи километров.
      final adapter = _FakeAdapter([
        [
          {'lat': '69.24', 'lon': '41.31'}
        ]
      ]);

      expect(
        await NominatimGeocoder(dio: _dio(adapter)).locate('Ташкент'),
        isNull,
      );
    });
  });

  group('YandexGeocoder', () {
    Object yandexAnswer(String pos) => {
          'response': {
            'GeoObjectCollection': {
              'featureMember': [
                {
                  'GeoObject': {
                    'Point': {'pos': pos}
                  }
                }
              ]
            }
          }
        };

    test('pos читается как «долгота широта»', () async {
      final adapter = _FakeAdapter([yandexAnswer('69.240562 41.311081')]);

      final point = await YandexGeocoder(apiKey: 'k', dio: _dio(adapter))
          .locate('Шофиркон 5');

      // Порядок обратный привычному — на этом ошибаются чаще всего.
      expect(point!.latitude, closeTo(41.311, 0.001));
      expect(point.longitude, closeTo(69.240, 0.001));
      expect(adapter.queries.single['apikey'], 'k');
    });

    test('пустой ответ — это «не нашли», а не ошибка', () async {
      final adapter = _FakeAdapter([
        {
          'response': {
            'GeoObjectCollection': {'featureMember': <Object>[]}
          }
        }
      ]);

      expect(
        await YandexGeocoder(apiKey: 'k', dio: _dio(adapter)).locate('X'),
        isNull,
      );
    });
  });
}

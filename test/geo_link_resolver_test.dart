import 'dart:typed_data';

import 'package:crm_millwater/core/maps/geo_link.dart';
import 'package:crm_millwater/core/maps/geo_link_resolver.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Короткая ссылка на карту — то, что менеджер вставляет в поле адреса чаще
/// всего. Координат в ней нет вовсе: они появляются только после перехода по
/// редиректу, и до этой сборки такая строка уходила в маршрут текстом.
///
/// Ташкент, на нём собраны все примеры.
const lat = 41.311081;
const lon = 69.240562;

/// Отвечает на запросы редиректами по заранее заданной цепочке.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.hops, {this.body = ''});

  /// Адрес → значение заголовка `Location`. Чего нет в карте — конечная
  /// страница, она отдаёт [body].
  final Map<String, String> hops;
  final String body;

  final List<String> requested = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requested.add(url);

    final next = hops[url];
    if (next != null) {
      return ResponseBody.fromString('', 302, headers: {
        'location': [next],
      });
    }
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: ['text/html'],
    });
  }
}

GeoLinkResolver _resolver(_FakeAdapter adapter, {int maxHops = 5}) {
  final dio = Dio(BaseOptions(
    followRedirects: false,
    validateStatus: (code) => code != null && code < 400,
    responseType: ResponseType.plain,
  ))..httpClientAdapter = adapter;
  return GeoLinkResolver(dio: dio, maxHops: maxHops);
}

void main() {
  void expectTashkent(GeoPoint? point) {
    expect(point, isNotNull, reason: 'координаты не найдены');
    expect(point!.latitude, closeTo(lat, 0.001));
    expect(point.longitude, closeTo(lon, 0.001));
  }

  test('обычный адрес в сеть не ходит', () async {
    final adapter = _FakeAdapter(const {});
    final resolved = await _resolver(adapter).resolve('Шофиркон 5');

    expect(resolved.isEmpty, isTrue);
    expect(adapter.requested, isEmpty, reason: 'текст резолвить нечем');
  });

  test('ссылка с координатами разбирается на месте', () async {
    final adapter = _FakeAdapter(const {});
    final resolved = await _resolver(adapter)
        .resolve('https://yandex.uz/maps/?ll=$lon,$lat&z=17');

    expectTashkent(resolved.point);
    expect(adapter.requested, isEmpty, reason: 'сеть здесь не нужна');
  });

  test('короткая ссылка разворачивается по цепочке редиректов', () async {
    // Ровно тот случай со стенда: `share.google` ведёт на длинную ссылку
    // Google, и координаты лежат уже в ней.
    final adapter = _FakeAdapter({
      'https://share.google/zhOQ2JLKjOKc2lUSi':
          'https://maps.app.goo.gl/aBcDeFgH',
      'https://maps.app.goo.gl/aBcDeFgH':
          'https://www.google.com/maps/place/IT+Park/@$lat,$lon,17z',
    });

    final resolved =
        await _resolver(adapter).resolve('https://share.google/zhOQ2JLKjOKc2lUSi');

    expectTashkent(resolved.point);
    expect(adapter.requested, hasLength(2));
  });

  test('координаты ищутся и в теле конечной страницы', () async {
    final adapter = _FakeAdapter(
      const {},
      body: '<html><head>'
          '<link rel="canonical" href="https://www.google.com/maps/place/X/'
          '@$lat,$lon,17z"/>'
          '</head></html>',
    );

    expectTashkent(
      (await _resolver(adapter).resolve('https://share.google/zhOQ2JLKjOKc2lUSi'))
          .point,
    );
  });

  test('адрес со ссылкой внутри тоже разворачивается', () async {
    final adapter = _FakeAdapter({
      'https://share.google/abc':
          'https://www.google.com/maps/place/X/@$lat,$lon,17z',
    });

    expectTashkent(
      (await _resolver(adapter).resolve('Чиланзар, 12 кв https://share.google/abc'))
          .point,
    );
  });

  test('ссылка ведёт в поиск — забираем название места', () async {
    // Живая цепочка со стенда: `share.google` уводит **не на карту, а в поиск
    // Google**, и координат в ней нет ни одной. Единственное полезное там —
    // название места в `q`, по нему точка и находится.
    final adapter = _FakeAdapter({
      'https://share.google/zhOQ2JLKjOKc2lUSi':
          'https://www.google.com/share.google?q=zhOQ2JLKjOKc2lUSi',
      'https://www.google.com/share.google?q=zhOQ2JLKjOKc2lUSi':
          'https://www.google.com/search?output=search&q=IT+Park+Uzbekistan&kgs=f7ad',
    });

    final resolved =
        await _resolver(adapter).resolve('https://share.google/zhOQ2JLKjOKc2lUSi');

    expect(resolved.point, isNull, reason: 'координат в цепочке нет');
    // Идентификатор самой ссылки названием не считается.
    expect(resolved.searchText, 'IT Park Uzbekistan');
  });

  test('второй раз тот же адрес в сеть не ходит', () async {
    final adapter = _FakeAdapter({
      'https://share.google/abc':
          'https://www.google.com/maps/place/X/@$lat,$lon,17z',
    });
    final resolver = _resolver(adapter);

    await resolver.resolve('https://share.google/abc');
    await resolver.resolve('https://share.google/abc');

    // Маршрут из десяти точек не должен десять раз ходить за одной ссылкой.
    expect(adapter.requested, hasLength(1));
  });

  test('бесконечный редирект обрывается по счётчику', () async {
    final adapter = _FakeAdapter({
      'https://share.google/loop': 'https://share.google/loop',
    });

    final resolved =
        await _resolver(adapter, maxHops: 3).resolve('https://share.google/loop');

    expect(resolved.isEmpty, isTrue);
    expect(adapter.requested, hasLength(3));
  });

  test('отказ сети означает «координат нет», а не ошибку экрана', () async {
    final dio = Dio()
      ..httpClientAdapter = _ThrowingAdapter();

    expect(
      (await GeoLinkResolver(dio: dio).resolve('https://share.google/abc')).isEmpty,
      isTrue,
    );
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'нет сети',
      );
}

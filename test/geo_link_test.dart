import 'package:crm_millwater/core/maps/geo_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ссылка, вставленная менеджером в поле адреса. Сегодня такая строка уходит
/// в геокодер Яндекс.Карт как текст и не находится вовсе.
void main() {
  // Точка в Ташкенте, на ней собраны все примеры.
  const lat = 41.311081;
  const lon = 69.240562;

  void expectTashkent(GeoPoint? point, {required GeoLinkSource from}) {
    expect(point, isNotNull, reason: 'ссылка не распознана');
    expect(point!.latitude, closeTo(lat, 0.001));
    expect(point.longitude, closeTo(lon, 0.001));
    expect(point.source, from);
  }

  group('Google', () {
    test('метка места важнее центра экрана', () {
      // `@` — куда смотрит камера, `!3d/!4d` — где стоит метка. После того
      // как карту подвигали, они расходятся; верна вторая пара.
      final point = GeoLink.tryParse(
        'https://www.google.com/maps/place/Millwater/'
        '@41.350000,69.300000,17z/data=!3m1!4b1!4m6!3m5!1s0x38ae8b'
        '!8m2!3d$lat!4d$lon!16s%2Fg%2F11c',
      );

      expectTashkent(point, from: GeoLinkSource.google);
    });

    test('карта без метки читается по центру экрана', () {
      expectTashkent(
        GeoLink.tryParse('https://www.google.com/maps/@$lat,$lon,17z'),
        from: GeoLinkSource.google,
      );
    });

    test('параметр q читается как широта и долгота', () {
      expectTashkent(
        GeoLink.tryParse('https://maps.google.com/?q=$lat,$lon'),
        from: GeoLinkSource.google,
      );
    });

    test('percent-кодировка восклицательных знаков не мешает', () {
      expectTashkent(
        GeoLink.tryParse(
          'https://www.google.com/maps/place/X/data=%213m1%218m2'
          '%213d$lat%214d$lon',
        ),
        from: GeoLinkSource.google,
      );
    });
  });

  group('Яндекс', () {
    test('ll читается наоборот: долгота первая', () {
      // Главная ловушка формата. Прочитай мы ll как «широта, долгота» —
      // получили бы точку за тысячи километров отсюда.
      expectTashkent(
        GeoLink.tryParse('https://yandex.uz/maps/10335/tashkent/?ll=$lon,$lat&z=17'),
        from: GeoLinkSource.yandex,
      );
    });

    test('pt читается, а стиль метки за координатами отбрасывается', () {
      expectTashkent(
        GeoLink.tryParse('https://yandex.uz/maps/?pt=$lon,$lat,pm2rdm&z=16'),
        from: GeoLinkSource.yandex,
      );
    });

    test('rtext читается как «широта, долгота» — не как ll', () {
      // Ссылка навигатора с уже построенным маршрутом: менеджеры присылают
      // именно такие. В `rtext` порядок прямой, в отличие от `ll` — прочитав
      // его наравне с ll, получаем широту 69° и теряем точку.
      expectTashkent(
        GeoLink.tryParse('https://yandex.ru/navi?rtext=$lat,$lon&rtt=auto'),
        from: GeoLinkSource.yandex,
      );
    });

    test('из маршрута берётся точка назначения', () {
      // Первая пара — где стоял отправитель, вторая — куда он ехал, то есть
      // заказчик.
      final point = GeoLink.tryParse(
        'https://yandex.ru/navi?rtext=41.359684,69.206596~$lat,$lon&rtt=auto',
      );

      expectTashkent(point, from: GeoLinkSource.yandex);
    });

    test('whatshere тоже несёт точку', () {
      expectTashkent(
        GeoLink.tryParse(
          'https://yandex.uz/maps/?whatshere%5Bpoint%5D=$lon,$lat&whatshere%5Bzoom%5D=17',
        ),
        from: GeoLinkSource.yandex,
      );
    });
  });

  group('Прочие источники', () {
    test('geo: с координатами в пути', () {
      expectTashkent(
        GeoLink.tryParse('geo:$lat,$lon'),
        from: GeoLinkSource.geoUri,
      );
    });

    test('geo: андроидовского вида — точка в параметре q', () {
      // Путь здесь заглушка `0,0`, настоящая точка в `q`.
      expectTashkent(
        GeoLink.tryParse('geo:0,0?q=$lat,$lon(Кафе)'),
        from: GeoLinkSource.geoUri,
      );
    });

    test('голые координаты', () {
      expectTashkent(
        GeoLink.tryParse('$lat, $lon'),
        from: GeoLinkSource.plain,
      );
    });

    test('ссылка внутри адреса находится', () {
      expectTashkent(
        GeoLink.tryParse('Чиланзар, 12 квартал https://yandex.uz/maps/?ll=$lon,$lat'),
        from: GeoLinkSource.yandex,
      );
    });
  });

  group('Короткие ссылки', () {
    // Их разворачивает GeoLinkResolver — здесь только опознание: без него
    // ссылка уходила в маршрут текстом, и геокодер искал «https://…».
    test('share.google опознаётся как картографическая', () {
      final short = GeoLink.shortLinkIn('https://share.google/zhOQ2JLKjOKc2lUSi');

      expect(short, isNotNull);
      expect(short!.host, 'share.google');
      // Координат в ней нет: они появятся только после редиректа.
      expect(GeoLink.tryParse(short.toString()), isNull);
    });

    test('короткие ссылки Google и Яндекса тоже', () {
      for (final link in [
        'https://maps.app.goo.gl/aBcDeFgH',
        'https://goo.gl/maps/aBcDeFgH',
        'https://yandex.ru/maps/-/CDe1234',
      ]) {
        expect(GeoLink.shortLinkIn(link), isNotNull, reason: link);
      }
    });

    test('адрес со ссылкой внутри — тоже случай для резолвера', () {
      expect(
        GeoLink.shortLinkIn('Чиланзар, 12 кв https://share.google/abc'),
        isNotNull,
      );
    });

    test('обычный адрес и чужая ссылка резолверу не нужны', () {
      expect(GeoLink.shortLinkIn('Шофиркон 5'), isNull);
      expect(GeoLink.shortLinkIn('https://example.com/place'), isNull);
    });
  });

  group('Что не разбирается', () {
    test('обычный адрес остаётся адресом', () {
      expect(GeoLink.tryParse('Чиланзар, 12 квартал, дом 4'), isNull);
      expect(GeoLink.tryParse(''), isNull);
      expect(GeoLink.tryParse('   '), isNull);
    });

    test('короткая ссылка — работа сервера, не наша', () {
      // Координат в ней нет вовсе: нужен переход по редиректу.
      expect(GeoLink.tryParse('https://maps.app.goo.gl/aBcDeFgH'), isNull);
      expect(GeoLink.tryParse('https://yandex.ru/maps/-/CDxxxx'), isNull);
    });

    test('перепутанный порядок отсекается рамкой', () {
      // Прочитанная наоборот ташкентская точка попадает на север России:
      // диапазоны широты и долготы при этом формально соблюдены.
      expect(GeoLink.tryParse('https://maps.google.com/?q=$lon,$lat'), isNull);
    });

    test('точка вне региона не принимается', () {
      // Москва — почти наверняка не наш заказчик, а чужая ссылка в буфере.
      expect(GeoLink.tryParse('https://maps.google.com/?q=55.755,37.617'),
          isNull);
    });

    test('десятичная запятая не угадывается', () {
      // «41,311081, 69,240562» разбирается двояко — угадывать нельзя.
      expect(GeoLink.tryParse('41,311081, 69,240562'), isNull);
    });

    test('чужая карта не разбирается', () {
      expect(GeoLink.tryParse('https://2gis.uz/tashkent/firm/70000001'), isNull);
    });
  });
}

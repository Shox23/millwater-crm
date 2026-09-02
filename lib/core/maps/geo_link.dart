import 'package:equatable/equatable.dart';

/// Откуда взялась точка — нужно для диагностики и подписи в интерфейсе.
enum GeoLinkSource { google, yandex, geoUri, plain }

/// Координаты, вынутые из ссылки или текста.
class GeoPoint extends Equatable {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final GeoLinkSource source;

  @override
  List<Object?> get props => [latitude, longitude, source];
}

/// Разбор ссылок на карты и голых координат.
///
/// Нужен потому, что менеджеры вставляют ссылку прямо в поле адреса. Сегодня
/// такая строка уходит в `rtext` как текст, и геокодер Яндекс.Карт ищет
/// «https://yandex.uz/maps/?ll=…» — то есть не находит ничего. Разобрав её в
/// координаты, мы и точку ставим верно, и открываем маршрут в нативном
/// приложении, которому геокодинг уже не нужен.
///
/// Чистая функция без сети: короткие ссылки (`maps.app.goo.gl`,
/// `yandex.ru/maps/-/…`) координат не содержат и требуют перехода по
/// редиректу — их разбирает сервер (`POST /admin/geo/resolve`).
abstract class GeoLink {
  /// Рамка, за пределами которой точку считаем нераспознанной.
  ///
  /// Главная ловушка формата: у Google порядок «широта, долгота», у Яндекса
  /// обратный. Перепутав их, Ташкент (41.31, 69.24) превращается в (69.24,
  /// 41.31) — формально исправную точку на севере России. Ни по типу, ни по
  /// диапазону такая ошибка не видна, поэтому ловится рамкой.
  ///
  /// Расширять при выходе за пределы Узбекистана.
  static const minLatitude = 37.0;
  static const maxLatitude = 46.0;
  static const minLongitude = 55.0;
  static const maxLongitude = 74.0;

  /// Ищет координаты в [text]. `null` — не нашли или нашли неправдоподобное.
  ///
  /// [text] может быть и чистой ссылкой, и адресом с ссылкой внутри:
  /// «Чиланзар, 12 квартал https://yandex.uz/maps/?ll=…».
  static GeoPoint? tryParse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final uri = _firstUri(trimmed);
    final point = uri == null ? _plain(trimmed) : _fromUri(uri);

    return point != null && _isPlausible(point) ? point : null;
  }

  /// Первая ссылка в строке. Учитываются `http(s)://` и схема `geo:`.
  static Uri? _firstUri(String text) {
    final match =
        RegExp(r'(https?://\S+|geo:\S+)', caseSensitive: false).firstMatch(text);
    if (match == null) return null;
    return Uri.tryParse(match.group(0)!);
  }

  static GeoPoint? _fromUri(Uri uri) {
    if (uri.scheme == 'geo') return _geoUri(uri);

    final host = uri.host.toLowerCase();
    if (host.contains('yandex.')) return _yandex(uri);
    if (host.contains('google.') || host.endsWith('goo.gl')) return _google(uri);
    return null;
  }

  /// Google: порядок всегда «широта, долгота».
  ///
  /// Источники по убыванию точности:
  /// 1. `!3d<широта>!4d<долгота>` внутри `data=` — координаты самой метки;
  /// 2. `@<широта>,<долгота>` — центр экрана, а не метка: после того как
  ///    карту подвигали, расходится с меткой на сотни метров;
  /// 3. параметры `q`, `ll`, `daddr`.
  static GeoPoint? _google(Uri uri) {
    // Точка приходит и в percent-кодировке: `%213d` вместо `!3d`.
    final full = Uri.decodeFull(uri.toString());

    final pin = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)')
        .firstMatch(full);
    if (pin != null) {
      return _point(pin.group(1)!, pin.group(2)!, GeoLinkSource.google);
    }

    final camera =
        RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(full);
    if (camera != null) {
      return _point(camera.group(1)!, camera.group(2)!, GeoLinkSource.google);
    }

    for (final key in ['q', 'll', 'daddr', 'query']) {
      final pair = _pair(uri.queryParameters[key]);
      if (pair != null) {
        return _point(pair.$1, pair.$2, GeoLinkSource.google);
      }
    }
    return null;
  }

  /// Яндекс: порядок обратный — «долгота, широта».
  static GeoPoint? _yandex(Uri uri) {
    for (final key in ['ll', 'pt', 'whatshere[point]', 'rtext']) {
      final pair = _pair(uri.queryParameters[key]);
      // Меняем местами: у Яндекса первой идёт долгота.
      if (pair != null) {
        return _point(pair.$2, pair.$1, GeoLinkSource.yandex);
      }
    }
    return null;
  }

  /// `geo:41.31,69.24` либо андроидовское `geo:0,0?q=41.31,69.24(Метка)`.
  static GeoPoint? _geoUri(Uri uri) {
    final fromQuery = _pair(uri.queryParameters['q']);
    if (fromQuery != null) {
      return _point(fromQuery.$1, fromQuery.$2, GeoLinkSource.geoUri);
    }
    final fromPath = _pair(uri.path);
    return fromPath == null
        ? null
        : _point(fromPath.$1, fromPath.$2, GeoLinkSource.geoUri);
  }

  /// Голые координаты: «41.311081, 69.240562».
  ///
  /// Десятичная запятая («41,311081, 69,240562») намеренно не поддержана: она
  /// совпадает с разделителем координат, и разобрать такую строку однозначно
  /// нельзя. Угадывать здесь нельзя — цена ошибки в том, что водитель уедет
  /// не туда.
  static GeoPoint? _plain(String text) {
    final match = RegExp(r'^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$')
        .firstMatch(text);
    return match == null
        ? null
        : _point(match.group(1)!, match.group(2)!, GeoLinkSource.plain);
  }

  /// Первые два числа значения параметра. У Яндекса в `pt` за координатами
  /// идёт стиль метки (`69.24,41.31,pm2rdm`), у `rtext` — точки через `~`.
  static (String, String)? _pair(String? value) {
    if (value == null) return null;
    final numbers = RegExp(r'-?\d+(?:\.\d+)?')
        .allMatches(value)
        .map((m) => m.group(0)!)
        .toList();
    return numbers.length < 2 ? null : (numbers[0], numbers[1]);
  }

  static GeoPoint? _point(String lat, String lon, GeoLinkSource source) {
    final latitude = double.tryParse(lat);
    final longitude = double.tryParse(lon);
    if (latitude == null || longitude == null) return null;
    return GeoPoint(
      latitude: latitude,
      longitude: longitude,
      source: source,
    );
  }

  /// Точка похожа на настоящую: в допустимых пределах и внутри рамки.
  static bool _isPlausible(GeoPoint p) =>
      p.latitude >= minLatitude &&
      p.latitude <= maxLatitude &&
      p.longitude >= minLongitude &&
      p.longitude <= maxLongitude;
}

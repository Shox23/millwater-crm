import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../product_config.dart';
import 'geo_link.dart';

/// Превращает текстовый адрес в координаты.
///
/// Нужен ради одного: нативное приложение Яндекс.Карт принимает в маршруте
/// только координаты, текстовые адреса оно молча отбрасывает. Пока у точки
/// нет координат, маршрут открывается лишь в вебе — а водителю нужен
/// навигатор.
abstract class AddressGeocoder {
  /// Координаты адреса или `null`, если найти не удалось.
  Future<GeoPoint?> locate(String address);

  /// Геокодер по настройкам сборки.
  ///
  /// С ключом (`--dart-define=YANDEX_GEOCODER_KEY=…`) — Яндекс: он точнее на
  /// местных адресах и не ограничен по темпу. Без ключа — OpenStreetMap:
  /// ключа не требует и находит и улицы («Шофиркон 5»), и названия
  /// («IT Park Uzbekistan»), но с точностью до улицы и не быстрее запроса в
  /// секунду.
  factory AddressGeocoder.fromConfig({Dio? dio}) {
    const key = ProductConfig.yandexGeocoderKey;
    if (key.isEmpty) return NominatimGeocoder(dio: dio);
    return YandexGeocoder(apiKey: key, dio: dio);
  }
}

/// Геокодера нет — адрес остаётся текстом. Для тестов и отключённого поиска.
class NoGeocoder implements AddressGeocoder {
  const NoGeocoder();

  @override
  Future<GeoPoint?> locate(String address) async => null;
}

/// Найденные координаты, пережившие перезапуск.
///
/// Адреса заказчиков меняются раз в никогда, а поиск стоит запроса в сеть и
/// секунды ожидания. Без этого водитель ждал бы каждое утро заново.
///
/// Промахи не сохраняются: адрес могли поправить, и вечное «не найдено»
/// закрыло бы дорогу исправлению.
class GeocodeCache {
  GeocodeCache({this.namespace = 'geocode'});

  final String namespace;
  final Map<String, GeoPoint?> _memory = {};

  Future<GeoPoint?> read(String address) async {
    if (_memory.containsKey(address)) return _memory[address];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyOf(address));
      if (raw == null) return null;
      return _memory[address] = GeoLink.tryParse(raw);
    } catch (_) {
      // Хранилище может быть недоступно (тесты без плагина, ошибка диска) —
      // это лишь кэш, без него всё работает, просто медленнее.
      return null;
    }
  }

  Future<void> write(String address, GeoPoint point) async {
    _memory[address] = point;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyOf(address),
        '${point.latitude},${point.longitude}',
      );
    } catch (_) {
      // См. выше: кэш необязателен.
    }
  }

  String _keyOf(String address) => '$namespace:${address.toLowerCase()}';
}

/// Геокодер OpenStreetMap (Nominatim) — без ключей и регистрации.
///
/// Публичный сервис с жёсткой политикой: не чаще запроса в секунду и с
/// внятным User-Agent. Поэтому запросы выстроены в очередь (одна на всё
/// приложение), а найденное складывается в [GeocodeCache] — второй раз тот же
/// адрес в сеть не идёт.
///
/// Поиск ограничен Узбекистаном и смещён к Ташкенту: «Шофиркон 5» без этого
/// находится где угодно. Точность — до улицы: дом 42/5 сервис не различает,
/// но для навигатора этого достаточно, а водитель видит карту перед выездом.
class NominatimGeocoder implements AddressGeocoder {
  NominatimGeocoder({Dio? dio, GeocodeCache? cache})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              responseType: ResponseType.json,
              headers: const {
                // Требование политики использования: сервис должен понимать,
                // кто к нему ходит.
                'User-Agent': 'crm_millwater/1.0 (+https://crm.millwater.uz)',
                'Accept-Language': 'ru',
              },
            )),
        _cache = cache ?? GeocodeCache();

  final Dio _dio;
  final GeocodeCache _cache;

  static const _endpoint = 'https://nominatim.openstreetmap.org/search';

  /// Окно поиска: Ташкент с областью, «долгота,широта» по углам.
  static const _viewbox = '68.9,41.6,69.8,41.0';

  /// Не найденное за этот сеанс — чтобы не долбить сервис одним и тем же.
  final Set<String> _misses = {};

  @override
  Future<GeoPoint?> locate(String address) async {
    final query = address.trim();
    if (query.isEmpty || _misses.contains(query)) return null;

    final cached = await _cache.read(query);
    if (cached != null) return cached;

    // Сначала в границах Ташкента: одноимённые улицы есть и в области, а
    // заказчики почти всегда городские. Не нашлось — ищем по всей стране.
    final point = await _search(query, bounded: true) ??
        await _search(query, bounded: false);

    if (point == null) {
      _misses.add(query);
      return null;
    }
    await _cache.write(query, point);
    return point;
  }

  Future<GeoPoint?> _search(String query, {required bool bounded}) async {
    try {
      final response = await _throttled(() => _dio.get<dynamic>(
            _endpoint,
            queryParameters: {
              'q': query,
              'format': 'json',
              'limit': 1,
              'countrycodes': 'uz',
              'viewbox': _viewbox,
              'bounded': bounded ? 1 : 0,
            },
          ));
      return _parse(response.data);
    } catch (_) {
      // Нет сети, лимит, отказ сервиса — адрес просто останется текстовым.
      return null;
    }
  }

  static GeoPoint? _parse(Object? data) {
    if (data is! List || data.isEmpty) return null;
    final first = data.first;
    if (first is! Map) return null;

    // Через общий разбор: он и числа проверит, и рамку правдоподобия
    // применит — ту же, что для ссылок.
    final point = GeoLink.tryParse('${first['lat']},${first['lon']}');
    return point == null
        ? null
        : GeoPoint(
            latitude: point.latitude,
            longitude: point.longitude,
            source: GeoLinkSource.plain,
          );
  }

  // ---- Очередь запросов ----
  //
  // Одна на всё приложение: у сервиса ограничение по адресу, а не по объекту,
  // и десять точек маршрута, выпущенные разом, — верный способ получить бан.

  static Future<void> _queue = Future<void>.value();
  static DateTime _lastCall = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minGap = Duration(milliseconds: 1100);

  static Future<R> _throttled<R>(Future<R> Function() job) {
    final result = Completer<R>();
    _queue = _queue.then((_) async {
      final wait = _minGap - DateTime.now().difference(_lastCall);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      _lastCall = DateTime.now();
      try {
        result.complete(await job());
      } catch (error, stack) {
        // Ошибку отдаём вызывающему, но очередь не рвём: следующей точке
        // маршрута она не мешает.
        result.completeError(error, stack);
      }
    });
    return result.future;
  }
}

/// HTTP-геокодер Яндекса (`geocode-maps.yandex.ru/1.x/`) — по ключу сборки.
///
/// Точнее OSM на местных адресах и без ограничения в запрос в секунду.
/// Поиск смещён к Ташкенту (`ll` + `spn`): неформальные адреса вроде
/// «Шофиркон 5» без подсказки о городе находятся где угодно. Жёстко окном не
/// ограничиваем (`rspn` не ставим) — заказчик может быть и за городом.
class YandexGeocoder implements AddressGeocoder {
  YandexGeocoder({required this.apiKey, Dio? dio, GeocodeCache? cache})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
              responseType: ResponseType.json,
            )),
        _cache = cache ?? GeocodeCache(namespace: 'geocode-yandex');

  final String apiKey;
  final Dio _dio;
  final GeocodeCache _cache;

  final Set<String> _misses = {};

  static const _endpoint = 'https://geocode-maps.yandex.ru/1.x/';

  /// Центр Ташкента и размер окна поиска в градусах.
  static const _biasLongitude = 69.24;
  static const _biasLatitude = 41.31;
  static const _biasSpan = 0.6;

  @override
  Future<GeoPoint?> locate(String address) async {
    final query = address.trim();
    if (query.isEmpty || _misses.contains(query)) return null;

    final cached = await _cache.read(query);
    if (cached != null) return cached;

    try {
      final response = await _dio.get<dynamic>(
        _endpoint,
        queryParameters: {
          'apikey': apiKey,
          'geocode': query,
          'format': 'json',
          'results': 1,
          'lang': 'ru_RU',
          'll': '$_biasLongitude,$_biasLatitude',
          'spn': '$_biasSpan,$_biasSpan',
        },
      );
      final point = _parse(response.data);
      if (point == null) {
        _misses.add(query);
        return null;
      }
      await _cache.write(query, point);
      return point;
    } catch (_) {
      // Нет сети, кончилась квота, неверный ключ — адрес останется текстовым.
      return null;
    }
  }

  /// Достаёт точку из ответа: `Point.pos` — «долгота широта» через пробел.
  ///
  /// Порядок обратный привычному, как и во всех ссылках Яндекса; перепутав
  /// его, получим формально исправную точку в тысячах километров отсюда.
  static GeoPoint? _parse(Object? data) {
    if (data is! Map) return null;
    final collection = data['response']?['GeoObjectCollection'];
    final members = collection?['featureMember'];
    if (members is! List || members.isEmpty) return null;

    final pos = members.first?['GeoObject']?['Point']?['pos'];
    if (pos is! String) return null;

    final parts = pos.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;

    final point = GeoLink.tryParse('${parts[1]},${parts[0]}');
    return point == null
        ? null
        : GeoPoint(
            latitude: point.latitude,
            longitude: point.longitude,
            source: GeoLinkSource.yandex,
          );
  }
}

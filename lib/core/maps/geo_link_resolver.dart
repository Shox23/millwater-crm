import 'package:dio/dio.dart';

import 'geo_link.dart';

/// Что удалось вытащить из адреса заказчика.
class ResolvedAddress {
  const ResolvedAddress({this.point, this.searchText});

  /// Ничего полезного в адресе не нашлось.
  static const ResolvedAddress none = ResolvedAddress();

  /// Координаты, если они были в самой ссылке.
  final GeoPoint? point;

  /// Название места из ссылки — то, что человек искал, когда её отправлял.
  ///
  /// Короткая ссылка Google (`share.google/…`) ведёт **не на карту, а на
  /// поиск**: координат в цепочке нет ни одной, зато в конце стоит
  /// `q=IT+Park+Uzbekistan`. По этому названию точка и находится — искать по
  /// самой ссылке бессмысленно.
  final String? searchText;

  bool get isEmpty => point == null && searchText == null;
}

/// Разворачивает ссылки на карты: координаты, а если их нет — название места.
///
/// [GeoLink] разбирает только то, что видно в самой строке. Короткая ссылка
/// координат не содержит вовсе — они (или название) появляются после перехода
/// по редиректу. Менеджеры вставляют в поле адреса именно такие.
///
/// Своим `Dio`, а не общим клиентом приложения: у того выставлен `baseUrl`
/// нашего API и интерсептор авторизации — отправлять токен на чужой хост
/// нельзя ни при каких обстоятельствах.
class GeoLinkResolver {
  GeoLinkResolver({Dio? dio, this.maxHops = 5}) : _dio = dio ?? _defaultDio();

  final Dio _dio;

  /// Сколько редиректов проходим. Цепочка `share.google` → `google.com` →
  /// поиск укладывается в три, запас — на промежуточные.
  final int maxHops;

  /// Разобранные адреса за время жизни объекта: маршрут из десяти точек не
  /// должен десять раз ходить в сеть за одной и той же ссылкой.
  final Map<String, ResolvedAddress> _cache = {};

  static Dio _defaultDio() => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        // Редиректы проходим сами: нужен каждый промежуточный адрес, а не
        // только конечная страница — и координаты, и название места
        // встречаются в середине цепочки.
        followRedirects: false,
        maxRedirects: 0,
        responseType: ResponseType.plain,
        // 3xx для нас — нормальный ответ, а не ошибка.
        validateStatus: (code) => code != null && code < 400,
        headers: const {
          // Без внятного User-Agent короткие ссылки Google отдают заглушку.
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
                  'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
          'Accept-Language': 'ru,en;q=0.8',
        },
      ));

  /// Разбирает адрес заказчика.
  ///
  /// Сеть трогается только ради ссылки: обычный адрес и ссылка с координатами
  /// внутри разбираются на месте. Наружу исключения не выходят — любая осечка
  /// означает «ничего не нашли», а не поломку экрана.
  Future<ResolvedAddress> resolve(String address) async {
    final key = address.trim();
    if (key.isEmpty) return ResolvedAddress.none;

    final cached = _cache[key];
    if (cached != null) return cached;

    final direct = GeoLink.tryParse(key);
    if (direct != null) {
      return _remember(key, ResolvedAddress(point: direct));
    }

    final short = GeoLink.shortLinkIn(key);
    if (short == null) return _remember(key, ResolvedAddress.none);

    return _remember(key, await _follow(short));
  }

  /// Идёт по цепочке редиректов, забирая по дороге координаты или название.
  Future<ResolvedAddress> _follow(Uri start) async {
    var uri = start;
    // Идентификатор самой ссылки: он попадается в параметре `q` первого
    // редиректа и названием места не является.
    final idOfLink = start.pathSegments.isEmpty ? '' : start.pathSegments.last;
    String? searchText;

    for (var hop = 0; hop < maxHops; hop++) {
      final Response<dynamic> response;
      try {
        response = await _dio.getUri<dynamic>(uri);
      } catch (_) {
        // Нет сети, таймаут, отказ хоста — ничего не нашли, и это не повод
        // показывать водителю ошибку.
        break;
      }

      final location = response.headers.value('location');
      if (location == null || location.isEmpty) {
        final fromBody = _fromBody(response.data);
        if (fromBody != null) return ResolvedAddress(point: fromBody);
        break;
      }

      // Относительный `Location` тоже встречается — достраиваем от текущего.
      uri = uri.resolve(location);
      final point = GeoLink.tryParse(uri.toString());
      if (point != null) return ResolvedAddress(point: point);
      // Название с каждого шага перетирается следующим: в конце цепочки оно
      // самое осмысленное.
      searchText = _searchTextIn(uri, idOfLink) ?? searchText;
    }

    return searchText == null
        ? ResolvedAddress.none
        : ResolvedAddress(searchText: searchText);
  }

  /// Название места из ссылки: `?q=…`, `?text=…` или `/maps/place/<название>`.
  static String? _searchTextIn(Uri uri, String idOfLink) {
    for (final key in ['q', 'query', 'text', 'daddr']) {
      final value = uri.queryParameters[key]?.trim();
      if (value == null || value.isEmpty) continue;
      // Тот же случайный набор букв, что стоял в короткой ссылке, — это её
      // идентификатор, а не название.
      if (value == idOfLink) continue;
      return value;
    }

    final segments = uri.pathSegments;
    final placeAt = segments.indexOf('place');
    if (placeAt != -1 && placeAt + 1 < segments.length) {
      final name = segments[placeAt + 1].replaceAll('+', ' ').trim();
      if (name.isNotEmpty) return name;
    }
    return null;
  }

  /// Ищет координаты в теле страницы: пробует ссылки, которые в нём попались.
  ///
  /// Тело ограничено: страница карт весит мегабайты, а нужная ссылка стоит в
  /// начале — разбирать всё целиком значит тратить память и время впустую.
  GeoPoint? _fromBody(Object? data) {
    if (data == null) return null;
    final body = data.toString();
    final head =
        body.length > _maxBodyChars ? body.substring(0, _maxBodyChars) : body;

    var tried = 0;
    for (final match
        in RegExp(r'https?://[^"' r"'" r'\s\\<>]+').allMatches(head)) {
      if (tried++ >= _maxLinksInBody) break;
      final point = GeoLink.tryParse(match.group(0)!);
      if (point != null) return point;
    }
    return null;
  }

  ResolvedAddress _remember(String key, ResolvedAddress value) {
    _cache[key] = value;
    return value;
  }

  static const int _maxBodyChars = 200000;
  static const int _maxLinksInBody = 200;
}

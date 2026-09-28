import '../../data/models/route_models.dart';
import '../utils/visit_order.dart';
import 'address_geocoder.dart';
import 'geo_link.dart';
import 'geo_link_resolver.dart';
import 'map_route.dart';

/// Чем маршрут задан для Яндекс.Карт.
enum RouteBuildMode {
  /// Все точки — координаты. Такой маршрут открывает нативное приложение:
  /// геокодинг ему не нужен, и водитель сразу оказывается в навигаторе.
  coordinates,

  /// Часть точек осталась текстом. Приложение текстовые адреса в маршруте не
  /// принимает — их разбирает веб-версия, поэтому и открывается она.
  addresses,
}

/// Готовый к открытию маршрут и всё, что о нём стоит сказать водителю.
class RoutePlan {
  const RoutePlan({
    required this.route,
    required this.stops,
    required this.unplaced,
    required this.mode,
  });

  /// Пустой план: строить нечего.
  const RoutePlan.empty()
      : route = const RouteData(points: []),
        stops = const [],
        unplaced = const [],
        mode = RouteBuildMode.addresses;

  /// Точки в том виде, в каком уйдут в Яндекс.Карты.
  final RouteData route;

  /// Остановки, вошедшие в маршрут, в порядке объезда.
  final List<RouteStop> stops;

  /// Остановки, для которых координат найти не удалось.
  ///
  /// Из маршрута они не выбрасываются — уходят текстом, и маршрут целиком
  /// строится веб-версией. Но назвать их водителю надо: пока в адресе такого
  /// заказчика не появится точка с карты, приложение маршрут не построит.
  final List<RouteStop> unplaced;

  final RouteBuildMode mode;

  bool get isEmpty => route.points.isEmpty;
}

/// Собирает маршрут из остановок: что везти, в каком порядке и по каким
/// координатам.
///
/// Отдельно от экрана, потому что решений здесь три и каждое проверяемо:
/// какие точки ещё предстоит объехать, в каком они порядке и откуда взять
/// координаты каждой.
class RoutePlanner {
  RoutePlanner({GeoLinkResolver? resolver, AddressGeocoder? geocoder})
      : _resolver = resolver ?? GeoLinkResolver(),
        _geocoder = geocoder ?? AddressGeocoder.fromConfig();

  final GeoLinkResolver _resolver;
  final AddressGeocoder _geocoder;

  /// Точки, которые ещё предстоит объехать, в порядке объезда.
  ///
  /// Закрытые (доставленные и несостоявшиеся) отбрасываются: вести водителя
  /// через адреса, где он уже был, — это лишние километры и потерянное время.
  /// Порядок задаёт `sequence`; точки без него встают в конец, сохраняя
  /// исходный порядок ответа — сервер сортировки не делает вовсе.
  static List<RouteStop> pendingStops(List<RouteStop> stops) => inVisitOrder(
        [for (final stop in stops) if (stop.status.isOpen) stop],
        (stop) => stop.sequence,
      );

  /// Строит план: координаты остановок, порядок и стартовую точку.
  ///
  /// [start] — место водителя. Первой точкой оно нужно потому, что водитель
  /// не стоит у первого заказчика, и отрезок «где я сейчас → первая точка»
  /// иначе выпал бы из маршрута.
  Future<RoutePlan> plan(
    List<RouteStop> stops, {
    GeoPoint? start,
  }) async {
    final pending = pendingStops(stops);
    if (pending.isEmpty) return const RoutePlan.empty();

    // Разом, а не по очереди: у каждой точки может быть свой поход в сеть, и
    // десять остановок подряд — это десять задержек, которые водитель ждёт
    // перед открытием карт.
    final located = await Future.wait([for (final stop in pending) _locate(stop)]);

    final points = <RoutePoint>[];
    final unplaced = <RouteStop>[];

    for (final (index, stop) in pending.indexed) {
      final point = located[index];
      if (point == null) unplaced.add(stop);
      points.add(point ?? RoutePoint(address: stop.customerAddress));
    }

    // Смешанный маршрут приложению отдавать бессмысленно: текстовые точки оно
    // выбросит и построит его не туда — либо все точки координатами, либо
    // маршрут уходит в веб целиком.
    final mode = unplaced.isEmpty
        ? RouteBuildMode.coordinates
        : RouteBuildMode.addresses;

    return RoutePlan(
      route: RouteData(
        points: [
          if (start != null)
            RoutePoint(
              address: '',
              latitude: start.latitude,
              longitude: start.longitude,
            ),
          ...points,
        ],
        mode: MapRouteMode.auto,
      ),
      stops: pending,
      unplaced: unplaced,
      mode: mode,
    );
  }

  /// Координаты остановки: сначала серверные, потом ссылка в адресе, потом
  /// геокодер. `null` — точку поставить не по чему.
  Future<RoutePoint?> _locate(RouteStop stop) async {
    // Координаты сервера точнее всего: их фиксировал водитель на месте.
    if (stop.hasCoordinates) {
      return RoutePoint(
        address: stop.customerAddress,
        latitude: stop.customerLatitude,
        longitude: stop.customerLongitude,
      );
    }

    final address = stop.customerAddress.trim();
    if (address.isEmpty) return null;

    // Ссылка на карту в поле адреса — обычная практика менеджеров. Короткую
    // (`share.google/…`) резолвер разворачивает по редиректу: иногда там
    // координаты, иногда только название места.
    final resolved = await _resolver.resolve(address);
    if (resolved.point != null) return _pointOf(address, resolved.point!);

    // Искать по самой ссылке бессмысленно — ищем по названию из неё, а для
    // обычного адреса по нему самому.
    final query = resolved.searchText ?? address;
    final geocoded = await _geocoder.locate(query);
    return geocoded == null ? null : _pointOf(address, geocoded);
  }

  RoutePoint _pointOf(String address, GeoPoint point) => RoutePoint(
        address: address,
        latitude: point.latitude,
        longitude: point.longitude,
      );
}

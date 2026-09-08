import 'dart:typed_data';

import 'package:crm_millwater/core/maps/address_geocoder.dart';
import 'package:crm_millwater/core/maps/geo_link.dart';
import 'package:crm_millwater/core/maps/geo_link_resolver.dart';
import 'package:crm_millwater/core/maps/route_plan.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

RouteStop _stop(
  String name, {
  String? address,
  DeliveryStatus status = DeliveryStatus.pending,
  int? sequence,
  double? latitude,
  double? longitude,
}) =>
    RouteStop(
      id: 'stop-$name',
      customerId: 'c-$name',
      customerName: name,
      customerAddress: address ?? 'Адрес $name',
      customerPhone: '+998901234567',
      status: status,
      sequence: sequence,
      customerLatitude: latitude,
      customerLongitude: longitude,
    );

/// Геокодер, который знает ровно один адрес: по нему видно и что его зовут,
/// и что зовут только для текстовых точек.
class _FakeGeocoder implements AddressGeocoder {
  _FakeGeocoder([this.known = const {}]);

  final Map<String, GeoPoint> known;
  final List<String> asked = [];

  @override
  Future<GeoPoint?> locate(String address) async {
    asked.add(address);
    return known[address];
  }
}

/// Резолвер без сети: любой запрос наружу означал бы ошибку теста.
GeoLinkResolver _offlineResolver() {
  final dio = Dio()..httpClientAdapter = _DeadAdapter();
  return GeoLinkResolver(dio: dio);
}

/// Отвечает редиректами по заданной цепочке, дальше — пустой страницей.
class _RedirectAdapter implements HttpClientAdapter {
  _RedirectAdapter(this.hops);

  final Map<String, String> hops;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final next = hops[options.uri.toString()];
    if (next != null) {
      return ResponseBody.fromString('', 302, headers: {
        'location': [next],
      });
    }
    return ResponseBody.fromString('', 200);
  }
}

class _DeadAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      throw StateError('в этом тесте сеть трогать нечем: ${options.uri}');
}

const _point = GeoPoint(
  latitude: 41.311081,
  longitude: 69.240562,
  source: GeoLinkSource.yandex,
);

void main() {
  RoutePlanner planner({AddressGeocoder? geocoder}) => RoutePlanner(
        resolver: _offlineResolver(),
        geocoder: geocoder ?? const NoGeocoder(),
      );

  group('pendingStops', () {
    test('закрытые точки в маршрут не идут', () {
      final stops = [
        _stop('А', status: DeliveryStatus.delivered),
        _stop('Б'),
        _stop('В', status: DeliveryStatus.failed),
        _stop('Г', status: DeliveryStatus.onWay),
      ];

      // Вести водителя через адреса, где он уже был, — лишние километры.
      expect(
        RoutePlanner.pendingStops(stops).map((s) => s.customerName),
        ['Б', 'Г'],
      );
    });

    test('порядок задаёт sequence, а не порядок ответа', () {
      final stops = [
        _stop('третий', sequence: 3),
        _stop('первый', sequence: 1),
        _stop('второй', sequence: 2),
      ];

      // Сервер точки не сортирует вовсе — порядок объезда задаётся здесь.
      expect(
        RoutePlanner.pendingStops(stops).map((s) => s.customerName),
        ['первый', 'второй', 'третий'],
      );
    });

    test('точки без номера встают в конец, сохраняя порядок ответа', () {
      final stops = [
        _stop('без номера 1'),
        _stop('с номером', sequence: 5),
        _stop('без номера 2'),
      ];

      expect(
        RoutePlanner.pendingStops(stops).map((s) => s.customerName),
        ['с номером', 'без номера 1', 'без номера 2'],
      );
    });

    test('все точки закрыты — вести некуда', () {
      expect(
        RoutePlanner.pendingStops([_stop('А', status: DeliveryStatus.delivered)]),
        isEmpty,
      );
    });
  });

  group('plan', () {
    test('маршрут без точек пуст', () async {
      final plan = await planner().plan([]);
      expect(plan.isEmpty, isTrue);
    });

    test('координаты сервера превращают маршрут в координатный', () async {
      final plan = await planner().plan([
        _stop('А', latitude: 41.31, longitude: 69.24),
        _stop('Б', latitude: 41.32, longitude: 69.25),
      ]);

      // Ради этого всё и затевалось: такой маршрут открывает нативное
      // приложение — текстовую точку оно из маршрута выбрасывает молча.
      expect(plan.mode, RouteBuildMode.coordinates);
      expect(plan.route.hasOnlyCoordinates, isTrue);
      expect(plan.unplaced, isEmpty);
      expect(plan.route.rtext, '41.31,69.24~41.32,69.25');
    });

    test('ссылка в адресе разбирается без сети', () async {
      final plan = await planner().plan([
        _stop('А', address: 'https://yandex.uz/maps/?ll=69.240562,41.311081&z=17'),
        _stop('Б', latitude: 41.32, longitude: 69.25),
      ]);

      expect(plan.mode, RouteBuildMode.coordinates);
      expect(plan.route.rtext, '41.311081,69.240562~41.32,69.25');
    });

    test('текстовый адрес без геокодера остаётся текстом и назван водителю',
        () async {
      final plan = await planner().plan([
        _stop('А', address: 'Шофиркон 5'),
        _stop('Б', latitude: 41.32, longitude: 69.25),
      ]);

      // Смешанный маршрут приложению отдавать нельзя — уходит в веб целиком.
      expect(plan.mode, RouteBuildMode.addresses);
      expect(plan.unplaced.map((s) => s.customerName), ['А']);
      // При этом ни одна точка не теряется: веб-версия геокодит текст сама.
      expect(plan.route.rtext, 'Шофиркон 5~41.32,69.25');
    });

    test('геокодер добирает текстовые адреса и возвращает маршрут приложению',
        () async {
      final geocoder = _FakeGeocoder({'Шофиркон 5': _point});
      final plan = await planner(geocoder: geocoder).plan([
        _stop('А', address: 'Шофиркон 5'),
        _stop('Б', latitude: 41.32, longitude: 69.25),
      ]);

      expect(plan.mode, RouteBuildMode.coordinates);
      expect(plan.unplaced, isEmpty);
      expect(plan.route.rtext, '41.311081,69.240562~41.32,69.25');
      // Точку с координатами геокодеру не показывают: это лишний запрос и
      // лишний расход квоты.
      expect(geocoder.asked, ['Шофиркон 5']);
    });

    test('ссылка на поиск даёт название, по нему и ищем точку', () async {
      // Живой случай: `share.google` ведёт не на карту, а в поиск Google —
      // координат в цепочке нет, есть только название места.
      final adapter = _RedirectAdapter({
        'https://share.google/abc':
            'https://www.google.com/search?q=IT+Park+Uzbekistan',
      });
      final geocoder = _FakeGeocoder({'IT Park Uzbekistan': _point});

      final plan = await RoutePlanner(
        resolver: GeoLinkResolver(
          dio: Dio(BaseOptions(
            followRedirects: false,
            validateStatus: (code) => code != null && code < 400,
            responseType: ResponseType.plain,
          ))
            ..httpClientAdapter = adapter,
        ),
        geocoder: geocoder,
      ).plan([_stop('IT Park', address: 'https://share.google/abc')]);

      expect(plan.mode, RouteBuildMode.coordinates);
      // Геокодеру уходит название, а не сама ссылка: по «https://…» не
      // находится ничего.
      expect(geocoder.asked, ['IT Park Uzbekistan']);
      expect(plan.route.rtext, '~41.311081,69.240562');
    });

    test('старт водителя становится первой точкой', () async {
      final plan = await planner().plan(
        [_stop('А', latitude: 41.32, longitude: 69.25)],
        start: const GeoPoint(
          latitude: 41.30,
          longitude: 69.20,
          source: GeoLinkSource.plain,
        ),
      );

      // Водитель не стоит у первого заказчика — этот отрезок нужен тоже.
      expect(plan.route.rtext, '41.3,69.2~41.32,69.25');
      expect(plan.stops.map((s) => s.customerName), ['А']);
    });

    test('закрытые точки не попадают и в план', () async {
      final plan = await planner().plan([
        _stop('закрытая',
            status: DeliveryStatus.delivered, latitude: 41.1, longitude: 69.1),
        _stop('живая', latitude: 41.32, longitude: 69.25),
      ]);

      expect(plan.stops.map((s) => s.customerName), ['живая']);
      // Осталась одна точка: она становится финишем, «откуда» Яндекс.Карты
      // спрашивают сами — отсюда пустой первый элемент.
      expect(plan.route.rtext, '~41.32,69.25');
    });
  });
}

import 'package:crm_millwater/core/maps/map_route.dart';
import 'package:crm_millwater/core/maps/yandex_route_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

/// Записывает вызовы вместо обращения к ОС.
class _FakeLauncher {
  _FakeLauncher({this.appInstalled = false, this.failModes = const {}});

  /// Ответ `canLaunchUrl` для `yandexmaps://`.
  final bool appInstalled;

  /// Режимы, в которых `launchUrl` не срабатывает: значение — бросить
  /// исключение (true) или вернуть false.
  final Map<LaunchMode, bool> failModes;

  final List<Uri> probed = [];
  final List<(Uri, LaunchMode)> opened = [];

  Uri? get lastUrl => opened.isEmpty ? null : opened.last.$1;

  Future<bool> canLaunch(Uri url) async {
    probed.add(url);
    return appInstalled;
  }

  Future<bool> launch(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async {
    opened.add((url, mode));
    final throws = failModes[mode];
    if (throws == true) {
      throw PlatformException(code: 'LAUNCH_ERROR');
    }
    return throws == null;
  }

  YandexRouteLauncher get service =>
      YandexRouteLauncher(canLaunch: canLaunch, launch: launch);
}

RoutePoint _addr(String address) => RoutePoint(address: address);

void main() {
  group('RoutePoint.toRtextValue', () {
    test('координаты имеют приоритет над адресом', () {
      const point =
          RoutePoint(address: 'Москва', latitude: 55.75, longitude: 37.61);
      expect(point.hasCoordinates, isTrue);
      expect(point.toRtextValue(), '55.75,37.61');
    });

    test('~ и лишние пробелы вычищаются из адреса', () {
      expect(_addr('  Москва,  ул.~Тверская,   1 ').toRtextValue(),
          'Москва, ул. Тверская, 1');
    });

    test('без обеих координат точка остаётся текстовой', () {
      const point = RoutePoint(address: 'Москва', latitude: 55.75);
      expect(point.hasCoordinates, isFalse);
      expect(point.toRtextValue(), 'Москва');
    });
  });

  group('RouteData.validate', () {
    test('одной точки достаточно — она станет финишем', () {
      final route = RouteData(points: [_addr('Москва')]);
      expect(route.validate(), isNull);
      expect(route.isSingleStop, isTrue);
      // Пустой старт: «откуда» Яндекс.Карты подставят сами.
      expect(route.rtext, '~Москва');
    });

    test('без точек строить нечего', () {
      expect(const RouteData(points: []).validate(), isA<RouteHasNoPoints>());
    });

    test('у двух точек порядок сохраняется без пустого старта', () {
      final route = RouteData(points: [_addr('Москва'), _addr('Тверская 1')]);
      expect(route.isSingleStop, isFalse);
      expect(route.rtext, 'Москва~Тверская 1');
    });

    test('пустой адрес назван по номеру точки', () {
      final route = RouteData(points: [_addr('Москва'), _addr('   ')]);
      final issue = route.validate();
      expect(issue, isA<RoutePointWithoutAddress>());
      expect((issue as RoutePointWithoutAddress).number, 2);
    });

    test('точка с координатами не требует адреса', () {
      const route = RouteData(points: [
        RoutePoint(address: '', latitude: 55.75, longitude: 37.61),
        RoutePoint(address: '', latitude: 55.76, longitude: 37.64),
      ]);
      expect(route.validate(), isNull);
    });
  });

  group('RoutePoint.fromCustomer', () {
    // Ташкент; ссылка Яндекса несёт координаты в обратном порядке.
    const link = 'https://yandex.uz/maps/?ll=69.240562,41.311081&z=17';

    test('ссылка в поле адреса становится координатами', () {
      final point = RoutePoint.fromCustomer(address: link);

      // Без разбора эта строка ушла бы в rtext текстом, и геокодер искал бы
      // «https://…» — то есть не нашёл бы ничего.
      expect(point.hasCoordinates, isTrue);
      expect(point.toRtextValue(), '41.311081,69.240562');
    });

    test('обычный адрес остаётся текстом', () {
      final point = RoutePoint.fromCustomer(address: 'Чиланзар, 12 квартал');

      expect(point.hasCoordinates, isFalse);
      expect(point.toRtextValue(), 'Чиланзар, 12 квартал');
    });

    test('координаты сервера важнее разобранных из адреса', () {
      final point = RoutePoint.fromCustomer(
        address: link,
        latitude: 41.5,
        longitude: 69.5,
      );

      // Адрес правил человек, а координаты фиксировал водитель на месте.
      expect(point.toRtextValue(), '41.5,69.5');
    });

    test('нераспознанная ссылка ведёт себя как сегодня', () {
      // Короткую ссылку разбирает сервер; здесь она просто остаётся текстом.
      const short = 'https://maps.app.goo.gl/aBcDeFgH';
      final point = RoutePoint.fromCustomer(address: short);

      expect(point.hasCoordinates, isFalse);
      expect(point.toRtextValue(), short);
    });

    test('маршрут из адресов-ссылок открывает нативное приложение', () async {
      final fake = _FakeLauncher(appInstalled: true);
      final result = await fake.service.openRoute(RouteData(points: [
        RoutePoint.fromCustomer(address: link),
        RoutePoint.fromCustomer(
          address: 'Мирабад https://yandex.uz/maps/?ll=69.28,41.29&z=17',
        ),
      ]));

      expect(result.isSuccess, isTrue);
      // Ради этого разбор и нужен: у всех точек есть координаты, геокодинг
      // не участвует, маршрут уходит в Яндекс.Карты, а не в браузер.
      expect(fake.opened.single.$1.scheme, 'yandexmaps');
      expect(fake.opened.single.$2, LaunchMode.externalApplication);
    });
  });

  group('openRoute — веб-версия', () {
    test('текстовые адреса уходят наружу с rtt=auto', () async {
      final fake = _FakeLauncher();
      final result = await fake.service.openRoute(
        RouteData(points: [_addr('Москва'), _addr('Тверская 1')]),
      );

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      // Текстовые адреса нативному приложению не предлагаются.
      expect(fake.probed, isEmpty);
      // Наружу, а не во встроенный браузер: по карте внутри приложения не
      // поедешь, водителю нужен навигатор.
      expect(fake.opened.single.$2, LaunchMode.externalApplication);

      final url = fake.lastUrl!;
      expect(url.scheme, 'https');
      expect(url.host, 'yandex.ru');
      expect(url.path, '/maps/');
      expect(url.queryParameters['rtext'], 'Москва~Тверская 1');
      expect(url.queryParameters['rtt'], 'auto');
    });

    test('порядок трёх и более точек сохраняется', () async {
      final fake = _FakeLauncher();
      await fake.service.openRoute(RouteData(points: [
        const RoutePoint(address: 'Старт', latitude: 55.75, longitude: 37.61),
        _addr('Москва, Тверская 1'),
        _addr('Финиш'),
      ]));

      expect(fake.lastUrl!.queryParameters['rtext'],
          '55.75,37.61~Москва, Тверская 1~Финиш');
    });

    test('пробелы и кириллица кодируются, а не ломают ссылку', () async {
      final fake = _FakeLauncher();
      await fake.service.openRoute(RouteData(
        points: [_addr('Москва, ул. Тверская, 1'), _addr('Москва, Арбат 2')],
      ));

      final url = fake.lastUrl!;
      // В сыром виде — процентное кодирование UTF-8 и `+` вместо пробела.
      expect(url.toString(), isNot(contains(' ')));
      expect(url.query, contains('%D0%9C'));
      // А после разбора — исходный текст.
      expect(url.queryParameters['rtext'],
          'Москва, ул. Тверская, 1~Москва, Арбат 2');
    });

    test('& и + внутри адреса не создают лишних параметров', () async {
      final fake = _FakeLauncher();
      await fake.service.openRoute(RouteData(
        points: [_addr('Дом 1 & 2'), _addr('Корпус A+B?rtt=pd')],
      ));

      final url = fake.lastUrl!;
      expect(url.queryParameters.keys, ['rtext', 'rtt']);
      expect(url.queryParameters['rtext'], 'Дом 1 & 2~Корпус A+B?rtt=pd');
      // Тип маршрута берётся из модели, а не из подставленного текста.
      expect(url.queryParameters['rtt'], 'auto');
      expect(url.query, contains('%26'));
      expect(url.query, contains('%2B'));
    });

    test('смена типа маршрута меняет rtt', () async {
      for (final mode in MapRouteMode.values) {
        final fake = _FakeLauncher();
        await fake.service.openRoute(RouteData(
          points: [_addr('А'), _addr('Б')],
          mode: mode,
        ));
        expect(fake.lastUrl!.queryParameters['rtt'], mode.code);
      }
      expect(MapRouteMode.auto.code, 'auto');
      expect(MapRouteMode.transit.code, 'mt');
      expect(MapRouteMode.pedestrian.code, 'pd');
      expect(MapRouteMode.bicycle.code, 'bc');
    });
  });

  group('openRoute — нативное приложение', () {
    const coords = RouteData(points: [
      RoutePoint(address: 'Старт', latitude: 55.75, longitude: 37.61),
      RoutePoint(address: 'Финиш', latitude: 55.76, longitude: 37.64),
    ]);

    test('все точки с координатами уходят в deeplink', () async {
      final fake = _FakeLauncher(appInstalled: true);
      final result = await fake.service.openRoute(coords);

      expect(result.isSuccess, isTrue);
      expect(fake.probed.single.scheme, 'yandexmaps');

      final (url, mode) = fake.opened.single;
      expect(mode, LaunchMode.externalApplication);
      expect(url.scheme, 'yandexmaps');
      expect(url.host, 'maps.yandex.ru');
      expect(url.queryParameters['rtext'], '55.75,37.61~55.76,37.64');
      expect(url.queryParameters['rtt'], 'auto');
    });

    test('приложение не установлено — маршрут всё равно уходит наружу',
        () async {
      final fake = _FakeLauncher();
      final result = await fake.service.openRoute(coords);

      expect(result.isSuccess, isTrue, reason: 'пользователь ошибки не видит');
      expect(fake.opened.single.$1.scheme, 'https');
      expect(fake.opened.single.$2, LaunchMode.externalApplication);
    });

    test('внешним запуском открыть нечем — дальше встроенного браузера не идём',
        () async {
      final fake = _FakeLauncher(
        appInstalled: true,
        failModes: {LaunchMode.externalApplication: false},
      );
      final result = await fake.service.openRoute(coords);

      // Deeplink, затем веб наружу — и всё. Встроенный браузер открывается
      // поверх приложения, а по карте внутри веб-вида не поедешь: водителю
      // он не заменяет навигатор.
      expect(fake.opened.map((e) => e.$1.scheme), ['yandexmaps', 'https']);
      expect(fake.opened.map((e) => e.$2),
          everyElement(LaunchMode.externalApplication));
      expect(result.isSuccess, isFalse);
      expect(result.error, isA<RouteOpenFailed>());
    });
  });

  group('openRoute — сбои', () {
    final route = RouteData(points: [_addr('А'), _addr('Б')]);

    test('PlatformException из внешнего запуска не роняет экран', () async {
      final fake =
          _FakeLauncher(failModes: {LaunchMode.externalApplication: true});
      final result = await fake.service.openRoute(route);

      // Исключение url_launcher превращается в понятную ошибку, а не в
      // падение: маршрут не открылся, но карточка маршрута жива.
      expect(fake.opened.map((e) => e.$2), [LaunchMode.externalApplication]);
      expect(result.error, isA<RouteOpenFailed>());
    });

    test('исключение из canLaunchUrl не роняет открытие', () async {
      final service = YandexRouteLauncher(
        canLaunch: (_) async => throw PlatformException(code: 'X'),
        launch: (url, {mode = LaunchMode.platformDefault}) async => true,
      );
      final result = await service.openRoute(const RouteData(points: [
        RoutePoint(address: 'Старт', latitude: 55.75, longitude: 37.61),
        RoutePoint(address: 'Финиш', latitude: 55.76, longitude: 37.64),
      ]));

      expect(result.isSuccess, isTrue);
    });

    test('когда не сработало ничего — понятная ошибка', () async {
      final fake = _FakeLauncher(failModes: {
        LaunchMode.externalApplication: false,
      });
      final result = await fake.service.openRoute(route);

      expect(result.isSuccess, isFalse);
      expect(result.error, isA<RouteOpenFailed>());
    });

    test('невалидный маршрут ничего не открывает', () async {
      final fake = _FakeLauncher(appInstalled: true);
      final result = await fake.service.openRoute(const RouteData(points: []));

      expect(result.isSuccess, isFalse);
      expect(result.error, isA<RouteHasNoPoints>());
      expect(fake.probed, isEmpty);
      expect(fake.opened, isEmpty);
    });

    test('единственная точка открывается с пустым стартом', () async {
      final fake = _FakeLauncher();
      final result =
          await fake.service.openRoute(RouteData(points: [_addr('Москва')]));

      expect(result.isSuccess, isTrue);
      expect(fake.lastUrl!.queryParameters['rtext'], '~Москва');
      expect(fake.lastUrl!.queryParameters['rtt'], 'auto');
    });

    test('единственная точка с координатами уходит в приложение', () async {
      final fake = _FakeLauncher(appInstalled: true);
      final result = await fake.service.openRoute(
        const RouteData(points: [
          RoutePoint(address: 'Дом', latitude: 55.75, longitude: 37.61),
        ]),
      );

      expect(result.isSuccess, isTrue);
      expect(fake.lastUrl!.scheme, 'yandexmaps');
      expect(fake.lastUrl!.queryParameters['rtext'], '~55.75,37.61');
    });
  });
}

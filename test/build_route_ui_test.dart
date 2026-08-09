import 'dart:async';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/location/device_location.dart';
import 'package:crm_millwater/core/maps/yandex_route_launcher.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/build_route_section.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

RouteStop _stop(String address) => RouteStop(
      id: address,
      customerId: 'c-$address',
      customerName: 'Заказчик',
      customerAddress: address,
      customerPhone: '+998901234567',
      status: DeliveryStatus.pending,
    );

Position _position(double lat, double lon) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// Геолокация с заданным исходом и счётчиком обращений: по нему видно,
/// что у водителя не спрашивают разрешение там, где старт уже известен.
class _FakeLocation {
  _FakeLocation({this.granted = true});

  final bool granted;
  int calls = 0;

  DeviceLocationService get service => DeviceLocationService(
        isServiceEnabled: () async {
          calls++;
          return granted;
        },
        checkPermission: () async => granted
            ? LocationPermission.whileInUse
            : LocationPermission.deniedForever,
        requestPermission: () async => granted
            ? LocationPermission.whileInUse
            : LocationPermission.deniedForever,
        readPosition: () async => _position(41.31, 69.24),
      );
}

/// Собирает ссылки, которые блок отдал бы операционной системе.
class _RecordingLauncher {
  final List<Uri> opened = [];

  /// Открытие держится до [release] — так видно индикатор загрузки.
  final gate = Completer<void>();
  var _blocking = false;

  YandexRouteLauncher service({bool blocking = false}) {
    _blocking = blocking;
    return YandexRouteLauncher(
      canLaunch: (_) async => false,
      launch: (url, {mode = LaunchMode.platformDefault}) async {
        opened.add(url);
        if (_blocking) await gate.future;
        return true;
      },
    );
  }

  void release() => gate.complete();
}

void main() {
  Future<void> pumpSection(
    WidgetTester tester,
    List<RouteStop> stops,
    YandexRouteLauncher launcher, {
    _FakeLocation? location,
  }) async {
    location ??= _FakeLocation();
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
            // Строки интерфейса берутся из локали: тесты идут на русской.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuildRouteSection(
              stops: stops,
              launcher: launcher,
              location: location.service,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('кнопка открывает веб-версию с точками маршрута', (tester) async {
    final recorder = _RecordingLauncher();
    await pumpSection(
      tester,
      [_stop('Москва, ул. Тверская, 1'), _stop('Москва, Арбат 2')],
      recorder.service(),
    );

    await tester.tap(find.text('Построить маршрут'));
    await tester.pump();

    expect(recorder.opened, hasLength(1));
    final url = recorder.opened.single;
    expect(url.host, 'yandex.ru');
    // Первая точка — место водителя, дальше остановки по порядку.
    expect(url.queryParameters['rtext'],
        '41.31,69.24~Москва, ул. Тверская, 1~Москва, Арбат 2');
    expect(url.queryParameters['rtt'], 'auto');
  });

  testWidgets('выбора транспорта нет — маршрут всегда автомобильный',
      (tester) async {
    final recorder = _RecordingLauncher();
    await pumpSection(
      tester,
      [_stop('А'), _stop('Б')],
      recorder.service(),
    );

    // Блок показывает только кнопку: доставку возят машиной.
    for (final label in ['Авто', 'Транспорт', 'Пешком', 'Велосипед']) {
      expect(find.text(label), findsNothing, reason: 'селектор режима убран');
    }

    await tester.tap(find.text('Построить маршрут'));
    await tester.pump();

    expect(recorder.opened.single.queryParameters['rtt'], 'auto');
  });

  testWidgets('одна точка строится от текущего места', (tester) async {
    final recorder = _RecordingLauncher();
    final location = _FakeLocation();
    await pumpSection(
      tester,
      [_stop('Москва')],
      recorder.service(),
      location: location,
    );

    expect(
      find.textContaining('от вашего текущего места'),
      findsOneWidget,
      reason: 'водителю объясняют, откуда поведёт маршрут',
    );

    await tester.tap(find.text('Построить маршрут'));
    await tester.pump();

    // Старт — замер GPS, финиш — адрес заказчика.
    expect(location.calls, 1);
    expect(recorder.opened.single.queryParameters['rtext'],
        '41.31,69.24~Москва');
  });

  testWidgets('без доступа к геолокации точка уходит с пустым стартом',
      (tester) async {
    final recorder = _RecordingLauncher();
    final location = _FakeLocation(granted: false);
    await pumpSection(
      tester,
      [_stop('Москва')],
      recorder.service(),
      location: location,
    );

    await tester.tap(find.text('Построить маршрут'));
    await tester.pump();

    // Маршрут всё равно открывается — «откуда» спросят сами Яндекс.Карты.
    expect(recorder.opened.single.queryParameters['rtext'], '~Москва');
  });

  testWidgets('несколько точек тоже строятся от текущего места',
      (tester) async {
    final recorder = _RecordingLauncher();
    final location = _FakeLocation();
    await pumpSection(
      tester,
      [_stop('Москва'), _stop('Тверская 1')],
      recorder.service(),
      location: location,
    );

    await tester.tap(find.text('Построить маршрут'));
    await tester.pump();

    // Водитель не стоит у первого заказчика — этот отрезок пути нужен тоже.
    expect(location.calls, 1);
    expect(recorder.opened.single.queryParameters['rtext'],
        '41.31,69.24~Москва~Тверская 1');
  });

  testWidgets('без доступа к геолокации маршрут идёт по одним остановкам',
      (tester) async {
    final recorder = _RecordingLauncher();
    await pumpSection(
      tester,
      [_stop('Москва'), _stop('Тверская 1')],
      recorder.service(),
      location: _FakeLocation(granted: false),
    );

    await tester.tap(find.text('Построить маршрут'));
    await tester.pump();

    expect(recorder.opened.single.queryParameters['rtext'],
        'Москва~Тверская 1');
  });

  testWidgets('без точек кнопка неактивна, ничего не открывается',
      (tester) async {
    final recorder = _RecordingLauncher();
    await pumpSection(tester, [], recorder.service());

    expect(find.text('Для маршрута нужна хотя бы одна точка.'), findsOneWidget);
    await tester.tap(find.text('Построить маршрут'));
    await tester.pump();

    expect(recorder.opened, isEmpty);
  });

  testWidgets('пустой адрес блокирует построение', (tester) async {
    final recorder = _RecordingLauncher();
    await pumpSection(
      tester,
      [_stop('Москва'), _stop('   ')],
      recorder.service(),
    );

    expect(find.text('У точки 2 не заполнен адрес.'), findsOneWidget);
    await tester.tap(find.text('Построить маршрут'));
    await tester.pump();

    expect(recorder.opened, isEmpty);
  });

  testWidgets('на время открытия показывается индикатор', (tester) async {
    final recorder = _RecordingLauncher();
    await pumpSection(
      tester,
      [_stop('А'), _stop('Б')],
      recorder.service(blocking: true),
    );

    await tester.tap(find.text('Построить маршрут'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Построить маршрут'), findsNothing);

    recorder.release();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Построить маршрут'), findsOneWidget);
  });

  testWidgets('ошибка открытия показывается снекбаром', (tester) async {
    final failing = YandexRouteLauncher(
      canLaunch: (_) async => false,
      launch: (url, {mode = LaunchMode.platformDefault}) async => false,
    );
    await pumpSection(tester, [_stop('А'), _stop('Б')], failing);

    await tester.tap(find.text('Построить маршрут'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Не удалось открыть Яндекс.Карты'), findsOneWidget);
  });
}

import 'dart:async';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/location/device_location.dart';
import 'package:crm_millwater/core/maps/map_route.dart';
import 'package:crm_millwater/core/maps/yandex_route_launcher.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/presentation/delivery_completion_page.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/build_route_section.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Сервис геолокации с заданным поведением каждого шага.
DeviceLocationService _location({
  bool serviceEnabled = true,
  LocationPermission permission = LocationPermission.whileInUse,
  LocationPermission? afterRequest,
  Position? position,
  Object? throws,
}) {
  return DeviceLocationService(
    isServiceEnabled: () async => serviceEnabled,
    checkPermission: () async => permission,
    requestPermission: () async => afterRequest ?? permission,
    readPosition: () async {
      if (throws != null) throw throws;
      return position ?? _position(41.31, 69.24);
    },
  );
}

RouteStop _stop({double? lat, double? lon}) => RouteStop(
      id: 'stop-1',
      customerId: 'c-1',
      customerName: 'Заказчик',
      customerAddress: 'Ташкент, Чиланзар 12',
      customerPhone: '+998901234567',
      status: DeliveryStatus.pending,
      customerLatitude: lat,
      customerLongitude: lon,
    );

/// Запоминает координаты, дошедшие до репозитория.
class _RecordingDriverRepository extends MockDriverRepository {
  double? latitude;
  double? longitude;

  @override
  Future<void> completeDelivery({
    required String stopId,
    required int capsules,
    required int amount,
    required int bottleBalance,
    required PaymentMethod method,
    String? photoPath,
    String? idempotencyKey,
    double? latitude,
    double? longitude,
  }) async {
    this.latitude = latitude;
    this.longitude = longitude;
    return super.completeDelivery(
      stopId: stopId,
      capsules: capsules,
      amount: amount,
      bottleBalance: bottleBalance,
      method: method,
      photoPath: photoPath,
      idempotencyKey: idempotencyKey,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

void main() {
  group('DeviceLocationService', () {
    test('координаты возвращаются при выданном разрешении', () async {
      final fix = await _location(position: _position(41.31, 69.24)).currentFix();

      expect(fix.isSuccess, isTrue);
      expect(fix.latitude, 41.31);
      expect(fix.longitude, 69.24);
    });

    test('выключенная служба — отказ без запроса разрешения', () async {
      var asked = false;
      final service = DeviceLocationService(
        isServiceEnabled: () async => false,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async {
          asked = true;
          return LocationPermission.whileInUse;
        },
        readPosition: () async => _position(1, 2),
      );

      final fix = await service.currentFix();

      expect(fix.isSuccess, isFalse);
      expect(fix.failure, LocationFailure.serviceDisabled);
      expect(asked, isFalse);
    });

    test('разрешение спрашивается один раз и выдача принимается', () async {
      final fix = await _location(
        permission: LocationPermission.denied,
        afterRequest: LocationPermission.whileInUse,
      ).currentFix();

      expect(fix.isSuccess, isTrue);
    });

    test('отказ навсегда объясняется отдельно', () async {
      final fix =
          await _location(permission: LocationPermission.deniedForever)
              .currentFix();

      expect(fix.failure, LocationFailure.deniedForever);
    });

    test('обычный отказ — короткое сообщение', () async {
      final fix = await _location(
        permission: LocationPermission.denied,
        afterRequest: LocationPermission.denied,
      ).currentFix();

      expect(fix.failure, LocationFailure.denied);
    });

    test('таймаут замера не выходит наружу исключением', () async {
      final fix =
          await _location(throws: TimeoutException('нет сигнала')).currentFix();

      expect(fix.isSuccess, isFalse);
      expect(fix.failure, LocationFailure.unknown);
    });
  });

  group('Завершение доставки фиксирует точку', () {
    Future<void> pumpPage(
      WidgetTester tester,
      DriverRepository repo, {
      DeviceLocationService? location,
    }) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RepositoryProvider<DriverRepository>.value(
          value: repo,
          child: MaterialApp(
            // Строки интерфейса берутся из локали: тесты идут на русской.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            theme: AppTheme.light(),
            home: DeliveryCompletionPage(stop: _stop(), location: location),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('снятые координаты уходят в репозиторий', (tester) async {
      final repo = _RecordingDriverRepository();
      await pumpPage(tester, repo,
          location: _location(position: _position(41.31, 69.24)));
      await tester.pump();

      expect(find.text('Точка зафиксирована'), findsOneWidget);
      expect(find.text('41.31, 69.24'), findsOneWidget);

      await tester.tap(find.text('Завершить'));
      await tester.pumpAndSettle();

      expect(repo.latitude, 41.31);
      expect(repo.longitude, 69.24);
    });

    testWidgets('отказ в геолокации не мешает завершить доставку',
        (tester) async {
      final repo = _RecordingDriverRepository();
      await pumpPage(tester, repo,
          location: _location(permission: LocationPermission.deniedForever));
      await tester.pump();

      expect(find.text('Точка не зафиксирована'), findsOneWidget);
      expect(find.textContaining('Доставку можно завершить и так'),
          findsOneWidget);

      await tester.tap(find.text('Завершить'));
      await tester.pumpAndSettle();

      // Доставка проведена, координат просто нет.
      expect(repo.latitude, isNull);
      expect(repo.longitude, isNull);
    });

    testWidgets('с выключенной фиксацией блок не показывается и GPS не трогаем',
        (tester) async {
      final repo = _RecordingDriverRepository();
      await pumpPage(tester, repo);
      await tester.pump();

      expect(find.text('КООРДИНАТЫ ТОЧКИ'), findsNothing);

      await tester.tap(find.text('Завершить'));
      await tester.pumpAndSettle();

      expect(repo.latitude, isNull);
    });
  });

  group('Накопленные координаты меняют способ построения маршрута', () {
    testWidgets('точки с координатами уходят в нативное приложение',
        (tester) async {
      final opened = <(Uri, LaunchMode)>[];
      final launcher = YandexRouteLauncher(
        canLaunch: (_) async => true,
        launch: (url, {mode = LaunchMode.platformDefault}) async {
          opened.add((url, mode));
          return true;
        },
      );

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
            body: BuildRouteSection(
              stops: [
                _stop(lat: 41.31, lon: 69.24),
                _stop(lat: 41.29, lon: 69.20),
              ],
              launcher: launcher,
              // Место водителя отличается от точек маршрута — так видно,
              // что оно встаёт в начало, а не дублирует первую остановку.
              location: _location(position: _position(41.20, 69.10)),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Построить маршрут'));
      await tester.pump();

      final (url, mode) = opened.single;
      expect(url.scheme, 'yandexmaps');
      expect(mode, LaunchMode.externalApplication);
      expect(url.queryParameters['rtext'],
          '41.2,69.1~41.31,69.24~41.29,69.2');
    });

    testWidgets('пока покрыта не вся точка — маршрут идёт через веб',
        (tester) async {
      final opened = <Uri>[];
      final launcher = YandexRouteLauncher(
        canLaunch: (_) async => true,
        launch: (url, {mode = LaunchMode.platformDefault}) async {
          opened.add(url);
          return true;
        },
      );

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
            body: BuildRouteSection(
              stops: [_stop(lat: 41.31, lon: 69.24), _stop()],
              launcher: launcher,
              location: _location(position: _position(41.20, 69.10)),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Построить маршрут'));
      await tester.pump();

      // Смешанный список: координаты и адрес в одном rtext понимает только веб.
      expect(opened.single.scheme, 'https');
      expect(opened.single.queryParameters['rtext'],
          '41.2,69.1~41.31,69.24~Ташкент, Чиланзар 12');
    });
  });

  test('RouteStop разбирает координаты из JSON', () {
    final stop = RouteStop.fromJson({
      'id': 's1',
      'customer_id': 'c1',
      'status': 'pending',
      // Целое приходит из JSON как int — `as double?` здесь упал бы.
      'customer_latitude': 41,
      'customer_longitude': 69.24,
    });

    expect(stop.hasCoordinates, isTrue);
    expect(stop.customerLatitude, 41.0);
    expect(stop.customerLongitude, 69.24);
  });

  test('без полей в ответе координат нет и точка остаётся текстовой', () {
    final stop = RouteStop.fromJson({
      'id': 's1',
      'customer_id': 'c1',
      'status': 'pending',
      'customer_address': 'Ташкент, Чиланзар 12',
    });

    expect(stop.hasCoordinates, isFalse);
    expect(
      RoutePoint(
        address: stop.customerAddress,
        latitude: stop.customerLatitude,
        longitude: stop.customerLongitude,
      ).toRtextValue(),
      'Ташкент, Чиланзар 12',
    );
  });
}

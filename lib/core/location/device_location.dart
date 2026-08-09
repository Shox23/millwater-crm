import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Включена ли служба геолокации на устройстве (`isLocationServiceEnabled`).
typedef ServiceEnabledCheck = Future<bool> Function();

/// Проверка или запрос разрешения (`checkPermission` / `requestPermission`).
typedef PermissionCheck = Future<LocationPermission> Function();

/// Снятие текущей позиции (`getCurrentPosition`).
typedef PositionReader = Future<Position> Function();

/// Почему координаты не получены. Текст подбирает интерфейс: сервис про
/// язык не знает и знать не должен.
enum LocationFailure {
  /// Служба геолокации выключена в системе.
  serviceDisabled,

  /// Доступ запрещён навсегда — чинится только в настройках телефона.
  deniedForever,

  /// Доступа нет (разрешение не выдано).
  denied,

  /// Таймаут, ошибка плагина и всё остальное.
  unknown,
}

/// Координаты устройства или причина, по которой их не получили.
class LocationFix extends Equatable {
  const LocationFix.success({
    required double this.latitude,
    required double this.longitude,
  }) : failure = null;

  const LocationFix.failure(LocationFailure this.failure)
      : latitude = null,
        longitude = null;

  final double? latitude;
  final double? longitude;

  /// Причина отказа; null — координаты получены.
  final LocationFailure? failure;

  bool get isSuccess => failure == null;

  @override
  List<Object?> get props => [latitude, longitude, failure];
}

/// Определяет, где физически находится телефон.
///
/// Нужен, чтобы водитель зафиксировал точку в момент доставки: адрес
/// заказчика — текст, а построение маршрута в нативных Яндекс.Картах
/// требует чисел. Геокодера в приложении нет и не планируется.
///
/// Наружу исключения не выходят: отказ в разрешении, выключенный GPS и
/// таймаут одинаково возвращаются как [LocationFix.failure] с кодом причины.
/// Зависимости принимаются конструктором — в тестах подменяются функциями.
class DeviceLocationService {
  // Поля заполняются инициализатором, а не `this.`-параметрами: именованный
  // параметр в Dart не может начинаться с подчёркивания.
  // ignore_for_file: prefer_initializing_formals
  const DeviceLocationService({
    ServiceEnabledCheck isServiceEnabled = Geolocator.isLocationServiceEnabled,
    PermissionCheck checkPermission = Geolocator.checkPermission,
    PermissionCheck requestPermission = Geolocator.requestPermission,
    PositionReader readPosition = _defaultPositionReader,
  })  : _isServiceEnabled = isServiceEnabled,
        _checkPermission = checkPermission,
        _requestPermission = requestPermission,
        _readPosition = readPosition;

  final ServiceEnabledCheck _isServiceEnabled;
  final PermissionCheck _checkPermission;
  final PermissionCheck _requestPermission;
  final PositionReader _readPosition;

  /// Снимает текущие координаты.
  ///
  /// Порядок действий:
  /// 1. Служба геолокации выключена — сразу отказ, разрешение не спрашиваем.
  /// 2. Разрешения нет — запрашиваем один раз; `deniedForever` отделяем,
  ///    потому что чинится оно только в настройках системы.
  /// 3. Снимаем позицию — с точностью и таймаутом из [_defaultPositionReader].
  Future<LocationFix> currentFix() async {
    try {
      if (!await _isServiceEnabled()) {
        return const LocationFix.failure(LocationFailure.serviceDisabled);
      }

      var permission = await _checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationFix.failure(LocationFailure.deniedForever);
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return const LocationFix.failure(LocationFailure.denied);
      }

      final position = await _readPosition();
      return LocationFix.success(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      // Ловим всё: помимо таймаута плагин бросает свои
      // LocationServiceDisabledException и PermissionDefinitionsNotFoundException.
      // Координаты — не повод не дать водителю завершить доставку.
      if (kDebugMode) debugPrint('DeviceLocationService: $e');
      return const LocationFix.failure(LocationFailure.unknown);
    }
  }
}

/// Точность — [LocationAccuracy.high]: нужна отметка подъезда, а не города.
///
/// Таймаут обязателен: в подвале или во дворе-колодце запрос иначе висит,
/// пока водитель не закроет экран.
Future<Position> _defaultPositionReader() => Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );

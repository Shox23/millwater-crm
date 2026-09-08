import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';


import 'map_route.dart';

/// Проверка, что систему есть чем открыть ссылку (`canLaunchUrl`).
typedef UrlProbe = Future<bool> Function(Uri url);

/// Передача ссылки в ОС (`launchUrl`).
typedef UrlOpener = Future<bool> Function(Uri url, {LaunchMode mode});

/// Чем закончилась попытка открыть маршрут.
class OpenRouteResult extends Equatable {
  const OpenRouteResult.success() : error = null;

  const OpenRouteResult.failure(RouteIssue this.error);

  /// Причина отказа; null — маршрут открыт. Текст подбирает интерфейс.
  final RouteIssue? error;

  bool get isSuccess => error == null;

  @override
  List<Object?> get props => [error];
}

/// Открывает готовый маршрут в Яндекс.Картах: нативное приложение или веб.
///
/// Своей карты в приложении нет — сервис только собирает ссылку и отдаёт её
/// операционной системе. Наружу исключения не выходят: любая осечка
/// `url_launcher` превращается в следующий фолбэк или в текст ошибки.
///
/// Зависимости принимаются конструктором, чтобы в тестах подменить
/// `url_launcher` обычными функциями.
class YandexRouteLauncher {
  // Поля заполняются инициализатором, а не `this.`-параметрами: именованный
  // параметр в Dart не может начинаться с подчёркивания.
  // ignore_for_file: prefer_initializing_formals
  const YandexRouteLauncher({
    UrlProbe canLaunch = canLaunchUrl,
    UrlOpener launch = launchUrl,
  })  : _canLaunch = canLaunch,
        _launch = launch;

  final UrlProbe _canLaunch;
  final UrlOpener _launch;

  static const _webHost = 'yandex.ru';
  static const _webPath = '/maps/';
  static const _deeplinkScheme = 'yandexmaps';
  static const _deeplinkHost = 'maps.yandex.ru';

  /// Строит ссылку по [route] и открывает её.
  ///
  /// Порядок действий:
  /// 1. Валидация [RouteData.validate] — при ошибке ничего не открывается,
  ///    её текст возвращается вызывающему.
  /// 2. Если у всех точек есть координаты — попытка отдать `yandexmaps://`
  ///    нативному приложению (`canLaunchUrl`, затем `LaunchMode.externalApplication`).
  ///    Текстовые адреса сюда не отдаются намеренно: в маршруте приложение
  ///    принимает только координаты, а текстовую точку молча выбрасывает —
  ///    именно так маршрут из трёх адресов открывался пустым, с одним
  ///    «Моё местоположение» в поле «куда».
  /// 3. Веб-ссылка `https://yandex.ru/maps/` через `LaunchMode.externalApplication`:
  ///    последнее средство для маршрута, в котором остался текст.
  /// 4. Ничего не сработало — ошибка «Не удалось открыть Яндекс.Карты».
  ///
  /// Встроенного браузера в цепочке нет: он открывается поверх приложения и
  /// водителю всё равно не годится — по карте внутри веб-вида не поедешь.
  Future<OpenRouteResult> openRoute(RouteData route) async {
    final invalid = route.validate();
    if (invalid != null) return OpenRouteResult.failure(invalid);

    // Параметры одинаковы для deeplink и веба, отличается только адрес.
    // Сборка через queryParameters, а не строкой: Uri(query: ...) считает
    // строку уже закодированной и пропустит `&`, `=`, `+` из адреса насквозь,
    // сломав разбор параметров.
    final query = {'rtext': route.rtext, 'rtt': route.mode.code};

    if (route.hasOnlyCoordinates) {
      final deeplink = Uri(
        scheme: _deeplinkScheme,
        host: _deeplinkHost,
        path: '/',
        queryParameters: query,
      );
      if (await _tryDeeplink(deeplink)) return const OpenRouteResult.success();
    }

    final web = Uri.https(_webHost, _webPath, query);

    // Сюда доходит только маршрут, в котором осталась текстовая точка.
    //
    // Ловушка iOS: `yandex.ru/maps` подхватывает universal link'ом само
    // приложение Яндекс.Карт — то самое, которое текст в маршруте не
    // принимает, — и водитель видит «Не удалось построить маршрут». Обойти
    // это нечем: заставить систему открыть внешний браузер для домена,
    // объявленного приложением, нельзя. Поэтому текстовых точек надо не
    // допускать (`RoutePlanner` ставит координаты каждой остановке), а этот
    // запуск остаётся последним средством — на Android и там, где
    // приложения нет.
    if (await _tryLaunch(web, LaunchMode.externalApplication)) {
      return const OpenRouteResult.success();
    }

    return const OpenRouteResult.failure(RouteOpenFailed());
  }

  /// Отдаёт deeplink приложению, если оно установлено.
  ///
  /// Без `LSApplicationQueriesSchemes` (iOS) и `<queries>` (Android)
  /// `canLaunchUrl` вернёт false даже при установленном приложении.
  Future<bool> _tryDeeplink(Uri url) async {
    try {
      if (!await _canLaunch(url)) return false;
    } catch (e) {
      _log('canLaunchUrl(${url.scheme}) завершился ошибкой: $e');
      return false;
    }
    return _tryLaunch(url, LaunchMode.externalApplication);
  }

  /// `launchUrl` умеет не только вернуть false, но и бросить
  /// `PlatformException` (особенно в режиме inAppBrowserView). Исключение —
  /// повод перейти к следующему фолбэку, а не уронить экран.
  Future<bool> _tryLaunch(Uri url, LaunchMode mode) async {
    try {
      return await _launch(url, mode: mode);
    } catch (e) {
      _log('launchUrl(${url.scheme}, ${mode.name}) завершился ошибкой: $e');
      return false;
    }
  }

  /// Логи только в отладке и без самой ссылки: адреса пользователя в
  /// релизных логах не нужны.
  void _log(String message) {
    if (kDebugMode) debugPrint('YandexRouteLauncher: $message');
  }
}

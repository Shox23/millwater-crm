import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'dio_client.dart';

/// Кадр Server-Sent Events — всё, что пришло между двумя пустыми строками.
///
/// Это ещё не событие приложения: разбор тела живёт слоем выше, здесь только
/// рамка протокола.
class SseFrame {
  const SseFrame({
    this.id,
    this.event,
    this.data = '',
    this.retry,
  });

  /// Поле `id:` — им сервер продолжит поток после переподключения.
  final String? id;

  /// Поле `event:`; у Water CRM дублирует `type` внутри JSON.
  final String? event;

  /// Склеенные строки `data:`; пустая строка — кадр без тела.
  final String data;

  /// Поле `retry:` — сервер просит переподключаться не раньше этой паузы.
  final Duration? retry;

  @override
  String toString() => 'SseFrame(id: $id, event: $event, data: $data)';
}

/// Собирает кадры SSE из потока строк.
///
/// Отделено от сети намеренно: разбор — единственная содержательная часть
/// протокола, и проверять её на живом сокете значит не проверять никогда.
///
/// Правила (W3C EventSource, сверено с боевыми кадрами):
/// * строка, начинающаяся с `:`, — комментарий; сервер шлёт ими ping;
/// * `поле: значение`, один пробел после двоеточия съедается;
/// * несколько `data:` в кадре склеиваются переводом строки;
/// * пустая строка завершает кадр; блок, в котором не встретилось ни одного
///   известного поля (например, только ping), кадром не считается;
/// * кадр, оборванный на середине, не отдаётся вовсе — половина JSON всё
///   равно не разберётся, а пропущенное догонит `Last-Event-ID`.
Stream<SseFrame> parseSseFrames(Stream<String> lines) async* {
  String? id;
  String? event;
  Duration? retry;
  final data = <String>[];
  var hasFields = false;

  await for (final line in lines) {
    if (line.isEmpty) {
      if (hasFields) {
        yield SseFrame(
          id: id,
          event: event,
          data: data.join('\n'),
          retry: retry,
        );
      }
      id = null;
      event = null;
      retry = null;
      data.clear();
      hasFields = false;
      continue;
    }
    if (line.startsWith(':')) continue;

    final colon = line.indexOf(':');
    final field = colon == -1 ? line : line.substring(0, colon);
    var value = colon == -1 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);

    switch (field) {
      case 'id':
        id = value;
        hasFields = true;
      case 'event':
        event = value;
        hasFields = true;
      case 'data':
        data.add(value);
        hasFields = true;
      case 'retry':
        final ms = int.tryParse(value);
        if (ms != null) retry = Duration(milliseconds: ms);
        hasFields = true;
      default:
        // Незнакомые поля спецификация велит молча игнорировать: сервер
        // вправе добавить своё, и падать из-за этого клиент не должен.
        break;
    }
  }
}

/// Байты ответа → строки для [parseSseFrames].
///
/// `utf8.decoder` в потоковом режиме сам склеивает многобайтный символ,
/// разорванный границей чанка: имена заказчиков кириллические, и на неё
/// они попадают регулярно.
Stream<String> decodeSseLines(Stream<List<int>> bytes) =>
    const LineSplitter().bind(utf8.decoder.bind(bytes));

/// Подписка на уход приложения в фон; возвращает функцию отписки.
///
/// Вынесено в параметр, потому что настоящий [AppLifecycleListener] требует
/// поднятого `WidgetsBinding` — в тестах вместо него подставляется заглушка.
typedef LifecycleBinder = VoidCallback Function({
  required VoidCallback onPause,
  required VoidCallback onResume,
});

/// Боевая реализация [LifecycleBinder].
VoidCallback bindAppLifecycle({
  required VoidCallback onPause,
  required VoidCallback onResume,
}) {
  final listener = AppLifecycleListener(onPause: onPause, onResume: onResume);
  return listener.dispose;
}

/// Обновление протухшего токена; `false` — сессия окончательно истекла.
typedef UnauthorizedHandler = Future<bool> Function();

/// Долгоживущее подключение к SSE-эндпоинту.
///
/// Подключается лениво — на первого подписчика [frames] — и отпускает сокет,
/// когда подписчиков не осталось: держать соединение ради экрана, которого
/// никто не видит, незачем.
///
/// Что здесь есть сверх «прочитать ответ»:
/// * переподключение с растущей паузой и `Last-Event-ID`: обрыв связи у
///   водителя в дороге — обычное дело, а события пропускать нельзя;
/// * сторож простоя — сервер шлёт ping раз в 15 с, и тишина дольше
///   [idleTimeout] означает мёртвое соединение задолго до того, как об
///   ошибке сокета сообщит система;
/// * пауза на время фона: в фоне поток некому показывать, а радио он будит;
/// * свой разбор 401 — интерсептор Dio умеет повторить обычный запрос, а
///   потоку нужно переоткрыть соединение и продолжить с последнего события.
class SseClient {
  // Поля заполняются инициализатором, а не `this.`-параметрами: именованный
  // параметр в Dart не может начинаться с подчёркивания.
  // ignore_for_file: prefer_initializing_formals
  SseClient({
    required Dio dio,
    required String path,
    UnauthorizedHandler? onUnauthorized,
    Duration idleTimeout = const Duration(seconds: 45),
    Duration minRetryDelay = const Duration(seconds: 1),
    Duration maxRetryDelay = const Duration(seconds: 60),
    LifecycleBinder lifecycle = bindAppLifecycle,
  })  : _dio = dio,
        _path = path,
        _onUnauthorized = onUnauthorized,
        _idleTimeout = idleTimeout,
        _minRetryDelay = minRetryDelay,
        _maxRetryDelay = maxRetryDelay,
        _lifecycle = lifecycle;

  final Dio _dio;
  final String _path;
  final UnauthorizedHandler? _onUnauthorized;
  final Duration _idleTimeout;
  final Duration _minRetryDelay;
  final Duration _maxRetryDelay;
  final LifecycleBinder _lifecycle;

  late final StreamController<SseFrame> _controller =
      StreamController<SseFrame>.broadcast(onListen: _start, onCancel: _stop);

  /// Идентификатор последнего полученного события — точка докачки.
  String? _lastEventId;

  /// Пауза, о которой попросил сервер полем `retry:`.
  Duration? _serverRetry;

  CancelToken? _request;
  Timer? _watchdog;
  Timer? _sleepTimer;
  Completer<void>? _wakeup;
  VoidCallback? _unbindLifecycle;

  bool _running = false;
  bool _paused = false;

  /// Номер живого цикла: `_stop()` сразу за `_start()` не должен оставить
  /// два цикла, читающих один и тот же контроллер.
  int _generation = 0;

  /// Кадры потока. Broadcast: на события смотрят и списки, и открытая карточка.
  Stream<SseFrame> get frames => _controller.stream;

  /// Идентификатор, с которого продолжится поток после переподключения.
  String? get lastEventId => _lastEventId;

  /// Отпускает соединение и закрывает поток. Дальше клиент непригоден.
  Future<void> close() async {
    _stop();
    await _controller.close();
  }

  void _start() {
    if (_running) return;
    _running = true;
    _unbindLifecycle = _lifecycle(onPause: _pause, onResume: _resume);
    unawaited(_loop(++_generation));
  }

  void _stop() {
    _running = false;
    _paused = false;
    _request?.cancel('sse-stopped');
    _request = null;
    _watchdog?.cancel();
    _watchdog = null;
    _unbindLifecycle?.call();
    _unbindLifecycle = null;
    // Разбудить цикл, чтобы он увидел флаг и вышел, а не досыпал паузу.
    _wake();
  }

  /// В фоне соединение только тратит батарею: экранов не видно, а ping
  /// каждые 15 с будит радио. Пропущенное догоним по `Last-Event-ID`.
  void _pause() {
    if (_paused || !_running) return;
    _paused = true;
    _request?.cancel('sse-paused');
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    _wake();
  }

  Future<void> _loop(int generation) async {
    var attempt = 0;

    while (_running && generation == _generation) {
      if (_paused) {
        // Без таймера: разбудит возвращение из фона или остановка.
        await _sleep(null);
        continue;
      }

      try {
        // Соединение, прожившее хоть сколько-то, — не неудачная попытка:
        // после суток работы обрыв должен чиниться сразу, а не через минуту.
        if (await _readStream()) attempt = 0;
      } on _Unauthorized {
        final refreshed = await _onUnauthorized?.call() ?? false;
        if (refreshed) {
          attempt = 0;
          continue;
        }
        // Сессия истекла: экран входа уже показывает `AuthBloc`, и долбиться
        // в поток мёртвым токеном бессмысленно.
        break;
      } catch (_) {
        // Обрыв, таймаут, сторож простоя, мусор вместо потока — всё это
        // лечится одинаково: подождать и подключиться заново.
      }

      if (!_running || generation != _generation) break;
      // Пауза фона ждёт наверху цикла — досыпать перед ней нечего.
      if (_paused) continue;
      await _sleep(_delayFor(attempt++));
    }

    // Цикл мог выйти сам (истёкшая сессия), а не по `_stop()`. Флаг должен
    // это отражать: иначе следующий подписчик получит «уже работаю» и
    // остался бы без потока навсегда.
    if (generation == _generation) _running = false;
  }

  /// Читает поток до конца. Возвращает `true`, если что-то успело прийти.
  Future<bool> _readStream() async {
    final request = CancelToken();
    _request = request;
    var received = false;

    final Response<ResponseBody> response;
    try {
      response = await _dio.get<ResponseBody>(
        _path,
        queryParameters: {'since': ?_since()},
        options: Options(
          responseType: ResponseType.stream,
          // Между событиями поток молчит минутами. Общий
          // `ApiConfig.receiveTimeout` (15 с) рвал бы его на каждом простое —
          // на этом запросе таймаут снимается целиком.
          receiveTimeout: Duration.zero,
          headers: {
            'Accept': 'text/event-stream',
            // Докачка: сервер продолжит со следующего события, а не с
            // текущего момента.
            'Last-Event-ID': ?_lastEventId,
          },
          // 401 разбираем сами — см. описание класса.
          extra: const {kNoAuthRetry: true},
        ),
        cancelToken: request,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw const _Unauthorized();
      rethrow;
    }

    final body = response.data;
    if (body == null) return false;

    _armWatchdog(request);
    try {
      final bytes = body.stream.map((chunk) {
        // Признак жизни — любой байт, включая ping: он для того и шлётся.
        received = true;
        _armWatchdog(request);
        return chunk;
      });

      await for (final frame in parseSseFrames(decodeSseLines(bytes))) {
        if (frame.id != null && frame.id!.isNotEmpty) _lastEventId = frame.id;
        if (frame.retry != null) _serverRetry = frame.retry;
        // Кадр без тела нести некому: это смена `retry` или голый `id`.
        if (frame.data.isNotEmpty && !_controller.isClosed) {
          _controller.add(frame);
        }
      }
    } finally {
      _watchdog?.cancel();
      _watchdog = null;
      if (identical(_request, request)) _request = null;
    }
    return received;
  }

  /// `since` дублирует `Last-Event-ID` запасным путём — заголовок по дороге
  /// может потерять прокси. Нечисловой идентификатор сервер не примет
  /// (параметр объявлен целым), поэтому такой не отправляем вовсе.
  String? _since() {
    final id = _lastEventId;
    if (id == null || int.tryParse(id) == null) return null;
    return id;
  }

  void _armWatchdog(CancelToken request) {
    _watchdog?.cancel();
    _watchdog = Timer(_idleTimeout, () {
      // Ни данных, ни ping дольше [_idleTimeout]. Соединение умерло молча
      // (уснувшая сеть, NAT, перезапуск nginx): для системы сокет ещё жив,
      // и ошибки чтения мы не дождёмся никогда — рвём сами.
      request.cancel('sse-idle');
    });
  }

  /// Пауза перед попыткой номер [attempt] (считая с нуля).
  ///
  /// Удвоение до потолка: сервер может лежать, и клиент, стучащийся раз в
  /// секунду, ему не поможет. Джиттера нет намеренно — клиентов у CRM
  /// единицы, зато пауза предсказуема в тестах.
  Duration _delayFor(int attempt) {
    final base = _serverRetry ?? _minRetryDelay;
    final ms = base.inMilliseconds * (1 << attempt.clamp(0, 16));
    return ms >= _maxRetryDelay.inMilliseconds
        ? _maxRetryDelay
        : Duration(milliseconds: ms);
  }

  /// Ждёт [delay] или пробуждения. `null` — ждать только пробуждения.
  Future<void> _sleep(Duration? delay) {
    final wake = Completer<void>();
    _wakeup = wake;
    if (delay != null) _sleepTimer = Timer(delay, _wake);
    return wake.future;
  }

  void _wake() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    final wake = _wakeup;
    _wakeup = null;
    if (wake != null && !wake.isCompleted) wake.complete();
  }
}

/// Сервер отказал по токену. Для потока это не «ошибка запроса», а повод
/// обновить токен и открыть соединение заново.
class _Unauthorized implements Exception {
  const _Unauthorized();
}

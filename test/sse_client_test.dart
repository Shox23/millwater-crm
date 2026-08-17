import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/data/network/sse_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Строки одним куском — как их видел бы разбор без разрывов чанков.
Stream<String> _lines(String raw) =>
    Stream<String>.fromIterable(const LineSplitter().convert(raw));

/// Сервер, отдающий поток по кускам: что и когда прислать, решает тест.
///
/// Отмену (`CancelToken`) обязан отрабатывать сам — настоящий адаптер рвёт
/// сокет, а здесь без этого чтение не закончилось бы никогда.
class _StreamAdapter implements HttpClientAdapter {
  _StreamAdapter({this.statusFor});

  /// Статус ответа по номеру подключения (с нуля). По умолчанию 200.
  final int Function(int attempt)? statusFor;

  final List<RequestOptions> requests = [];
  final List<StreamController<Uint8List>> connections = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final attempt = requests.length;
    requests.add(options);

    final status = statusFor?.call(attempt) ?? 200;
    if (status != 200) {
      return ResponseBody.fromString(
        jsonEncode(const {'detail': 'Not authenticated'}),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    final chunks = StreamController<Uint8List>();
    connections.add(chunks);
    unawaited(cancelFuture?.then((_) {
      if (!chunks.isClosed) {
        chunks.addError(DioException.requestCancelled(
          requestOptions: options,
          reason: null,
        ));
        chunks.close();
      }
    }));

    return ResponseBody(
      chunks.stream,
      status,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  void send(int connection, String raw) =>
      connections[connection].add(Uint8List.fromList(utf8.encode(raw)));

  /// Сервер закрыл соединение штатно.
  void hangUp(int connection) => connections[connection].close();

  /// Ждёт, пока клиент откроет [count] соединений.
  Future<void> waitForRequests(int count) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (requests.length < count) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Ожидали $count подключений, дождались ${requests.length}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }
}

/// Фальшивый жизненный цикл: настоящий [AppLifecycleListener] требует
/// поднятого WidgetsBinding, а фон и возврат тест изображает сам.
class _Lifecycle {
  VoidCallback? pause;
  VoidCallback? resume;
  int unbinds = 0;

  VoidCallback bind({
    required VoidCallback onPause,
    required VoidCallback onResume,
  }) {
    pause = onPause;
    resume = onResume;
    return () => unbinds++;
  }
}

void main() {
  group('Разбор кадров SSE', () {
    test('обычный кадр разбирается целиком', () async {
      final frames = await parseSseFrames(_lines(
        'id: 7\n'
        'event: delivery_status_updated\n'
        'data: {"id":7,"type":"delivery_status_updated"}\n'
        '\n',
      )).toList();

      expect(frames, hasLength(1));
      expect(frames.single.id, '7');
      expect(frames.single.event, 'delivery_status_updated');
      expect(frames.single.data, '{"id":7,"type":"delivery_status_updated"}');
    });

    test('несколько data склеиваются переводом строки', () async {
      final frames = await parseSseFrames(_lines(
        'event: x\n'
        'data: {"id":7,\n'
        'data:  "customer_name":"Влад"}\n'
        '\n',
      )).toList();

      // Съедается ровно один пробел после двоеточия — второй принадлежит JSON.
      expect(frames.single.data, '{"id":7,\n "customer_name":"Влад"}');
    });

    test('ping и прочие комментарии кадром не считаются', () async {
      final frames = await parseSseFrames(_lines(
        ': ping\n'
        '\n'
        ':\n'
        '\n'
        'data: {"id":1}\n'
        '\n',
      )).toList();

      expect(frames, hasLength(1));
      expect(frames.single.data, '{"id":1}');
    });

    test('кадр без id отдаётся как есть', () async {
      final frames = await parseSseFrames(_lines(
        'event: route_customer_added\n'
        'data: {"type":"route_customer_added"}\n'
        '\n',
      )).toList();

      expect(frames.single.id, isNull);
      expect(frames.single.event, 'route_customer_added');
    });

    test('оборванный на середине кадр не отдаётся', () async {
      final frames = await parseSseFrames(_lines(
        'id: 1\n'
        'data: {"id":1}\n'
        '\n'
        'id: 2\n'
        'data: {"id":2,"pay',
      )).toList();

      // Второй кадр не закрыт пустой строкой — половина JSON никому не нужна.
      expect(frames, hasLength(1));
      expect(frames.single.id, '1');
    });

    test('retry разбирается, кадром без тела поток не засоряется', () async {
      final frames =
          await parseSseFrames(_lines('retry: 5000\n\n')).toList();

      expect(frames.single.retry, const Duration(milliseconds: 5000));
      expect(frames.single.data, isEmpty);
    });

    test('многобайтный символ, разорванный чанком, собирается обратно',
        () async {
      final bytes = utf8.encode('data: {"name":"Влад"}\n\n');
      // Рвём ровно посередине кириллической буквы.
      final stream = Stream<List<int>>.fromIterable([
        bytes.sublist(0, 16),
        bytes.sublist(16),
      ]);

      final frames = await parseSseFrames(decodeSseLines(stream)).toList();

      expect(frames.single.data, '{"name":"Влад"}');
    });
  });

  group('SseClient', () {
    late _StreamAdapter adapter;
    late _Lifecycle lifecycle;
    late SseClient client;

    SseClient build({
      int Function(int attempt)? statusFor,
      UnauthorizedHandler? onUnauthorized,
      Duration idleTimeout = const Duration(seconds: 30),
    }) {
      adapter = _StreamAdapter(statusFor: statusFor);
      lifecycle = _Lifecycle();
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      return client = SseClient(
        dio: dio,
        path: '/admin/notifications/stream',
        onUnauthorized: onUnauthorized,
        idleTimeout: idleTimeout,
        minRetryDelay: const Duration(milliseconds: 10),
        maxRetryDelay: const Duration(milliseconds: 40),
        lifecycle: lifecycle.bind,
      );
    }

    tearDown(() => client.close());

    test('подключается только под подписчика и снимает receiveTimeout',
        () async {
      build();
      // Без подписчиков сокет держать незачем.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(adapter.requests, isEmpty);

      final sub = client.frames.listen((_) {});
      addTearDown(sub.cancel);
      await adapter.waitForRequests(1);

      final request = adapter.requests.single;
      expect(request.receiveTimeout, Duration.zero);
      expect(request.headers['Accept'], 'text/event-stream');
      // Первое подключение докачивать нечего.
      expect(request.headers.containsKey('Last-Event-ID'), isFalse);
      expect(request.queryParameters.containsKey('since'), isFalse);
    });

    test('после обрыва подключается заново и продолжает с Last-Event-ID',
        () async {
      build();
      final frames = <SseFrame>[];
      final sub = client.frames.listen(frames.add);
      addTearDown(sub.cancel);

      await adapter.waitForRequests(1);
      adapter.send(0, 'id: 7\nevent: delivery_status_updated\ndata: {"id":7}\n\n');
      await pumpEventQueue();
      adapter.hangUp(0);

      await adapter.waitForRequests(2);
      expect(frames.single.id, '7');
      expect(adapter.requests[1].headers['Last-Event-ID'], '7');
      // Заголовок может потерять прокси — тот же номер уходит и параметром.
      expect(adapter.requests[1].queryParameters['since'], '7');
    });

    test('тишина дольше сторожа рвёт соединение сама', () async {
      build(idleTimeout: const Duration(milliseconds: 60));
      final sub = client.frames.listen((_) {});
      addTearDown(sub.cancel);

      await adapter.waitForRequests(1);
      // Ни данных, ни ping: ошибки сокета не будет, но поток мёртв.
      await adapter.waitForRequests(2);
      expect(adapter.connections.first.isClosed, isTrue);
    });

    test('ping отодвигает сторожа', () async {
      build(idleTimeout: const Duration(milliseconds: 120));
      final sub = client.frames.listen((_) {});
      addTearDown(sub.cancel);

      await adapter.waitForRequests(1);
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        adapter.send(0, ': ping\n\n');
      }

      // 200 мс молчания в кадрах, но с ping'ами — соединение то же самое.
      expect(adapter.requests, hasLength(1));
    });

    test('уход в фон отпускает соединение, возврат подключает заново',
        () async {
      build();
      final sub = client.frames.listen((_) {});
      addTearDown(sub.cancel);
      await adapter.waitForRequests(1);

      lifecycle.pause!();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      // Пауза не переподключается: пока приложение в фоне, поток не нужен.
      expect(adapter.requests, hasLength(1));
      expect(adapter.connections.first.isClosed, isTrue);

      lifecycle.resume!();
      await adapter.waitForRequests(2);
    });

    test('401 обновляет токен и переподключается без паузы', () async {
      var refreshes = 0;
      build(
        statusFor: (attempt) => attempt == 0 ? 401 : 200,
        onUnauthorized: () async {
          refreshes++;
          return true;
        },
      );
      final sub = client.frames.listen((_) {});
      addTearDown(sub.cancel);

      await adapter.waitForRequests(2);
      expect(refreshes, 1);
    });

    test('истёкшая сессия останавливает поток', () async {
      build(
        statusFor: (_) => 401,
        onUnauthorized: () async => false,
      );
      final sub = client.frames.listen((_) {});
      addTearDown(sub.cancel);

      await adapter.waitForRequests(1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      // Долбиться в поток мёртвым токеном бессмысленно — впереди экран входа.
      expect(adapter.requests, hasLength(1));
    });

    test('уход последнего подписчика закрывает соединение', () async {
      build();
      final sub = client.frames.listen((_) {});
      await adapter.waitForRequests(1);

      await sub.cancel();
      await pumpEventQueue();

      expect(adapter.connections.first.isClosed, isTrue);
      expect(lifecycle.unbinds, 1);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(adapter.requests, hasLength(1));
    });
  });
}

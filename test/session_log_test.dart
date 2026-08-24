import 'dart:async';

import 'package:crm_millwater/core/observability/session_log.dart';
import 'package:crm_millwater/data/network/dio_client.dart';
import 'package:crm_millwater/data/network/session_storage.dart';
import 'package:crm_millwater/data/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Журнал, который никогда не отвечает.
///
/// Ровно то, чем оказалось хранилище настроек в тестах: платформенного
/// канала нет, запись не завершается. Ожидание такого журнала подвешивало
/// выход из аккаунта целиком.
class _StuckSessionLog implements SessionLog {
  @override
  Future<SessionEnd?> last() => Completer<SessionEnd?>().future;

  @override
  Future<void> record(SessionEnd end) => Completer<void>().future;
}

void main() {
  group('Запись обрыва', () {
    test('переживает сохранение и чтение', () {
      final end = SessionEnd(
        at: DateTime.utc(2026, 8, 24, 19, 31),
        reason: SessionEndReason.refreshFailed,
        path: '/auth/refresh',
        statusCode: 401,
      );

      final back = SessionEnd.tryFromJson(end.toJson())!;

      expect(back.at.toUtc(), end.at);
      expect(back.reason, SessionEndReason.refreshFailed);
      expect(back.path, '/auth/refresh');
      expect(back.statusCode, 401);
    });

    test('обходится без необязательных полей', () {
      final end = SessionEnd(
        at: DateTime.utc(2026, 8, 24),
        reason: SessionEndReason.signedOut,
      );

      final json = end.toJson();
      expect(json.containsKey('path'), isFalse);
      expect(json.containsKey('status_code'), isFalse);

      final back = SessionEnd.tryFromJson(json)!;
      expect(back.reason, SessionEndReason.signedOut);
      expect(back.statusCode, isNull);
    });

    test('мусор в хранилище не разбирается в запись', () {
      // После отката версии или ручной правки — не повод падать на настройках.
      expect(SessionEnd.tryFromJson({'at': 'вчера', 'reason': 'x'}), isNull);
      expect(SessionEnd.tryFromJson(const {}), isNull);
      expect(
        SessionEnd.tryFromJson({'at': DateTime.utc(2026).toIso8601String()}),
        isNull,
      );
    });

    test('строка для разработчика несёт время, причину и код', () {
      final details = SessionEnd(
        at: DateTime.utc(2026, 8, 24, 19, 31),
        reason: SessionEndReason.refreshFailed,
        path: '/auth/refresh',
        statusCode: 401,
      ).details;

      expect(details, contains('2026-08-24T19:31'));
      expect(details, contains('refresh_failed'));
      expect(details, contains('/auth/refresh'));
      expect(details, contains('HTTP 401'));
    });
  });

  group('Кто пишет в журнал', () {
    test('выход по кнопке отмечается отдельной причиной', () async {
      final log = InMemorySessionLog();
      final store = AuthTokenStore(InMemorySessionStorage(), log);
      await store.setTokens(access: 'a', refresh: 'r');

      await AuthRepository(Dio(), store).logout();

      // Обычный выход записывается тоже — иначе «выкинуло» от «вышел сам»
      // в журнале не отличить.
      expect(log.entry?.reason, SessionEndReason.signedOut);
      expect(store.isAuthenticated, isFalse);
    });

    test('по умолчанию стор в хранилище устройства не пишет', () async {
      // Стор, собранный без корня приложения, молча писать не должен —
      // боевой журнал подставляет app.dart.
      final store = AuthTokenStore(InMemorySessionStorage());
      await store.setTokens(access: 'a', refresh: 'r');

      // Падать здесь нечему: журнал по умолчанию — пустышка.
      await AuthRepository(Dio(), store).logout();

      expect(store.isAuthenticated, isFalse);
    });
  });

  group('Диагностика не мешает тому, что диагностирует', () {
    test('выход завершается, даже если журнал не отвечает', () async {
      final store = AuthTokenStore(InMemorySessionStorage(), _StuckSessionLog());
      await store.setTokens(access: 'a', refresh: 'r');

      // Ожидание записи держало бы выход бесконечно — а пользователь ждёт
      // экран входа.
      await AuthRepository(Dio(), store).logout().timeout(
            const Duration(seconds: 2),
            onTimeout: () => fail('выход подвис на записи в журнал'),
          );

      expect(store.isAuthenticated, isFalse);
    });
  });
}

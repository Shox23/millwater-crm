import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Отчего в прошлый раз оборвалась сессия.
enum SessionEndReason {
  /// Обновление пары токенов не удалось — самый интересный случай:
  /// пользователь ничего не делал, а его вернуло на экран входа.
  refreshFailed('refresh_failed'),

  /// Сохранённую сессию сервер не признал при запуске.
  restoreRejected('restore_rejected'),

  /// Вышли сами. Записывается, чтобы обычный выход не путали с обрывом.
  signedOut('signed_out');

  const SessionEndReason(this.wire);

  final String wire;

  static SessionEndReason? tryParse(String? value) =>
      SessionEndReason.values.where((r) => r.wire == value).firstOrNull;
}

/// Обстоятельства последнего обрыва сессии.
@immutable
class SessionEnd {
  const SessionEnd({
    required this.at,
    required this.reason,
    this.path,
    this.statusCode,
  });

  final DateTime at;
  final SessionEndReason reason;

  /// Какой запрос принёс отказ.
  final String? path;

  /// Код ответа, если он вообще был: при обрыве связи его нет.
  final int? statusCode;

  Map<String, dynamic> toJson() => {
        'at': at.toUtc().toIso8601String(),
        'reason': reason.wire,
        'path': ?path,
        'status_code': ?statusCode,
      };

  static SessionEnd? tryFromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    final reason = SessionEndReason.tryParse(json['reason'] as String?);
    if (at == null || reason == null) return null;

    return SessionEnd(
      at: at.toLocal(),
      reason: reason,
      path: json['path'] as String?,
      statusCode: json['status_code'] as int?,
    );
  }

  /// Строка для отправки разработчику бэкенда — её и копируют кнопкой.
  String get details => [
        at.toUtc().toIso8601String(),
        reason.wire,
        ?path,
        if (statusCode != null) 'HTTP $statusCode',
      ].join(' · ');
}

/// Журнал обрывов сессии — одна последняя запись.
///
/// Заведён после жалобы «один раз выкинуло из сессии»: разбирать такое по
/// пересказу нечем, а на клиенте обновление токена и без того сделано
/// единственной попыткой на все параллельные запросы ([TokenRefresher]).
/// Запись показывается в настройках, чтобы в следующий раз у бэкенда были
/// время, эндпоинт и код ответа.
///
/// Хранится не в секретном хранилище: выход из аккаунта стирает то целиком
/// (`deleteAll`), и запись уехала бы вместе с токенами — ровно в тот момент,
/// ради которого она и заводилась.
abstract class SessionLog {
  Future<SessionEnd?> last();

  Future<void> record(SessionEnd end);
}

/// Реализация поверх `SharedPreferences`.
class PrefsSessionLog implements SessionLog {
  const PrefsSessionLog();

  static const _key = 'session.last_end';

  @override
  Future<SessionEnd?> last() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      return json is Map ? SessionEnd.tryFromJson(json.cast()) : null;
    } catch (e) {
      // Диагностика не должна мешать тому, что диагностирует.
      _log(e);
      return null;
    }
  }

  @override
  Future<void> record(SessionEnd end) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(end.toJson()));
    } catch (e) {
      _log(e);
    }
  }

  static void _log(Object error) {
    if (kDebugMode) debugPrint('SessionLog: $error');
  }
}

/// Журнал, который ничего не пишет.
///
/// Значение по умолчанию у [AuthTokenStore]: стор, собранный без корня
/// приложения, не должен молча писать в хранилище устройства. Боевой журнал
/// подставляет `app.dart` — там же, где собираются остальные зависимости.
class NoSessionLog implements SessionLog {
  const NoSessionLog();

  @override
  Future<SessionEnd?> last() async => null;

  @override
  Future<void> record(SessionEnd end) async {}
}

/// Реализация для тестов: держит запись в памяти.
class InMemorySessionLog implements SessionLog {
  InMemorySessionLog([this.entry]);

  SessionEnd? entry;

  @override
  Future<SessionEnd?> last() async => entry;

  @override
  Future<void> record(SessionEnd end) async => entry = end;
}

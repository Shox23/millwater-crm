import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'error_noise.dart';

/// Запуск приложения под наблюдением: необработанные ошибки не теряются.
///
/// До этого любое исключение в асинхронном коде исчезало бесследно — у
/// водителя красный экран или зависший спиннер, а в проекте ни следа. Узнать
/// о поломке можно было только по звонку, и воспроизвести её — не по чему.
///
/// Адрес проекта задаётся сборкой: `--dart-define=SENTRY_DSN=https://...`.
/// Без него отчёты слать некуда — тогда ставим только локальные обработчики,
/// чтобы поведение не расходилось между сборками с ключом и без.
abstract class Observability {
  static const String _dsn = String.fromEnvironment('SENTRY_DSN');

  /// Настроен ли приём отчётов. Ложь — крэши видит только консоль.
  static bool get isEnabled => _dsn.isNotEmpty;

  /// Поднимает приложение. [buildApp] выполняется уже под наблюдением,
  /// поэтому падение при чтении настроек тоже попадёт в отчёт.
  static Future<void> run(Future<Widget> Function() buildApp) async {
    // Биндинг поднимается внутри `start`, а не до него: он должен достаться
    // той же зоне, в которой потом живёт `runApp`. Инициализация снаружи —
    // классический источник расхождения зон. `SentryFlutter.init` вызывает
    // то же самое сам, повторный вызов возвращает уже готовый экземпляр.
    Future<void> start() async {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(await buildApp());
    }

    if (!isEnabled) {
      _installLocalHandlers();
      // Своя зона нужна и здесь: без неё асинхронная ошибка не дойдёт даже
      // до консоли, и отладочная сборка будет врать про то, что всё цело.
      return runZonedGuarded(start, _reportZoneError);
    }

    // `SentryFlutter.init` сам ставит `FlutterError.onError`,
    // `PlatformDispatcher.instance.onError` и запускает `appRunner` в
    // защищённой зоне — свои обработчики поверх только задвоили бы отчёты.
    await SentryFlutter.init(_configure, appRunner: start);
  }

  static void _configure(SentryFlutterOptions options) {
    options.dsn = _dsn;
    options.environment = kReleaseMode ? 'production' : 'development';

    // Личные данные не отправляем. В CRM это имена, адреса и телефоны
    // заказчиков: они не нужны для починки крэша, а утекать им незачем.
    // По той же причине нет скриншотов — на экране водителя всегда чей-то
    // адрес. Дерево виджетов (`attachViewHierarchy`) выключено по умолчанию
    // и включаться не должно по той же причине: подписи в нём те же данные.
    options.sendDefaultPii = false;
    options.attachScreenshot = false;

    // Трассировка производительности выключена: она съедает квоту, а вопрос
    // «почему медленно» решается профайлером на устройстве, а не выборкой
    // с рынка. Включать осознанно и с малой долей.
    options.tracesSampleRate = 0;

    // Ожидаемый шум до сервера не доходит — см. [isReportableError].
    options.beforeSend = (event, hint) =>
        isReportableError(event.throwable) ? event : null;
  }

  /// Оставляет след в отчёте: что происходило перед падением.
  ///
  /// Ничего не делает без DSN, поэтому вызывать можно откуда угодно, не
  /// оборачивая в проверки.
  static void breadcrumb({
    required String category,
    required String message,
    Map<String, dynamic>? data,
  }) {
    if (!isEnabled) return;
    Sentry.addBreadcrumb(
      Breadcrumb(category: category, message: message, data: data),
    );
  }

  static void _installLocalHandlers() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      _reportZoneError(details.exception, details.stack ?? StackTrace.empty);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _reportZoneError(error, stack);
      return true;
    };
  }

  /// Без DSN отправлять некуда — но и молчать нельзя.
  static void _reportZoneError(Object error, StackTrace stack) {
    if (!isReportableError(error)) return;
    if (kDebugMode) debugPrint('Необработанная ошибка: $error\n$stack');
  }
}

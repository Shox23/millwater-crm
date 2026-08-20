import 'package:crm_millwater/core/observability/observability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('без DSN сборки отчёты никуда не уходят', () {
    // Тесты запускаются без `--dart-define-from-file`, поэтому DSN пуст.
    //
    // Тест сторожит не столько это, сколько обратное: DSN не должен оказаться
    // зашитым в исходники. Мастер настройки Sentry предлагает именно так —
    // и заодно переписывает `main.dart` своим шаблоном, теряя фильтр шума и
    // выключенные PII. Провалившийся тест здесь означает, что кто-то этот
    // мастер запустил.
    expect(Observability.isEnabled, isFalse);
  });

  test('крошка без DSN ничего не делает и не падает', () {
    // Её зовут из интерсептора на каждом запросе — она обязана быть
    // безопасной в сборке без Sentry.
    expect(
      () => Observability.breadcrumb(category: 'http', message: 'GET /admin/customers'),
      returnsNormally,
    );
  });
}

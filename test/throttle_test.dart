import 'package:crm_millwater/core/utils/throttle.dart';
import 'package:flutter_test/flutter_test.dart';

/// Окно намеренно короткое: часы настоящие, а не фейковые — с фейковыми
/// таймеры в этом проекте уже подводили.
const _window = Duration(milliseconds: 60);

Future<void> wait([int windows = 1]) =>
    Future<void>.delayed(_window * windows + const Duration(milliseconds: 20));

void main() {
  late Throttle throttle;
  late List<String> calls;

  setUp(() {
    throttle = Throttle(_window);
    calls = [];
  });

  tearDown(() => throttle.dispose());

  test('первый вызов проходит сразу — оператор видит изменение без задержки',
      () {
    throttle(() => calls.add('первый'));
    expect(calls, ['первый']);
  });

  test('всплеск из десяти событий обходится в две перезагрузки', () async {
    // Ровно случай утреннего часа пик: водители закрывают точки подряд.
    for (var i = 0; i < 10; i++) {
      throttle(() => calls.add('вызов $i'));
    }
    // Первое событие прошло сразу, остальные ждут конца окна.
    expect(calls, ['вызов 0']);

    await wait();
    // Из девяти оставшихся выполнился последний: все они означают одно и
    // то же — «данные устарели».
    expect(calls, ['вызов 0', 'вызов 9']);
  });

  test('поток событий чаще окна не откладывает перезагрузку бесконечно',
      () async {
    // Ради этого взят ограничитель, а не отсрочка: при отсрочке список не
    // обновился бы ни разу, пока события идут.
    for (var i = 0; i < 6; i++) {
      throttle(() => calls.add('вызов $i'));
      await Future<void>.delayed(_window ~/ 2);
    }
    expect(calls.length, greaterThan(1),
        reason: 'перезагрузка ни разу не сработала за три окна');
  });

  test('редкие события проходят каждое', () async {
    throttle(() => calls.add('раз'));
    await wait();
    throttle(() => calls.add('два'));
    expect(calls, ['раз', 'два']);
  });

  test('после dispose отложенный вызов не срабатывает', () async {
    throttle(() => calls.add('первый'));
    throttle(() => calls.add('отложенный'));
    throttle.dispose();

    await wait();
    // Иначе таймер обратился бы к уже закрытому блоку.
    expect(calls, ['первый']);
  });

  test('боевое окно — три секунды', () {
    expect(kNotificationReloadWindow, const Duration(seconds: 3));
  });
}

import 'package:crm_millwater/core/utils/driver_password.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Стартовый пароль водителя', () {
    test('у каждой учётки свой', () {
      // Раньше здесь была константа, одна на всех: пока водитель её не сменил,
      // под его учёткой входил любой, кто знает номер телефона.
      final passwords = {for (var i = 0; i < 200; i++) DriverPassword.generate()};
      expect(passwords, hasLength(200));
    });

    test('не содержит символов, которые путаются при диктовке', () {
      // Пароль передают голосом и переписывают с экрана: «ноль или буква о» —
      // это второй звонок водителю.
      const confusing = ['0', 'O', '1', 'l', 'I', '5', 'S', '8', 'B'];
      for (var i = 0; i < 200; i++) {
        final password = DriverPassword.generate();
        for (final char in confusing) {
          expect(password, isNot(contains(char)),
              reason: 'в пароле "$password" встретился «$char»');
        }
      }
    });

    test('проходит проверку формы: не короче шести символов', () {
      // Форма водителя валидирует пароль правилом `Validators.password()`
      // с минимумом в 6 символов — сгенерированный не должен его нарушать.
      for (var i = 0; i < 50; i++) {
        expect(DriverPassword.generate().length, greaterThanOrEqualTo(6));
      }
    });
  });
}

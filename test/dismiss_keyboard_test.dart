import 'package:crm_millwater/core/widgets/dismiss_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Тап мимо поля убирает клавиатуру.
///
/// Клавиатуры в тестовой среде нет, поэтому проверяется то, чем она
/// управляется: фокус поля и связь с текстовым вводом. Снят фокус — движок
/// прячет клавиатуру.
void main() {
  late FocusNode node;

  setUp(() => node = FocusNode());
  tearDown(() => node.dispose());

  Future<void> pump(WidgetTester tester, {VoidCallback? onButton}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DismissKeyboardOnTapOutside(
          child: Scaffold(
            body: Column(
              children: [
                TextField(key: const Key('field'), focusNode: node),
                ElevatedButton(
                  key: const Key('button'),
                  onPressed: onButton ?? () {},
                  child: const Text('Кнопка'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('тап по пустому месту снимает фокус с поля', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(node.hasFocus, isTrue, reason: 'поле в фокусе до тапа мимо');
    expect(tester.testTextInput.isVisible, isTrue);

    // Пустое место ниже формы: там нет ничего, кроме обёртки.
    await tester.tapAt(const Offset(400, 500));
    await tester.pump();

    expect(node.hasFocus, isFalse,
        reason: 'после тапа мимо фокус с поля должен сняться');
    expect(tester.testTextInput.isVisible, isFalse,
        reason: 'снятый фокус закрывает клавиатуру');
  });

  testWidgets('нажатие на кнопку не перехватывается обёрткой', (tester) async {
    var pressed = 0;
    await pump(tester, onButton: () => pressed++);

    await tester.tap(find.byKey(const Key('button')));
    await tester.pump();

    expect(pressed, 1, reason: 'обёртка не должна съедать нажатия кнопок');
  });
}

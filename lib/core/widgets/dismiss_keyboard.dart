import 'package:flutter/material.dart';

/// Снимает фокус — и убирает клавиатуру — по тапу мимо поля ввода.
///
/// Ставится один раз над всем приложением (`MaterialApp.builder`), а не на
/// каждой форме: клавиатура закрывает нижнюю часть экрана одинаково везде, и
/// на формах с полем внизу (вход, расход, опт) за ней остаются ровно те итог
/// и кнопка, ради которых её и закрывают.
///
/// [HitTestBehavior.translucent], а не opaque: жест участвует в арене наравне
/// с остальными, и внутренние распознаватели — кнопки, карточки, прокрутка —
/// выигрывают его как более глубокие. То есть обычные нажатия сюда не
/// проваливаются, а до этого обработчика доходит только тап по пустому месту.
class DismissKeyboardOnTapOutside extends StatelessWidget {
  const DismissKeyboardOnTapOutside({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // primaryFocus, а не FocusScope.of(context): контекст здесь лежит НАД
      // Navigator, и его FocusScope к полю на текущем экране отношения не
      // имеет — unfocus по нему клавиатуру не убирает.
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

/// Строка «иконка человека + имя заказчика» под названием в карточке —
/// в одном стиле со строкой адреса.
///
/// Имя (`customer_name`) — контактное лицо: к кому обращаться на месте и
/// по телефону. У заказчиков, заведённых до 07.11.26, его нет, и тогда
/// строку не ставят вовсе (`if (name != null) ContactNameLine(name)`):
/// «не указано» в каждой второй карточке списка было бы шумом, а пустой
/// виджет в `Column` со `spacing` всё равно оставил бы зазор.
class ContactNameLine extends StatelessWidget {
  const ContactNameLine(this.name, {super.key, this.style});

  final String name;

  /// Стиль текста; по умолчанию — вторичный, как у адреса в карточках.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      spacing: 4,
      children: [
        Icon(Icons.person_outline, size: 15, color: t.text2),
        Expanded(
          child: Text(
            name,
            style: style ?? AppTypography.secondary.copyWith(color: t.text2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

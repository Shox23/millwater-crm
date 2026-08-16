import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

/// Шапка списочного экрана: капс-подпись, крупный заголовок и слот действия.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.label,
    required this.title,
    this.action,
  });

  final String label;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTypography.sectionLabel.copyWith(color: t.primary),
              ),
              // Заголовок ужимается, только если не влезает в остаток строки.
              // Слово длиннее русского («Marshrutlar» против «Маршруты») или
              // вторая кнопка справа съедали ширину, и заголовок переносился
              // посреди слова. Перенос запрещаем, кегль отдаём на откуп
              // ширине — при системном увеличении шрифта это тоже спасает.
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    style: AppTypography.screenTitle.copyWith(color: t.text),
                  ),
                ),
              ),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

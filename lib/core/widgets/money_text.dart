import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import '../utils/money_formatter.dart';

/// Денежная сумма: число заметное, «сум» — приглушённая приписка.
class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.amount,
    this.numberStyle,
    this.color,
    this.currencyColor,
  });

  final num amount;
  final TextStyle? numberStyle;
  final Color? color;
  final Color? currencyColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = numberStyle ?? AppTypography.money;
    final numStyle = base.copyWith(color: color ?? base.color ?? t.text);
    final curStyle = numStyle.copyWith(
      fontSize: (numStyle.fontSize ?? 16) * 0.7,
      color: currencyColor ?? t.text2,
      fontWeight: FontWeight.w600,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: MoneyFormatter.amount(amount), style: numStyle),
          TextSpan(text: ' ${context.l10n.commonSum}', style: curStyle),
        ],
      ),
    );
  }
}

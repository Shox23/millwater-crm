import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../data/models/reports_summary.dart';

/// Карточка «Выручка за неделю» со столбчатым графиком.
class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({
    super.key,
    required this.bars,
    required this.total,
    required this.changePct,
  });

  final List<WeeklyBar> bars;
  final int total;
  final int changePct;

  static const double _maxBarHeight = 96;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxValue = bars.isEmpty
        ? 1
        : bars.map((b) => b.value).reduce((a, b) => a > b ? a : b);
    final activeIndex = bars.length - 1;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text('Выручка за неделю',
                        style:
                            AppTypography.bodyStrong.copyWith(color: t.text)),
                    Text('${MoneyFormatter.compactSum(total)} собрано',
                        style:
                            AppTypography.secondary.copyWith(color: t.text2)),
                  ],
                ),
              ),
              StatusBadge(text: '+$changePct%', tone: StatusTone.success),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < bars.length; i++)
                Expanded(
                  child: _Bar(
                    bar: bars[i],
                    heightFactor: bars[i].value / maxValue,
                    maxHeight: _maxBarHeight,
                    active: i == activeIndex,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.bar,
    required this.heightFactor,
    required this.maxHeight,
    required this.active,
  });

  final WeeklyBar bar;
  final double heightFactor;
  final double maxHeight;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = active ? t.primary : t.surface3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(
          '${(bar.value / 1000).round()}',
          style: AppTypography.secondary.copyWith(
            fontWeight: FontWeight.w700,
            color: active ? t.primary : t.text2,
          ),
        ),
        Container(
          width: 30,
          height: (maxHeight * heightFactor).clamp(8, maxHeight),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        Text(bar.label,
            style: AppTypography.secondary.copyWith(color: t.text2)),
      ],
    );
  }
}

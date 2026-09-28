import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/product_config.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/route_draft.dart';

/// Итоги собираемого маршрута: точки, капсулы и деньги.
///
/// Стоят перед кнопкой создания и видны всегда: маршрут сдают водителю
/// вместе с погрузкой, и «сколько всего капсул» — первое, что спрашивают.
/// Значения производные (см. [RouteDraft.totals]), своего состояния нет.
class RouteCreateTotals extends StatelessWidget {
  const RouteCreateTotals({
    super.key,
    required this.totals,
    this.capacity = ProductConfig.vehicleCapsuleCapacity,
  });

  final RouteDraftTotals totals;

  /// Сколько капсул везёт машина: выше — предупреждающий цвет.
  final int capacity;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final over = totals.exceedsCapacity(capacity);

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Stat(label: l10n.routeCreateTotalStops, value: '${totals.stops}'),
        _Divider(color: t.border),
        Tooltip(
          message: over ? l10n.routeCreateOverCapacity(capacity) : '',
          child: _Stat(
            label: l10n.routeCreateTotalCapsules(
              '${ProductConfig.capsuleVolumeLiters}',
            ),
            value: '${totals.capsules}',
            color: over ? t.warn : null,
          ),
        ),
        _Divider(color: t.border),
        _Stat(
          label: l10n.routeCreateTotalMoney,
          value: MoneyFormatter.sum(l10n, totals.money),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Text(label, style: AppTypography.badge.copyWith(color: t.text2)),
        Text(value, style: AppTypography.money.copyWith(color: color ?? t.text)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: color);
}

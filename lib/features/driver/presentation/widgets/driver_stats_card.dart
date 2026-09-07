import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/utils/stats_period.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/segmented_toggle.dart';
import '../../../../data/models/order.dart';
import '../../../../data/models/route_from_orders.dart';
import '../../../../data/repositories/driver_repository.dart';

/// Что водитель сделал за период: капсулы, опт и расходы.
///
/// Считается по его собственным данным — `/driver/orders` и расходам его
/// маршрутов. Готового отчёта водителю не положено: `/admin/reports/drivers`
/// закрыт админской ролью, и под водительским токеном отвечает 403.
class DriverStatsCard extends StatefulWidget {
  const DriverStatsCard({super.key});

  @override
  State<DriverStatsCard> createState() => _DriverStatsCardState();
}

class _DriverStatsCardState extends State<DriverStatsCard> {
  StatsPeriod _period = StatsPeriod.month;

  bool _loading = true;
  bool _failed = false;

  int _capsules = 0;
  int _bulk5l = 0;
  int _bulk10l = 0;
  int _expenses = 0;

  /// Номер последнего запроса: переключая период тремя тапами, легко получить
  /// ответы вразнобой — медленный первый лёг бы поверх последнего.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _failed = false;
    });

    final repo = context.read<DriverRepository>();
    final (from, to) = _period.range;

    try {
      // Заказы за период — постранично, как везде: сотня в ответе не предел.
      final orders = <Order>[];
      for (var page = 1; page <= 20; page++) {
        final chunk =
            await repo.getMyOrders(page: page, dateFrom: from, dateTo: to);
        orders.addAll(chunk.items);
        if (!chunk.hasMore) break;
      }

      // Расходы лежат у маршрутов, а не у заказов, — по запросу на маршрут.
      // Дорого, но иначе никак: суммы расходов за период сервер водителю не
      // отдаёт. Экран открывают по требованию, а не при каждом запуске.
      var spent = 0;
      for (final group in groupByRoute(orders)) {
        final routeId = group.first.routeId;
        if (routeId == null) continue;
        final expenses = await repo.getRouteExpenses(routeId);
        spent += expenses.fold<int>(0, (sum, e) => sum + e.amount);
      }

      if (id != _requestId || !mounted) return;
      setState(() {
        _capsules =
            orders.fold<int>(0, (sum, o) => sum + (o.deliveredCapsules ?? 0));
        _bulk5l = orders.fold<int>(0, (sum, o) => sum + (o.bulk5lCount ?? 0));
        _bulk10l = orders.fold<int>(0, (sum, o) => sum + (o.bulk10lCount ?? 0));
        _expenses = spent;
        _loading = false;
      });
    } catch (_) {
      if (id != _requestId || !mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;

    return Column(
      spacing: AppSpacing.sm,
      children: [
        SegmentedToggle<StatsPeriod>(
          options: [
            for (final period in StatsPeriod.values)
              SegmentOption(value: period, label: period.label(l10n)),
          ],
          value: _period,
          columns: 3,
          onChanged: _loading
              ? (_) {}
              : (period) {
                  setState(() => _period = period);
                  _load();
                },
        ),
        AppCard(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _failed
                  ? Text(l10n.profileStatsFailed,
                      style: AppTypography.secondary.copyWith(color: t.text2))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: AppSpacing.md,
                      children: [
                        _StatRow(
                          label: l10n.profileStatsCapsules,
                          value: '$_capsules',
                        ),
                        _StatRow(
                          label: l10n.profileStatsBulk,
                          value: l10n.profileStatsBulkValue(_bulk5l, _bulk10l),
                        ),
                        _StatRow(
                          label: l10n.profileStatsExpenses,
                          value: MoneyFormatter.sum(l10n, _expenses),
                          color: _expenses > 0 ? t.danger : null,
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppTypography.secondary.copyWith(color: t.text2)),
        ),
        Text(value,
            style: AppTypography.bodyStrong.copyWith(color: color ?? t.text)),
      ],
    );
  }
}

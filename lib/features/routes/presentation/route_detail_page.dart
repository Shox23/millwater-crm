import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/route_models.dart';
import '../../../data/repositories/crm_repository.dart';
import 'delivery_completion_page.dart';
import 'widgets/route_card.dart';

/// Экран «Карточка маршрута»: водитель, прогресс и список точек.
class RouteDetailPage extends StatefulWidget {
  const RouteDetailPage({super.key, required this.routeId});

  final String routeId;

  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage> {
  RouteDetail? _route;
  bool _loading = true;
  bool _loadFailed = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final route =
          await context.read<CrmRepository>().getRoute(widget.routeId);
      if (!mounted) return;
      setState(() {
        _route = route;
        _loading = false;
      });
    } catch (_) {
      // Ошибка сети — не то же самое, что «маршрут не найден».
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _cancelRoute() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Отменить маршрут?',
      message: 'Маршрут будет помечен как отменённый.',
      confirmLabel: 'Отменить маршрут',
    );
    if (!confirmed || !mounted) return;
    final repo = context.read<CrmRepository>();
    final ok = await runGuarded(
      context,
      () => repo.cancelRoute(widget.routeId),
      fallback: 'Не удалось отменить маршрут.',
    );
    if (!ok || !mounted) return;
    _changed = true;
    showAppSnackBar(context, 'Маршрут отменён');
    await _load();
  }

  Future<void> _openStop(RouteStop stop) async {
    final done = await Navigator.of(context).push<bool>(
      OverlayPageRoute(builder: (_) => DeliveryCompletionPage(stop: stop)),
    );
    if (done == true) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final route = _route;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: DetailScaffold(
        title: 'Карточка маршрута',
        body: _loading
            ? const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            : _loadFailed
                ? Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: ErrorRetryView(
                      onRetry: _load,
                      message: 'Не удалось загрузить маршрут',
                    ),
                  )
                : route == null
                    ? Center(
                        child: Text('Маршрут не найден',
                            style: AppTypography.secondary
                                .copyWith(color: t.text2)),
                      )
                    : _RouteBody(route: route, onStopTap: _openStop),
        bottomBar: _loadFailed ||
                route == null ||
                route.status == RouteStatus.cancelled
            ? null
            : BottomActionBar(
                child: AppButton(
                  label: 'Отменить маршрут',
                  variant: AppButtonVariant.secondary,
                  onPressed: _cancelRoute,
                ),
              ),
      ),
    );
  }
}

class _RouteBody extends StatelessWidget {
  const _RouteBody({required this.route, required this.onStopTap});

  final RouteDetail route;
  final ValueChanged<RouteStop> onStopTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.lg,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.md,
            children: [
              Row(
                spacing: AppSpacing.sm,
                children: [
                  StatusBadge(
                    text: route.status.label,
                    tone: routeTone(route.status),
                  ),
                  const Spacer(),
                  Text(DateFormat('dd.MM.yyyy').format(route.date),
                      style: AppTypography.secondary.copyWith(color: t.text2)),
                ],
              ),
              Row(
                spacing: AppSpacing.md,
                children: [
                  InitialsAvatar(name: route.driverFullName, size: 46),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text('Водитель',
                            style: AppTypography.secondary
                                .copyWith(color: t.text2)),
                        Text(route.driverFullName,
                            style: AppTypography.bodyStrong
                                .copyWith(color: t.text)),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                spacing: AppSpacing.md,
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'ВЫПОЛНЕНО',
                      value: '${route.completedCount} / ${route.totalCustomers}',
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: 'СОБРАНО',
                      value: MoneyFormatter.sum(route.collected),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Text('ТОЧКИ МАРШРУТА',
                style: AppTypography.fieldLabel.copyWith(color: t.text2)),
            for (final stop in route.stops)
              _StopCard(stop: stop, onTap: () => onStopTap(stop)),
          ],
        ),
      ],
    );
  }
}

/// Карточка одной точки маршрута.
class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop, required this.onTap});

  final RouteStop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      onTap: stop.isCompleted ? null : onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Row(
            spacing: AppSpacing.sm,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: deliveryColor(context, stop.status),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(stop.customerName,
                    style: AppTypography.cardTitle.copyWith(color: t.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              StatusBadge(
                text: stop.status.label,
                tone: deliveryTone(stop.status),
              ),
            ],
          ),
          Row(
            spacing: 4,
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: t.text2),
              Expanded(
                child: Text(stop.customerAddress,
                    style: AppTypography.secondary.copyWith(color: t.text2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (stop.isCompleted) ...[
            const Divider(),
            Row(
              children: [
                Text('${stop.deliveredCapsules ?? 0} капсул',
                    style: AppTypography.secondary.copyWith(color: t.text2)),
                const Spacer(),
                Text(
                  MoneyFormatter.sum(stop.paymentAmount ?? 0),
                  style: AppTypography.money.copyWith(color: t.success),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Мини-карточка со значением на приглушённой поверхности.
class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(label, style: AppTypography.fieldLabel.copyWith(color: t.text2)),
          Text(value, style: AppTypography.bodyStrong.copyWith(color: t.text)),
        ],
      ),
    );
  }
}

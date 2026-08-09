import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/route_models.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../routes/presentation/widgets/build_route_section.dart';
import '../../routes/presentation/widgets/route_card.dart';
import '../../routes/presentation/widgets/stop_card.dart';
import 'delivery_completion_page.dart';

/// Карточка своего маршрута: прогресс и точки с действиями.
class MyRouteDetailPage extends StatefulWidget {
  const MyRouteDetailPage({super.key, required this.routeId});

  final String routeId;

  @override
  State<MyRouteDetailPage> createState() => _MyRouteDetailPageState();
}

class _MyRouteDetailPageState extends State<MyRouteDetailPage> {
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
          await context.read<DriverRepository>().getMyRoute(widget.routeId);
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

  Future<void> _openCompletion(RouteStop stop) async {
    final done = await Navigator.of(context).push<bool>(
      OverlayPageRoute(builder: (_) => DeliveryCompletionPage(stop: stop)),
    );
    if (done == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _setStatus(RouteStop stop, DeliveryStatus status) async {
    final repo = context.read<DriverRepository>();
    final ok = await runGuarded(
      context,
      () => repo.updateDeliveryStatus(stopId: stop.id, status: status),
      fallback: context.l10n.myRouteStatusFailed,
    );
    if (!ok || !mounted) return;
    _changed = true;
    showAppSnackBar(context, context.l10n.myRouteStatusChanged(status.label(context.l10n)));
    await _load();
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
        title: context.l10n.myRouteTitle,
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
                      message: context.l10n.routeLoadFailed,
                    ),
                  )
                : route == null
                    ? Center(
                        child: Text(context.l10n.routeNotFound,
                            style: AppTypography.secondary
                                .copyWith(color: t.text2)),
                      )
                    : _Body(
                        route: route,
                        onComplete: _openCompletion,
                        onStatus: _setStatus,
                      ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.route,
    required this.onComplete,
    required this.onStatus,
  });

  final RouteDetail route;
  final ValueChanged<RouteStop> onComplete;
  final void Function(RouteStop, DeliveryStatus) onStatus;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final progress = route.totalCustomers == 0
        ? 0.0
        : route.completedCount / route.totalCustomers;

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
                    text: route.status.label(context.l10n),
                    tone: routeTone(route.status),
                  ),
                  const Spacer(),
                  Text(DateFormat('dd.MM.yyyy').format(route.date),
                      style: AppTypography.secondary.copyWith(color: t.text2)),
                ],
              ),
              Row(
                children: [
                  Text(context.l10n.commonDone,
                      style: AppTypography.secondary.copyWith(color: t.text2)),
                  const Spacer(),
                  Text('${route.completedCount} / ${route.totalCustomers}',
                      style: AppTypography.bodyStrong.copyWith(color: t.text)),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: t.surface2,
                  valueColor: AlwaysStoppedAnimation(t.primary),
                ),
              ),
            ],
          ),
        ),
        BuildRouteSection(stops: route.stops),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Text(context.l10n.routeStops,
                style: AppTypography.fieldLabel.copyWith(color: t.text2)),
            for (final stop in route.stops)
              StopCard(
                stop: stop,
                onTap: stop.isCompleted ? null : () => onComplete(stop),
                trailing: stop.isCompleted
                    ? null
                    : _StatusMenu(
                        current: stop.status,
                        onSelected: (s) => onStatus(stop, s),
                      ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Смена статуса точки без захода в завершение доставки.
class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.current, required this.onSelected});

  final DeliveryStatus current;
  final ValueChanged<DeliveryStatus> onSelected;

  /// Завершение проводится отдельным экраном (нужны капсулы и сумма),
  /// поэтому здесь только промежуточные статусы.
  static const _options = [DeliveryStatus.onWay, DeliveryStatus.failed];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopupMenuButton<DeliveryStatus>(
      onSelected: onSelected,
      color: t.surface,
      tooltip: context.l10n.myRouteChangeStatus,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      itemBuilder: (context) => [
        for (final s in _options)
          PopupMenuItem(
            value: s,
            enabled: s != current,
            child: Text(s.label(context.l10n), style: TextStyle(color: t.text)),
          ),
      ],
      child: Icon(Icons.more_vert, size: 20, color: t.text2),
    );
  }
}

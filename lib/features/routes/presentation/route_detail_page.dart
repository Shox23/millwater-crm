import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/notifications_scope.dart';
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
import '../../../data/models/notification_event.dart';
import '../../../data/models/route_models.dart';
import '../../../data/repositories/crm_repository.dart';
import 'route_form_page.dart';
import 'stop_detail_page.dart';
import 'widgets/route_card.dart';
import 'widgets/stop_card.dart';

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
  StreamSubscription<NotificationEvent>? _notifications;

  @override
  void initState() {
    super.initState();
    _load();
    // Водитель тронулся или закрыл точку — карточка обновляется сама.
    // Чужие маршруты пропускаем: их перечитает список, когда до него дойдёт
    // очередь, а здесь лишний запрос ничего на экране не изменит.
    _notifications = context.notificationEvents
        ?.where((e) => e.routeId == widget.routeId)
        .listen((_) => _load(silent: true));
  }

  @override
  void dispose() {
    _notifications?.cancel();
    super.dispose();
  }

  /// [silent] — обновление по уведомлению, а не по действию пользователя.
  Future<void> _load({bool silent = false}) async {
    // Фоновое обновление не гасит карточку спиннером: на неё в этот момент
    // смотрят, и подмена содержимого индикатором читается как сбой.
    if (!silent) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
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
      // Неудачное фоновое обновление оставляет то, что уже показано:
      // менять живую карточку на экран ошибки никто не просил.
      if (silent) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _cancelRoute() async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.routeCancelTitle,
      message: context.l10n.routeCancelMessage,
      confirmLabel: context.l10n.routeCancelAction,
    );
    if (!confirmed || !mounted) return;
    final repo = context.read<CrmRepository>();
    final ok = await runGuarded(
      context,
      () => repo.cancelRoute(widget.routeId),
      fallback: context.l10n.routeCancelFailed,
    );
    if (!ok || !mounted) return;
    _changed = true;
    showAppSnackBar(context, context.l10n.routeCancelled2);
    await _load();
  }

  /// Открывает форму правки и перечитывает маршрут, если что-то поменялось.
  ///
  /// Перечитываем всегда, а не достраиваем состояние из формы: правки
  /// применяются по одной, и при отказе на середине часть из них уже на
  /// сервере — единственный источник правды теперь там.
  Future<void> _editRoute(RouteDetail route) async {
    final saved = await Navigator.of(context).push<bool>(
      OverlayPageRoute<bool>(builder: (_) => RouteFormPage(route: route)),
    );
    if (saved != true || !mounted) return;
    _changed = true;
    await _load();
  }

  /// Админу точка доступна только на просмотр: завершение доставки —
  /// driver-эндпоинт, под админским токеном он отвечает 403.
  void _openStop(RouteStop stop) {
    Navigator.of(context).push(
      OverlayPageRoute<void>(builder: (_) => StopDetailPage(stop: stop)),
    );
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
        title: context.l10n.routeCardTitle,
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
                    : _RouteBody(route: route, onStopTap: _openStop),
        // Панель целиком исчезает, когда с маршрутом уже нечего делать:
        // у завершённого и отменённого не осталось ни правок, ни отмены.
        bottomBar: _loadFailed ||
                route == null ||
                !(route.status.canCancel || route.status.isEditable)
            ? null
            : BottomActionBar(
                child: Row(
                  spacing: AppSpacing.md,
                  children: [
                    if (route.status.canCancel)
                      Expanded(
                        child: AppButton(
                          label: context.l10n.routeCancelAction,
                          variant: AppButtonVariant.secondary,
                          onPressed: _cancelRoute,
                        ),
                      ),
                    // Завершённый маршрут править нечего — кнопки нет вовсе.
                    if (route.status.isEditable)
                      Expanded(
                        child: AppButton(
                          label: context.l10n.commonEdit,
                          onPressed: () => _editRoute(route),
                        ),
                      ),
                  ],
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
    final driverName = route.driverFullName ?? '—';

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
                spacing: AppSpacing.md,
                children: [
                  // Админский ответ водителя всегда содержит; `?? '—'` —
                  // страховка от неполных данных, а не рабочий сценарий.
                  InitialsAvatar(name: driverName, size: 46),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(context.l10n.driverTitle,
                            style: AppTypography.secondary
                                .copyWith(color: t.text2)),
                        Text(driverName,
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
                      label: context.l10n.routeStatDone,
                      value: '${route.completedCount} / ${route.totalCustomers}',
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: context.l10n.routeStatCollected,
                      value: MoneyFormatter.sum(context.l10n, route.collected),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Построения маршрута здесь нет намеренно: маршрут строится от
        // текущего места того, кто нажал кнопку, а админ по нему не едет —
        // ему бы прокладывало путь из офиса. Блок живёт в карточке водителя.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Text(context.l10n.routeStops,
                style: AppTypography.fieldLabel.copyWith(color: t.text2)),
            for (final stop in route.stops)
              StopCard(stop: stop, onTap: () => onStopTap(stop)),
          ],
        ),
      ],
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

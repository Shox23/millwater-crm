import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/utils/day.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/section_block.dart';
import '../../../data/models/order.dart';
import '../../../data/models/route_models.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/crm_repository.dart';

/// Перенос заказа: дата и маршрут, в который он уедет.
///
/// Отдельный экран, а не шторка: в приложении шторок нет вовсе, всё, что
/// требует ввода, живёт оверлейной страницей — и уход с неё уже умеет
/// переспрашивать и показывать ошибку сервера.
///
/// Сервер принимает ровно один вариант из двух: либо маршрут, либо дата (и
/// тогда он сам найдёт маршрут этой даты, а не найдя — заведёт новый **без
/// водителя**). Экран поэтому и устроен как выбор: сначала день, потом один
/// из его маршрутов или «Новый маршрут».
class MoveOrderPage extends StatefulWidget {
  const MoveOrderPage({super.key, required this.order});

  final Order order;

  @override
  State<MoveOrderPage> createState() => _MoveOrderPageState();
}

class _MoveOrderPageState extends State<MoveOrderPage> with SubmitState {
  late DateTime _date;

  /// Выбранный маршрут; `null` — «Новый маршрут», перенос по дате.
  RouteListItem? _route;

  List<RouteListItem> _routes = const [];
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    // Начинаем с сегодняшнего дня, а не с даты заказа: дату в прошлом сервер
    // отвергает (422 DATE_IN_PAST), а заказ вполне может быть вчерашним.
    final today = dayOnly(DateTime.now());
    final current = widget.order.routeDate;
    _date = (current == null || current.isBefore(today)) ? today : current;
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final routes = await context
          .read<CrmRepository>()
          .getRoutes(dateFrom: _date, dateTo: _date);
      if (!mounted) return;
      setState(() {
        // Маршрут, в котором заказ уже лежит, выбирать незачем: сервер такой
        // перенос сочтёт переносом в тот же маршрут.
        _routes =
            routes.where((r) => r.id != widget.order.routeId).toList();
        _route = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _pickDate() async {
    final today = dayOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // Прошлое сервер не примет — календарь туда и не пускает.
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _date = dayOnly(picked));
    await _loadRoutes();
  }

  Future<void> _submit() async {
    final repo = context.read<CrmRepository>();
    // Строки берём до запроса: после await контекст уже мог уйти.
    final l10n = context.l10n;
    final route = _route;

    final moved = await submit(
      () => route == null
          ? repo.moveOrderToDate(orderId: widget.order.id, date: _date)
          : repo.moveOrderToRoute(
              orderId: widget.order.id,
              targetRouteId: route.id,
            ),
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.orderMoveFailed)
          : l10n.orderMoveFailed,
    );

    if (moved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;

    return DetailScaffold(
      title: l10n.orderMoveTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          AppCard(
            onTap: submitting ? null : _pickDate,
            child: Row(
              spacing: AppSpacing.md,
              children: [
                Icon(Icons.event_outlined, size: 20, color: t.primary),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        l10n.orderMoveDate,
                        style:
                            AppTypography.secondary.copyWith(color: t.text2),
                      ),
                      Text(
                        DateFormat('dd.MM.yyyy').format(_date),
                        style:
                            AppTypography.bodyStrong.copyWith(color: t.text),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: t.text3),
              ],
            ),
          ),
          SectionBlock(
            label: l10n.orderMoveRoutes,
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.md,
                    children: [
                      if (_loadFailed)
                        Text(
                          l10n.orderMoveRoutesFailed,
                          style: AppTypography.secondary
                              .copyWith(color: t.danger),
                        )
                      else if (_routes.isEmpty)
                        Text(
                          l10n.orderMoveNoRoutes,
                          style:
                              AppTypography.secondary.copyWith(color: t.text2),
                        ),
                      for (final route in _routes)
                        _RouteOption(
                          route: route,
                          selected: _route?.id == route.id,
                          onTap: submitting
                              ? null
                              : () => setState(() => _route = route),
                        ),
                      _NewRouteOption(
                        selected: _route == null,
                        onTap: submitting
                            ? null
                            : () => setState(() => _route = null),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      bottomBar: BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.md,
          children: [
            if (submitError != null)
              Text(
                submitError!,
                style: AppTypography.secondary.copyWith(color: t.danger),
                textAlign: TextAlign.center,
              ),
            AppButton(
              label: submitting ? l10n.commonSaving : l10n.orderMoveAction,
              enabled: !submitting && !_loading,
              onPressed: (submitting || _loading) ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Существующий маршрут выбранного дня.
class _RouteOption extends StatelessWidget {
  const _RouteOption({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final RouteListItem route;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return AppCard(
      onTap: onTap,
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 20,
            color: selected ? t.primary : t.text3,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  l10n.orderRouteStops(
                    route.totalCustomers,
                    // Маршрут без водителя — рабочее состояние: сервер
                    // разрешает такие заводить.
                    route.driverFullName ?? l10n.orderNoDriverShort,
                  ),
                  style: AppTypography.bodyStrong.copyWith(color: t.text),
                ),
                Text(
                  route.status.label(l10n),
                  style: AppTypography.secondary.copyWith(color: t.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «Новый маршрут» — перенос по дате.
class _NewRouteOption extends StatelessWidget {
  const _NewRouteOption({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Row(
            spacing: AppSpacing.md,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? t.primary : t.text3,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      l10n.orderMoveNewRoute,
                      style: AppTypography.bodyStrong.copyWith(color: t.text),
                    ),
                    Text(
                      l10n.orderMoveNewRouteHint,
                      style: AppTypography.secondary.copyWith(color: t.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Предупреждение видно до отправки, а не после: заказ уедет в
          // маршрут, который некому везти, и узнать об этом из карточки
          // заказчика — поздно.
          if (selected) const _NoDriverWarning(),
        ],
      ),
    );
  }
}

/// Предупреждение под «Новым маршрутом».
///
/// Блоком, а не статус-пилюлей: пилюля не переносит строку, и фраза целиком
/// не помещалась по ширине ни на одном телефоне — правый край просто
/// обрезался. Форма та же, что у предупреждения на экране завершения
/// доставки.
class _NoDriverWarning extends StatelessWidget {
  const _NoDriverWarning();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.warnBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        spacing: AppSpacing.sm,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: t.warn),
          Expanded(
            child: Text(
              context.l10n.orderMoveNoDriver,
              style: AppTypography.secondary.copyWith(color: t.warn),
            ),
          ),
        ],
      ),
    );
  }
}

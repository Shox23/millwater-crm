import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/notifications_scope.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/utils/idempotency.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/route_cash_card.dart';
import '../../../core/widgets/section_block.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/enums.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/models/notification_event.dart';
import '../../../data/models/order.dart';
import '../../../data/models/route_expense.dart';
import '../../../data/models/route_models.dart';
import '../../../data/repositories/crm_repository.dart';
import '../../orders/presentation/order_detail_page.dart';
import '../../orders/presentation/widgets/order_expectations.dart';
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

  /// Расходы водителя по маршруту. Отдельным запросом: в ответе маршрута их
  /// нет, есть только итоговая сумма в блоке кассы.
  List<RouteExpense> _expenses = const [];
  bool _loading = true;
  bool _loadFailed = false;
  StreamSubscription<NotificationEvent>? _notifications;

  /// Ключ завершения маршрута — один на карточку: повтор после обрыва связи
  /// уходит с тем же ключом и не упирается в 409 от уже прошедшего запроса.
  final String _completionKey = newIdempotencyKey('route-complete');

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
      final repo = context.read<CrmRepository>();
      final route = await repo.getRoute(widget.routeId);
      // Расходы грузим отдельно и не роняем ими карточку: маршрут без списка
      // расходов показать можно, а без маршрута список расходов бессмыслен.
      final expenses = await repo
          .getRouteExpenses(widget.routeId)
          .catchError((_) => const <RouteExpense>[]);
      if (!mounted) return;
      setState(() {
        _route = route;
        _expenses = expenses;
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
    showAppSnackBar(context, context.l10n.routeCancelled2);
    await _load();
  }

  /// Завершение маршрута: точки, до которых водитель не доехал, сервер
  /// отменит, поэтому диалог называет их число — админ должен видеть, что
  /// именно он сейчас закрывает, а не только «маршрут».
  Future<void> _completeRoute(RouteDetail route) async {
    final open = route.stops.where((s) => s.status.isOpen).length;
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.routeCompleteTitle,
      message: open == 0
          ? context.l10n.routeCompleteMessage
          : context.l10n.routeCompleteMessageOpen(open),
      confirmLabel: context.l10n.routeCompleteAction,
      destructive: false,
    );
    if (!confirmed || !mounted) return;
    final repo = context.read<CrmRepository>();
    // Строки берём до запроса: после await контекст уже мог уйти.
    final l10n = context.l10n;
    try {
      await repo.completeRoute(widget.routeId, idempotencyKey: _completionKey);
    } on DioException catch (e) {
      if (!mounted) return;
      // 409 у этой ручки один: маршрут уже не в работе — его закрыли с
      // другого устройства. Общий разбор кода (`ORDER_ALREADY_COMPLETED`)
      // сказал бы «заказ», поэтому подпись своя, а карточка перечитывается:
      // на экране она всё ещё «В пути».
      final conflict = e.response?.statusCode == 409;
      showAppSnackBar(
        context,
        conflict
            ? l10n.errorRouteCompleted
            : apiErrorMessage(l10n, e, fallback: l10n.routeCompleteFailed),
        isError: true,
      );
      if (conflict) await _load();
      return;
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, l10n.routeCompleteFailed, isError: true);
      }
      return;
    }
    if (!mounted) return;
    showAppSnackBar(context, l10n.routeCompleted2);
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
    await _load();
  }

  /// Открывает точку карточкой заказа.
  ///
  /// Точка маршрута и заказ — одна и та же запись (`stop.id` это `order.id`),
  /// но карточка заказа знает про неё больше: цель, брак и возврат, опт,
  /// историю платежей, перенос и правку оплаты. Дублировать всё это в
  /// карточке точки значило бы вести два экрана про одно.
  ///
  /// Если заказ не пришёл — старый стенд без `/admin/orders/{id}` или сеть —
  /// остаётся прежняя карточка точки: она собрана из данных маршрута и
  /// показывается без единого запроса.
  Future<void> _openStop(RouteStop stop) async {
    final repo = context.read<CrmRepository>();
    Order? order;
    try {
      order = await repo.getOrder(stop.id);
    } catch (_) {
      // Молча: ниже открывается запасная карточка.
    }
    if (!mounted) return;

    final loaded = order;
    final changed = await Navigator.of(context).push<bool>(
      OverlayPageRoute<bool>(
        builder: (_) => loaded == null
            ? StopDetailPage(stop: stop)
            : OrderDetailPage(
                order: loaded,
                canManage: true,
                onCancel: (reason) =>
                    repo.cancelOrder(orderId: loaded.id, reason: reason),
              ),
      ),
    );
    // Перенос или правка оплаты меняют маршрут — перечитываем его целиком.
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final route = _route;

    return DetailScaffold(
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
                  : _RouteBody(
                      route: route,
                      expenses: _expenses,
                      onStopTap: _openStop,
                      onAssignDriver: _editRoute,
                    ),
      // Панель целиком исчезает, когда с маршрутом уже нечего делать:
      // у завершённого и отменённого не осталось ни правок, ни отмены.
      bottomBar: _loadFailed ||
              route == null ||
              !(route.status.canCancel ||
                  route.status.canComplete ||
                  route.status.isEditable)
          ? null
          : BottomActionBar(
              // «Изменить» — своей строкой на всю ширину, под ней в ряд
              // «Отменить» и «Завершить»: три кнопки в одну строку на
              // телефоне не помещаются, а правка — действие другого рода,
              // чем два закрывающих маршрут.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                // Кнопка сама ширину не задаёт — растягиваем её колонкой.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.md,
                children: [
                  if (route.awaitsCompletion)
                    Text(
                      context.l10n.routeAwaitsCompletion,
                      textAlign: TextAlign.center,
                      style: AppTypography.secondary.copyWith(color: t.text2),
                    ),
                  // Завершённый маршрут править нечего — кнопки нет вовсе.
                  if (route.status.isEditable)
                    AppButton(
                      label: context.l10n.commonEdit,
                      onPressed: () => _editRoute(route),
                    ),
                  if (route.status.canCancel || route.status.canComplete)
                    Row(
                      spacing: AppSpacing.md,
                      children: [
                        if (route.status.canCancel)
                          Expanded(
                            child: AppButton(
                              // Короткая подпись: на половине ширины
                              // «Отменить маршрут» обрезалось до «Отменить
                              // ма…», а узбекское «Marshrutni bekor qilish»
                              // и подавно. Слово «маршрут» здесь и так из
                              // контекста экрана, а полностью действие
                              // называет диалог подтверждения.
                              label: context.l10n.routeCancelShort,
                              variant: AppButtonVariant.secondary,
                              onPressed: _cancelRoute,
                            ),
                          ),
                        if (route.status.canComplete)
                          Expanded(
                            child: AppButton(
                              label: context.l10n.routeCompleteShort,
                              variant: AppButtonVariant.secondary,
                              onPressed: () => _completeRoute(route),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _RouteBody extends StatelessWidget {
  const _RouteBody({
    required this.route,
    required this.expenses,
    required this.onStopTap,
    required this.onAssignDriver,
  });

  final RouteDetail route;
  final List<RouteExpense> expenses;
  final ValueChanged<RouteStop> onStopTap;
  final ValueChanged<RouteDetail> onAssignDriver;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final driverName = route.driverFullName ?? '';
    final hasDriver = driverName.isNotEmpty;

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
                  // Маршрут-заготовку собирают без водителя — это законное
                  // состояние, а не неполные данные. Пустое имя читалось бы
                  // как сбой загрузки, поэтому у него своя иконка и подпись.
                  if (hasDriver)
                    InitialsAvatar(name: driverName, size: 46)
                  else
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: t.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_off_outlined, color: t.text3),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(context.l10n.driverTitle,
                            style: AppTypography.secondary
                                .copyWith(color: t.text2)),
                        Text(
                          hasDriver ? driverName : context.l10n.routeNoDriver,
                          style: AppTypography.bodyStrong.copyWith(
                              color: hasDriver ? t.text : t.warn),
                        ),
                      ],
                    ),
                  ),
                  // Назначение — та же форма правки: отдельного экрана под
                  // одно поле заводить незачем.
                  if (!hasDriver && route.status.canAssignDriver)
                    AppButton(
                      label: context.l10n.routeAssignDriver,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => onAssignDriver(route),
                    ),
                ],
              ),
              if (!hasDriver)
                Text(context.l10n.routeNoDriverHint,
                    style:
                        AppTypography.secondary.copyWith(color: t.text2)),
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
                      // Вся выручка, а не одни наличные: разбивку на
                      // наличные и безнал показывает блок кассы ниже, а в
                      // шапке «Собрано» одними наличными занижало день.
                      value: MoneyFormatter.sum(context.l10n, route.revenue),
                    ),
                  ),
                ],
              ),
              // Сколько ещё везти и привезти по открытым точкам — как на
              // карточке маршрута в списке; точки здесь уже загружены.
              if (route.expected() case final e when !e.isEmpty)
                OrderExpectations(capsules: e.capsules, amount: e.amount),
            ],
          ),
        ),
        // Касса приходит с сервером в самом маршруте; локальный подсчёт по
        // точкам остаётся запасным вариантом внутри `RouteDetail.collected`
        // для стендов, где этих полей ещё нет.
        SectionBlock(
          label: context.l10n.routeCashSection,
          // Подсказку про «сдать остаток» показываем водителю, а не админу:
          // деньги сдаёт не он.
          child: RouteCashCard(route: route, showHint: false),
        ),
        SectionBlock(
          label: context.l10n.routeExpensesSection,
          child: expenses.isEmpty
              ? AppCard(
                  child: Text(context.l10n.routeNoExpenses,
                      style: AppTypography.secondary
                          .copyWith(color: t.text2)),
                )
              : Column(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final expense in expenses)
                      _ExpenseRow(expense: expense),
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

/// Строка расхода водителя: категория, комментарий и сумма.
///
/// Только на просмотр: удалять чужой расход админ может по контракту, но
/// делать это из карточки маршрута опасно — рядом лежат деньги, и промах
/// пальцем стоил бы записи. Удаление живёт у водителя.
class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense});

  final RouteExpense expense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final comment = expense.comment;

    return AppCard(
      compact: true,
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(expense.category.label(context.l10n),
                    style: AppTypography.bodyStrong.copyWith(color: t.text)),
                if (comment != null && comment.trim().isNotEmpty)
                  Text(comment,
                      style:
                          AppTypography.secondary.copyWith(color: t.text2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(MoneyFormatter.sum(context.l10n, expense.amount),
              style: AppTypography.bodyStrong.copyWith(color: t.danger)),
        ],
      ),
    );
  }
}

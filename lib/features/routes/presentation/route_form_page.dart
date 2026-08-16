import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/utils/idempotency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/search_field.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/driver.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/route_models.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/crm_repository.dart';

/// Экран создания и редактирования маршрута: водитель, дата и заказчики.
///
/// В режиме правки набор доступных изменений зависит от статуса — см.
/// [RouteEditRules]: начатый маршрут можно только дополнить точками.
class RouteFormPage extends StatefulWidget {
  const RouteFormPage({super.key, this.route});

  /// Маршрут для правки; `null` — создаём новый.
  final RouteDetail? route;

  bool get isEdit => route != null;

  @override
  State<RouteFormPage> createState() => _RouteFormPageState();
}

class _RouteFormPageState extends State<RouteFormPage> with SubmitState {
  List<Driver> _drivers = [];
  List<Customer> _customers = [];
  bool _loading = true;
  bool _loadFailed = false;

  String? _driverId;
  late DateTime _date;
  final Set<String> _customerIds = {};

  /// Точки, с которыми маршрут был открыт, — база для вычисления правок.
  late final Set<String> _initialCustomerIds =
      widget.route?.stops.map((s) => s.customerId).toSet() ?? const {};

  RouteStatus get _status => widget.route?.status ?? RouteStatus.created;

  /// В создании ограничений нет, в правке их задаёт статус.
  bool get _canReschedule => !widget.isEdit || _status.canReschedule;
  bool get _canRemoveCustomers =>
      !widget.isEdit || _status.canRemoveCustomers;

  /// Один ключ на весь экран: повтор после обрыва связи не должен создать
  /// второй такой же маршрут.
  final String _idempotencyKey = newIdempotencyKey('route');

  /// Локальный фильтр по уже загруженному списку: выбирать из сотни
  /// чекбоксов вслепую невозможно.
  String _customerQuery = '';

  List<Customer> get _visibleCustomers {
    final q = _customerQuery.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.address.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    _date = route?.date ?? DateTime.now();
    _driverId = route?.driverId;
    _customerIds.addAll(_initialCustomerIds);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final repo = context.read<CrmRepository>();
    try {
      final drivers = await repo.getDrivers();
      final customers = await repo.getCustomers();
      if (!mounted) return;
      setState(() {
        _drivers = drivers;
        _customers = customers;
        _loading = false;
      });
    } catch (_) {
      // Без этого экран навсегда оставался с крутящимся индикатором.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  /// Заказчики, добавленные к исходному составу.
  Set<String> get _addedCustomers =>
      _customerIds.difference(_initialCustomerIds);

  /// Заказчики, убранные из исходного состава.
  Set<String> get _removedCustomers =>
      _initialCustomerIds.difference(_customerIds);

  /// Есть ли что сохранять. При создании — всегда да.
  bool get _hasChanges {
    final route = widget.route;
    if (route == null) return true;
    return !DateUtils.isSameDay(_date, route.date) ||
        _driverId != route.driverId ||
        _addedCustomers.isNotEmpty ||
        _removedCustomers.isNotEmpty;
  }

  bool get _valid =>
      _driverId != null && _customerIds.isNotEmpty && _hasChanges;

  /// Можно ли тронуть этого заказчика: снять галочку с уже стоящей точки
  /// разрешено не всегда, поставить новую — почти всегда.
  bool _canToggle(String customerId) => _customerIds.contains(customerId)
      ? _canRemoveCustomers || !_initialCustomerIds.contains(customerId)
      : _status.canAddCustomers;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    var first = now.subtract(const Duration(days: 30));
    // Маршрут мог быть заведён давно и всё ещё не выехать. Без этого календарь
    // падал на ассерте SDK: initialDate оказывался раньше firstDate.
    if (_date.isBefore(first)) first = _date;

    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final repo = context.read<CrmRepository>();
    // Строки берём до запроса: после await контекст уже мог уйти.
    final l10n = context.l10n;
    final fallback =
        widget.isEdit ? l10n.routeFormSaveFailed : l10n.routeFormCreateFailed;

    final saved = await submit(
      () => widget.isEdit ? _applyChanges(repo) : _create(repo),
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: fallback)
          : fallback,
    );

    if (saved && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _create(CrmRepository repo) => repo.createRoute(
        driverId: _driverId!,
        date: _date,
        customerIds: _customerIds.toList(),
        idempotencyKey: _idempotencyKey,
      );

  /// Применяет правки по одной: операции «сохранить маршрут целиком» у сервера
  /// нет, каждое изменение — отдельный запрос.
  ///
  /// Это не транзакция: при отказе на середине предыдущие правки останутся
  /// применёнными. Поэтому экран после ошибки перечитывает маршрут, и
  /// повторное сохранение доделает остаток — набор правок считается заново от
  /// свежего состояния, а каждая операция идемпотентна.
  ///
  /// Порядок фиксирован: сначала скалярные поля (по одному запросу), потом
  /// удаления и лишь затем добавления — так маршрут ни в один момент не
  /// раздувается сверх итогового состава.
  Future<void> _applyChanges(CrmRepository repo) async {
    final route = widget.route!;
    final id = route.id;

    if (_canReschedule) {
      if (!DateUtils.isSameDay(_date, route.date)) {
        await repo.updateRouteDate(routeId: id, date: _date);
      }
      if (_driverId != route.driverId) {
        await repo.assignDriver(routeId: id, driverId: _driverId!);
      }
    }

    if (_canRemoveCustomers) {
      for (final customerId in _removedCustomers) {
        await repo.removeRouteCustomer(routeId: id, customerId: customerId);
      }
    }

    if (_status.canAddCustomers) {
      for (final customerId in _addedCustomers) {
        await repo.addRouteCustomer(routeId: id, customerId: customerId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return DetailScaffold(
      title: widget.isEdit
          ? context.l10n.routeEditTitle
          : context.l10n.routeFormTitle,
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
                message: context.l10n.routeFormLoadFailed,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.lg,
              children: [
                // Объясняем, почему часть формы не поддаётся: заблокированные
                // поля без причины выглядят поломкой.
                if (widget.isEdit && !_canReschedule)
                  AppCard(
                    child: Row(
                      spacing: AppSpacing.md,
                      children: [
                        Icon(Icons.info_outline, size: 20, color: t.text2),
                        Expanded(
                          child: Text(
                            context.l10n.routeEditInProgressHint,
                            style: AppTypography.secondary
                                .copyWith(color: t.text2),
                          ),
                        ),
                      ],
                    ),
                  ),
                _Section(
                  label: context.l10n.routeFormDate,
                  child: AppCard(
                    onTap: _canReschedule ? _pickDate : null,
                    child: Row(
                      spacing: AppSpacing.md,
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 20,
                            color: _canReschedule ? t.primary : t.text3),
                        Expanded(
                          child: Text(DateFormat('dd.MM.yyyy').format(_date),
                              style: AppTypography.bodyStrong.copyWith(
                                  color: _canReschedule ? t.text : t.text2)),
                        ),
                        if (_canReschedule)
                          Icon(Icons.chevron_right, color: t.text2),
                      ],
                    ),
                  ),
                ),
                _Section(
                  label: context.l10n.routeFormDriver,
                  child: _drivers.isEmpty
                      ? Text(context.l10n.routeFormNoDrivers,
                          style:
                              AppTypography.secondary.copyWith(color: t.text2))
                      : Column(
                          spacing: AppSpacing.sm,
                          children: [
                            for (final d in _drivers)
                              // В начатом маршруте показываем только его
                              // водителя: остальные строки были бы мёртвыми.
                              if (_canReschedule || _driverId == d.id)
                                _SelectableRow(
                                  selected: _driverId == d.id,
                                  leading: InitialsAvatar(
                                      name: d.fullName, size: 40),
                                  title: d.fullName,
                                  subtitle: d.phone,
                                  onTap: _canReschedule
                                      ? () => setState(() => _driverId = d.id)
                                      : null,
                                ),
                          ],
                        ),
                ),
                _Section(
                  label: context.l10n.routeFormCustomers,
                  trailing: context.l10n.routeFormSelected(_customerIds.length),
                  child: _customers.isEmpty
                      ? Text(context.l10n.routeFormNoCustomers,
                          style:
                              AppTypography.secondary.copyWith(color: t.text2))
                      : Column(
                          spacing: AppSpacing.sm,
                          children: [
                            SearchField(
                              hint: context.l10n.customerSearch,
                              onChanged: (q) =>
                                  setState(() => _customerQuery = q),
                            ),
                            if (_visibleCustomers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.md),
                                child: Text(context.l10n.commonNothingFound,
                                    style: AppTypography.secondary
                                        .copyWith(color: t.text2)),
                              ),
                            for (final c in _visibleCustomers)
                              _SelectableRow(
                                selected: _customerIds.contains(c.id),
                                multi: true,
                                title: c.name,
                                subtitle: c.address,
                                onTap: _canToggle(c.id)
                                    ? () => setState(() {
                                          if (!_customerIds.remove(c.id)) {
                                            _customerIds.add(c.id);
                                          }
                                        })
                                    : null,
                              ),
                          ],
                        ),
                ),
                if (submitError != null)
                  Text(submitError!,
                      style: AppTypography.secondary.copyWith(color: t.danger)),
              ],
            ),
      bottomBar: _loadFailed
          ? null
          : BottomActionBar(
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  Expanded(
                    child: AppButton(
                      label: context.l10n.commonCancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  Expanded(
                    child: AppButton(
                      label: switch ((widget.isEdit, submitting)) {
                        (true, true) => context.l10n.commonSaving,
                        (true, false) => context.l10n.commonSave,
                        (false, true) => context.l10n.commonCreating,
                        (false, false) => context.l10n.commonCreate,
                      },
                      enabled: _valid && !submitting,
                      onPressed: (_valid && !submitting) ? _save : null,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Блок формы: капс-подпись, опциональная приписка справа и содержимое.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Row(
          children: [
            Text(label,
                style: AppTypography.fieldLabel.copyWith(color: t.text2)),
            const Spacer(),
            if (trailing != null)
              Text(trailing!,
                  style: AppTypography.secondary.copyWith(color: t.text2)),
          ],
        ),
        child,
      ],
    );
  }
}

/// Строка выбора: радио для водителя, чекбокс для заказчиков.
///
/// `onTap == null` — строку трогать нельзя (правило [RouteEditRules]); она
/// гасится, но остаётся видимой: убрать её значило бы скрыть от админа то,
/// что в маршруте уже есть.
class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.leading,
    this.multi = false,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool multi;

  bool get _enabled => onTap != null;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: _enabled ? 1 : 0.55,
      child: Material(
        color: selected ? t.softOf(t.primary) : t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          mouseCursor: _enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? t.primary : t.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              spacing: AppSpacing.md,
              children: [
                ?leading,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(title,
                          style:
                              AppTypography.bodyStrong.copyWith(color: t.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(subtitle,
                          style:
                              AppTypography.secondary.copyWith(color: t.text2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(
                  multi
                      ? (selected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank)
                      : (selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked),
                  color: selected ? t.primary : t.text3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

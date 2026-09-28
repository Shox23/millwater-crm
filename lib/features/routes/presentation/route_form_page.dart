import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/utils/day.dart';
import '../../../core/utils/idempotency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/labeled_card.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/segmented_toggle.dart';
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

  /// Цель каждой точки; отсутствие записи — цель по умолчанию.
  /// Маршрут бывает смешанным: по дороге и капсулы завезли, и кулер забрали.
  final Map<String, OrderPurpose> _stopPurposes = {};

  /// Задание водителю: сколько капсул везти каждому заказчику.
  /// Ноль — задания ещё не поставили, и форма такую точку не отпустит.
  final Map<String, int> _bottleCounts = {};

  /// Договорная сумма за весь заказ по каждой точке — поле ввода живёт в
  /// списке заказчиков, и контроллер заводится при первом обращении.
  /// Пустое поле — считать по прайсу.
  final Map<String, TextEditingController> _customPrices = {};

  TextEditingController _customPriceController(String customerId) =>
      _customPrices.putIfAbsent(customerId, TextEditingController.new);

  /// Комментарий водителю к точке — та же история, что и с суммой: поле
  /// живёт в списке, контроллер заводится при первом обращении. Пустое —
  /// комментария нет.
  final Map<String, TextEditingController> _comments = {};

  TextEditingController _commentController(String customerId) =>
      _comments.putIfAbsent(customerId, TextEditingController.new);

  /// Введённый комментарий; `null` — поле пустое.
  String? _commentOf(String customerId) {
    final text = _comments[customerId]?.text.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// Введённая сумма; `null` — поле пустое (по прайсу) или не число.
  int? _customPriceOf(String customerId) =>
      int.tryParse(_customPrices[customerId]?.text.trim() ?? '');

  /// Сумма либо пустая, либо целое больше нуля: ноль сервер отверг бы, а
  /// «бесплатно» задают не ценой, а способом оплаты «в долг» при закрытии.
  bool _customPriceValid(String customerId) {
    final text = _customPrices[customerId]?.text.trim() ?? '';
    return text.isEmpty || (_customPriceOf(customerId) ?? 0) > 0;
  }

  /// Скрытое поле не держит форму: сумму, набранную у доставки, при смене
  /// цели на опт не видно — и не отправят, значит и проверять её незачем.
  bool get _customPricesValid => _customerIds
      .every((id) => !_allowsCustomPrice(id) || _customPriceValid(id));

  /// Комментарии точек, с которыми маршрут открыли: показываем как есть,
  /// менять их сервер не умеет.
  late final Map<String, String?> _initialComments = {
    for (final stop in widget.route?.stops ?? const <RouteStop>[])
      stop.customerId: stop.comment,
  };

  /// Суммы точек, с которыми маршрут открыли, — менять их нечем, как и
  /// задание (см. [_initialBottleCounts]).
  late final Map<String, int?> _initialCustomPrices = {
    for (final stop in widget.route?.stops ?? const <RouteStop>[])
      stop.customerId: stop.customPrice,
  };

  /// Точки, с которыми маршрут был открыт, — база для вычисления правок.
  late final Set<String> _initialCustomerIds =
      widget.route?.stops.map((s) => s.customerId).toSet() ?? const {};

  /// Задания точек, с которыми маршрут открыли. Менять их нечем: у сервера
  /// есть только добавление, удаление и правка порядка объезда.
  late final Map<String, int?> _initialBottleCounts = {
    for (final stop in widget.route?.stops ?? const <RouteStop>[])
      stop.customerId: stop.bottleSellCount,
  };

  /// Точку добавляют сейчас — значит задание ещё можно задать.
  bool _isNewStop(String customerId) =>
      !_initialCustomerIds.contains(customerId);

  OrderPurpose _purposeOf(String customerId) =>
      _stopPurposes[customerId] ?? OrderPurpose.delivery19l;

  /// Заданию место только у доставки: вывозу и опту везти нечего.
  bool _needsBottleCount(String customerId) =>
      _purposeOf(customerId) == OrderPurpose.delivery19l;

  /// Договорная сумма — у доставки и у вывоза. У доставки она заменяет
  /// расчёт по прайсу, у вывоза — единственный источник денег: своей цены
  /// у него нет, и без неё вывоз бесплатный. Опту сумма не нужна: там цена
  /// договорная на бутыль и вводится водителем на месте.
  bool _allowsCustomPrice(String customerId) =>
      _purposeOf(customerId) != OrderPurpose.bulkWater;

  int _bottleCountOf(String customerId) => _bottleCounts[customerId] ?? 0;

  /// Доставка без задания уйти не должна: водитель не узнает, сколько везти.
  /// У точек, которые уже в маршруте, задание не спрашиваем — изменить его
  /// всё равно нечем.
  bool get _bottleCountsFilled => _customerIds.every((id) =>
      !_isNewStop(id) || !_needsBottleCount(id) || _bottleCountOf(id) > 0);

  RouteStatus get _status => widget.route?.status ?? RouteStatus.created;

  /// В создании ограничений нет, в правке их задаёт статус.
  bool get _canReschedule => !widget.isEdit || _status.canReschedule;

  /// Водителя сервер разрешает менять и в начатом маршруте — правило живёт
  /// в `RouteEditRules`, здесь только поправка на создание.
  bool get _canAssignDriver => !widget.isEdit || _status.canAssignDriver;
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

  /// Дата нового маршрута — завтра: маршруты планируют накануне, и
  /// «сегодня» по умолчанию заставляло каждый раз лезть в календарь.
  /// Через день месяца, а не `add(Duration(days: 1))`, — так дата остаётся
  /// календарной, без часов.
  static DateTime _tomorrow() {
    final today = dayOnly(DateTime.now());
    return DateTime(today.year, today.month, today.day + 1);
  }

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    _date = route?.date ?? _tomorrow();
    _driverId = route?.driverId;
    _customerIds.addAll(_initialCustomerIds);
    // Цель точек, с которыми маршрут открыли: без этого вывоз в редакторе
    // показывался доставкой. Менять её у такой точки нечем — см. ниже.
    for (final stop in route?.stops ?? const <RouteStop>[]) {
      _stopPurposes[stop.customerId] = stop.purpose;
    }
    _load();
  }

  @override
  void dispose() {
    for (final controller in _customPrices.values) {
      controller.dispose();
    }
    for (final controller in _comments.values) {
      controller.dispose();
    }
    super.dispose();
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

  /// Водителя в условии нет: маршрут без исполнителя — законное состояние,
  /// сервер оставляет такой маршрут в `created`, пока водителя не назначат.
  bool get _valid =>
      _customerIds.isNotEmpty &&
      _hasChanges &&
      _bottleCountsFilled &&
      _customPricesValid;

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
        // Водителя можно не назначать: маршрут-заготовку собирают заранее,
        // а исполнителя ставят, когда станет ясно, кто свободен.
        driverId: _driverId,
        date: _date,
        orders: [
          for (final id in _customerIds)
            RouteOrderInput(
              customerId: id,
              purpose: _stopPurposes[id] ?? OrderPurpose.delivery19l,
              // Только у доставки: у вывоза и опта число капсул к доставке
              // смысла не имеет, и сервер получит поле пустым.
              bottleSellCount:
                  _needsBottleCount(id) ? _bottleCountOf(id) : null,
              // Договорная сумма — у доставки и вывоза; у опта цена
              // договорная на бутыль и вводится водителем.
              customPrice:
                  _allowsCustomPrice(id) ? _customPriceOf(id) : null,
              comment: _commentOf(id),
            ),
        ],
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

    if (_canReschedule && !DateUtils.isSameDay(_date, route.date)) {
      await repo.updateRouteDate(routeId: id, date: _date);
    }

    // Снять водителя сервер не умеет — есть только назначение. Поэтому
    // переход «был водитель → нет водителя» не отправляем вовсе.
    final driverId = _driverId;
    if (_canAssignDriver && driverId != null && driverId != route.driverId) {
      await repo.assignDriver(routeId: id, driverId: driverId);
    }

    if (_canRemoveCustomers) {
      for (final customerId in _removedCustomers) {
        await repo.removeRouteCustomer(routeId: id, customerId: customerId);
      }
    }

    if (_status.canAddCustomers) {
      for (final customerId in _addedCustomers) {
        await repo.addRouteCustomer(
          routeId: id,
          customerId: customerId,
          purpose: _stopPurposes[customerId] ?? OrderPurpose.delivery19l,
          bottleSellCount: _needsBottleCount(customerId)
              ? _bottleCountOf(customerId)
              : null,
          customPrice: _allowsCustomPrice(customerId)
              ? _customPriceOf(customerId)
              : null,
          comment: _commentOf(customerId),
        );
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
                            // Отдельной строкой, а не отсутствием выбора:
                            // пустой список без единой отметки читается как
                            // «форма не догрузилась», а не как решение.
                            if (_canAssignDriver)
                              _SelectableRow(
                                selected: _driverId == null,
                                leading: Icon(Icons.person_off_outlined,
                                    color: t.text2),
                                title: context.l10n.routeFormAssignLater,
                                subtitle:
                                    context.l10n.routeFormAssignLaterHint,
                                onTap: () => setState(() => _driverId = null),
                              ),
                            for (final d in _drivers)
                              // В начатом маршруте показываем только его
                              // водителя: остальные строки были бы мёртвыми.
                              if (_canAssignDriver || _driverId == d.id)
                                _SelectableRow(
                                  selected: _driverId == d.id,
                                  leading: InitialsAvatar(
                                      name: d.fullName, size: 40),
                                  title: d.fullName,
                                  subtitle: d.phone,
                                  onTap: _canAssignDriver
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
                            for (final c in _visibleCustomers) ...[
                              _SelectableRow(
                                selected: _customerIds.contains(c.id),
                                multi: true,
                                title: c.name,
                                subtitle: c.address,
                                onTap: _canToggle(c.id)
                                    ? () => setState(() {
                                          if (!_customerIds.remove(c.id)) {
                                            _customerIds.add(c.id);
                                          } else {
                                            // Точку убрали — её отличие от
                                            // цели маршрута больше ничего
                                            // не значит.
                                            _stopPurposes.remove(c.id);
                                          }
                                        })
                                    : null,
                              ),
                              // Цель показываем только у выбранных: у
                              // остальных выбирать нечему, и список из сотни
                              // заказчиков превратился бы в сотню селекторов.
                              if (_customerIds.contains(c.id))
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: AppSpacing.xl,
                                      bottom: AppSpacing.sm),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: AppSpacing.xs,
                                    children: [
                                      Text(
                                        context.l10n.routeFormStopPurpose,
                                        style: AppTypography.fieldLabel
                                            .copyWith(color: t.text3),
                                      ),
                                      // Цель точки, которая уже в маршруте,
                                      // сервер менять не умеет (как и
                                      // задание ниже): показываем как есть,
                                      // а не переключателем, которому некуда
                                      // отправить выбор.
                                      if (_isNewStop(c.id))
                                        SegmentedToggle<OrderPurpose>(
                                          options: [
                                            for (final p
                                                in OrderPurpose.values)
                                              SegmentOption(
                                                  value: p,
                                                  label:
                                                      p.label(context.l10n)),
                                          ],
                                          value: _purposeOf(c.id),
                                          columns: 3,
                                          onChanged: (p) => setState(() {
                                            _stopPurposes[c.id] = p;
                                          }),
                                        )
                                      else
                                        Text(
                                          _purposeOf(c.id)
                                              .label(context.l10n),
                                          style: AppTypography.bodyStrong
                                              .copyWith(color: t.text),
                                        ),
                                      // Задание водителю — сколько капсул
                                      // везти. Только у доставки: вывозу и
                                      // опту везти нечего.
                                      if (_needsBottleCount(c.id))
                                        _BottleSellField(
                                          count: _bottleCountOf(c.id),
                                          // Изменить задание у точки, которая
                                          // уже в маршруте, сервер не умеет —
                                          // показываем как есть и объясняем.
                                          editable: _isNewStop(c.id),
                                          savedValue:
                                              _initialBottleCounts[c.id],
                                          onChanged: (value) => setState(
                                              () => _bottleCounts[c.id] = value),
                                        ),
                                      // Договорная сумма — у доставки и
                                      // вывоза, и тоже только у новой точки.
                                      if (_allowsCustomPrice(c.id))
                                        _CustomPriceField(
                                          purpose: _purposeOf(c.id),
                                          controller:
                                              _customPriceController(c.id),
                                          editable: _isNewStop(c.id),
                                          savedValue: _initialCustomPrices[c.id],
                                          valid: _customPriceValid(c.id),
                                          onChanged: () => setState(() {}),
                                        ),
                                      // Комментарий водителю — как и всё
                                      // остальное, только у новой точки:
                                      // правки комментария у сервера нет.
                                      _CommentField(
                                        controller: _commentController(c.id),
                                        editable: _isNewStop(c.id),
                                        savedValue: _initialComments[c.id],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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


/// Задание водителю: сколько капсул везти заказчику.
///
/// Оформлено карточкой со счётчиком — так же, как водитель отмечает капсулы
/// на завершении доставки: одно и то же число, названное одинаково с обеих
/// сторон, читается без перевода.
///
/// У новой точки счётчик рабочий, у уже добавленной — только число: изменить
/// `bottle_sell_count` сервер не умеет, у него есть лишь добавление точки,
/// удаление и правка порядка объезда. Пустой счётчик, который некуда
/// отправить, обещал бы правку, которой нет.
class _BottleSellField extends StatelessWidget {
  const _BottleSellField({
    required this.count,
    required this.editable,
    required this.savedValue,
    required this.onChanged,
  });

  final int count;

  /// Точку добавляют сейчас — задание ещё можно задать. У точки, которая уже
  /// в маршруте, это `false`, даже когда задания у неё нет.
  final bool editable;

  /// Задание, с которым точка пришла с сервера; `null` — его не ставили.
  final int? savedValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: LabeledCard(
        label: l10n.routeFormBottleSell,
        child: editable
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.sm,
                children: [
                  QuantityStepper(
                    value: count,
                    onChanged: onChanged,
                    caption: l10n.routeFormBottleSellHint,
                  ),
                  // Ноль — это не «везти ноль капсул», а незаполненное
                  // задание: форма такую точку не отпускает.
                  if (count == 0)
                    Text(l10n.routeFormBottleSellRequired,
                        style:
                            AppTypography.secondary.copyWith(color: t.danger)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  // Прочерк, а не ноль: задания не ставили.
                  Text('${savedValue ?? '—'}',
                      style: AppTypography.statNumber.copyWith(color: t.text)),
                  Text(l10n.routeFormBottleSellLocked,
                      style: AppTypography.secondary.copyWith(color: t.text3)),
                ],
              ),
      ),
    );
  }
}

/// Комментарий водителю к точке: «позвонить с парковки», «ключ у охраны».
///
/// Необязателен и ни на что не влияет, кроме того, что водитель его увидит.
/// У точки, которая уже в маршруте, — только текст: менять комментарий
/// сервер не умеет, как не умеет менять задание и договорную сумму.
class _CommentField extends StatelessWidget {
  const _CommentField({
    required this.controller,
    required this.editable,
    required this.savedValue,
  });

  final TextEditingController controller;
  final bool editable;

  /// Комментарий, с которым точка пришла с сервера; `null` — его нет.
  final String? savedValue;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    if (!editable) {
      // Точке без комментария строка не нужна: пустая плашка «Комментарий»
      // ничего не сообщает.
      if (savedValue == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: LabeledCard(
          label: l10n.orderCommentTitle,
          child: Text(savedValue!,
              style: AppTypography.body.copyWith(color: t.text)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: LabeledTextField(
        label: l10n.orderComment,
        hint: l10n.orderCommentHint,
        helper: l10n.orderCommentHelper,
        helperMaxLines: 2,
        controller: controller,
        // Колонка на сервере — 255 символов, и обрезать он не станет.
        maxLength: 255,
      ),
    );
  }
}

/// Договорная сумма за весь заказ этой точки.
///
/// Не цена капсулы: сервер при закрытии запишет её в стоимость заказа как
/// есть, сколько бы капсул ни привезли. Пустое поле — считать по прайсу;
/// так у подавляющего большинства точек, поэтому поле не обязательное и
/// не мешает собрать маршрут. У вывоза прайса нет, и пустое поле значит
/// «без оплаты» — подсказки говорят об этом по-разному.
///
/// У уже добавленной точки — только число, как и у задания: изменить его
/// сервер не умеет.
class _CustomPriceField extends StatelessWidget {
  const _CustomPriceField({
    required this.purpose,
    required this.controller,
    required this.editable,
    required this.savedValue,
    required this.valid,
    required this.onChanged,
  });

  final OrderPurpose purpose;
  final TextEditingController controller;
  final bool editable;

  /// Сумма, с которой точка пришла с сервера; `null` — по прайсу.
  final int? savedValue;
  final bool valid;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    if (!editable) {
      // Точке без своей суммы строка не нужна: «по прайсу» — обычный случай,
      // и напоминать о нём у каждой точки незачем.
      if (savedValue == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: LabeledCard(
          label: l10n.routeFormCustomPrice,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(MoneyFormatter.sum(l10n, savedValue!),
                  style: AppTypography.statNumber.copyWith(color: t.text)),
              Text(l10n.routeFormBottleSellLocked,
                  style: AppTypography.secondary.copyWith(color: t.text3)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          LabeledTextField(
            label: l10n.routeFormCustomPrice,
            hint: purpose == OrderPurpose.pickup
                ? l10n.routeFormPickupPriceHint
                : l10n.routeFormCustomPriceHint,
            helper: purpose == OrderPurpose.pickup
                ? l10n.routeFormPickupPriceHelper
                : l10n.routeFormCustomPriceHelper,
            helperMaxLines: 2,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            onChanged: (_) => onChanged(),
          ),
          // Ошибка строкой, а не валидатором поля: форма маршрута не
          // обёрнута в `Form`, и валидатор без неё не сработал бы. Как у
          // задания капсул выше.
          if (!valid)
            Text(l10n.routeFormCustomPriceInvalid,
                style: AppTypography.secondary.copyWith(color: t.danger)),
        ],
      ),
    );
  }
}

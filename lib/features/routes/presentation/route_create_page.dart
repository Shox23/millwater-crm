import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/product_config.dart';
import '../../../core/utils/day.dart';
import '../../../core/utils/idempotency.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/search_field.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/driver.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/crm_repository.dart';
import '../../../l10n/l10n.dart';
import '../domain/customer_habits.dart';
import '../domain/route_draft.dart';
import 'widgets/route_create_customer_row.dart';
import 'widgets/route_create_header.dart';
import 'widgets/route_create_sheet.dart';
import 'widgets/route_create_stop_card.dart';
import 'widgets/route_create_totals.dart';

/// Сборка нового маршрута: заказчики слева, маршрут справа, итоги внизу.
///
/// Заменила форму, где точка раскрывалась **внутри** списка заказчиков: там
/// выбор клиента разворачивал под ним три поля, следующий клиент уезжал за
/// экран, а выбранные точки терялись среди невыбранных. Здесь список только
/// отмечает выбор, а всё про точку — цель, количество, цена и порядок
/// объезда — живёт в зоне маршрута.
///
/// Правка маршрута осталась за `RouteFormPage`: там набор доступных изменений
/// зависит от статуса (`RouteEditRules`), и это другая задача.
///
/// Раскладок две, страница одна: на широком экране две колонки и липкий
/// футер, на телефоне — список во весь экран и маршрут в нижней шторке.
/// Состояние у них общее, иначе две копии разошлись бы на первой же правке.
class RouteCreatePage extends StatefulWidget {
  const RouteCreatePage({super.key});

  @override
  State<RouteCreatePage> createState() => _RouteCreatePageState();
}

class _RouteCreatePageState extends State<RouteCreatePage> with SubmitState {
  /// С какой ширины показываем две колонки.
  ///
  /// Две колонки по 340px плюс промежутки — то же, что `minmax(340px, 1fr)` в
  /// прототипе: как только колонки перестают влезать, раскладка становится
  /// телефонной, со шторкой.
  static const double _twoColumns = 720;

  List<Driver> _drivers = const [];
  List<Customer> _customers = const [];
  DraftPricing _pricing =
      const DraftPricing(capsulePrice: ProductConfig.capsulePrice);
  bool _loading = true;
  bool _loadFailed = false;

  late DateTime _date = _tomorrow();
  String? _driverId;

  /// Всё состояние маршрута — один объект; итоги из него выводятся.
  RouteDraft _draft = const RouteDraft();

  /// Развёрнутая на редактирование точка; `null` — все свёрнуты.
  String? _expandedId;

  String _query = '';
  bool _sheetExpanded = false;

  String? _toast;
  Timer? _toastTimer;

  late final CustomerHabits _habits =
      CustomerHabits(context.read<CrmRepository>());

  /// Точки, у которых количество правил человек: подсказка из истории
  /// приезжает асинхронно и не должна затирать его ввод.
  final Set<String> _qtyTouched = {};

  /// Один ключ на весь экран: повтор после обрыва связи не должен создать
  /// второй такой же маршрут.
  final String _idempotencyKey = newIdempotencyKey('route');

  /// День, от которого считается давность доставок в списке.
  final DateTime _today = dayOnly(DateTime.now());

  /// Дата нового маршрута — завтра: маршруты планируют накануне, и «сегодня»
  /// по умолчанию заставляло каждый раз лезть в календарь.
  static DateTime _tomorrow() {
    final today = dayOnly(DateTime.now());
    return DateTime(today.year, today.month, today.day + 1);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
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
      // Прайс — не повод не дать собрать маршрут: без него считаем по цене
      // из сборки, как это делает `CapsulePrice`.
      var capsulePrice = ProductConfig.capsulePrice;
      try {
        capsulePrice = (await repo.getPrices()).capsulePrice;
      } catch (_) {
        capsulePrice = ProductConfig.capsulePrice;
      }
      if (!mounted) return;
      setState(() {
        _drivers = drivers;
        _customers = customers;
        _pricing = DraftPricing(
          capsulePrice: capsulePrice,
          customerPrices: {
            for (final c in customers)
              if (c.customWaterPrice != null) c.id: c.customWaterPrice!,
          },
        );
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

  /// Фильтр по уже загруженному списку — по названию, адресу и телефону.
  /// Адрес обязателен: заказчиков зовут по улице, и ищут их чаще по ней.
  List<Customer> get _visibleCustomers {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.address.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q))
        .toList();
  }

  RouteDraftTotals get _totals => _draft.totals(_pricing);

  /// Ноль в цене — незаконченный ввод, а не «бесплатно»: сервер такую сумму
  /// не примет (см. `RouteCreateStopCard`).
  bool get _valid =>
      _draft.isNotEmpty && _draft.stops.every((s) => s.price != 0);

  Customer? _customer(String id) =>
      _customers.where((c) => c.id == id).firstOrNull;

  void _toggle(Customer customer, {required bool compact}) {
    final l10n = context.l10n;

    if (_draft.contains(customer.id)) {
      setState(() {
        _draft = _draft.remove(customer.id);
        if (_expandedId == customer.id) _expandedId = null;
        _qtyTouched.remove(customer.id);
      });
      if (compact) _flash(l10n.routeCreateRemoved);
      return;
    }

    // Точка приходит заполненной: цель — доставка, количество — обычный объём
    // заказчика, цена — по прайсу. Красных ошибок до первого действия быть не
    // должно, поэтому единица, а не ноль: ноль — это не «везти ноль капсул».
    final usual = _habits.cached(customer.id);
    final stop = RouteDraftStop(customerId: customer.id, qty: usual ?? 1);
    setState(() => _draft = _draft.add(stop));
    if (compact) {
      _flash(l10n.routeCreateAdded(
        customer.name,
        l10n.capsulesCount(stop.qty),
      ));
    }
    // Объёма в API нет — спрашиваем историю этого заказчика (один запрос) и
    // подставляем, когда ответ придёт. См. `CustomerHabits`.
    if (!_habits.knows(customer.id)) _askHabit(customer, compact: compact);
  }

  Future<void> _askHabit(Customer customer, {required bool compact}) async {
    final qty = await _habits.load(customer);
    if (!mounted) return;
    // Набранное руками не перебиваем: подсказка приходит с задержкой, и
    // оператор к этому моменту мог уже поправить число.
    final keep = _qtyTouched.contains(customer.id) || qty == null;
    setState(() {
      if (keep || !_draft.contains(customer.id)) return;
      _draft = _draft.patch(customer.id, qty: qty);
    });
    // Тост успел показать количество по умолчанию — поправляем его тем же
    // числом, что теперь стоит в точке.
    if (!keep && compact && _draft.contains(customer.id)) {
      final l10n = context.l10n;
      _flash(l10n.routeCreateAdded(customer.name, l10n.capsulesCount(qty)));
    }
  }

  void _flash(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _create({required bool compact}) async {
    // На телефоне свёрнутая шторка сначала разворачивается: последний взгляд
    // на состав маршрута перед отправкой — дешевле, чем отменять созданный.
    if (compact && !_sheetExpanded) {
      setState(() => _sheetExpanded = true);
      return;
    }

    final repo = context.read<CrmRepository>();
    // Строки берём до запроса: после await контекст уже мог уйти.
    final l10n = context.l10n;
    final fallback = l10n.routeFormCreateFailed;

    final saved = await submit(
      () => repo.createRoute(
        date: _date,
        // Водителя можно не назначать: маршрут-заготовку собирают заранее.
        driverId: _driverId,
        orders: _draft.toOrders(),
        idempotencyKey: _idempotencyKey,
      ),
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: fallback)
          : fallback,
    );

    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }
    // На телефоне под кнопкой места для текста ошибки нет — показываем тостом.
    final error = submitError;
    if (compact && error != null) _flash(error);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= _twoColumns
          ? _wideLayout(context)
          : _compactLayout(context, constraints),
    );
  }

  // ---- Широкая раскладка: две колонки и липкий футер ----

  Widget _wideLayout(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    if (_loading || _loadFailed) {
      return DetailScaffold(
        title: l10n.routeFormTitle,
        body: _loadingBody(context),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.md,
                    children: [
                      const CircleBackButton(),
                      Text(l10n.routeFormTitle,
                          style:
                              AppTypography.appBarTitle.copyWith(color: t.text)),
                    ],
                  ),
                  RouteCreateHeader(
                    date: _date,
                    driverId: _driverId,
                    drivers: _drivers,
                    onDate: (date) => setState(() => _date = date),
                    onDriver: (id) => setState(() => _driverId = id),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.md,
                  children: [
                    Expanded(
                      child: _panel(
                        context,
                        label: l10n.routeFormCustomers,
                        trailing: _query.trim().isEmpty
                            ? l10n.routeCreateBase(_customers.length)
                            : l10n.routeCreateFound(_visibleCustomers.length),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: AppSpacing.sm,
                          children: [
                            SearchField(
                              hint: l10n.routeCreateSearchHint,
                              onChanged: (q) => setState(() => _query = q),
                            ),
                            Expanded(child: _customersList(compact: false)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _panel(
                        context,
                        label: l10n.routeCreateStopsLabel,
                        trailing: _draft.length > 1
                            ? l10n.routeCreateDragHint
                            : l10n.routeCreateOrderHint,
                        child: _stopsList(compact: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        filled: true,
        child: Column(
          // Без этого колонка забирает всю высоту окна: нижнюю панель
          // Scaffold меряет свободными ограничениями, и тело остаётся с нулём.
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            if (submitError != null)
              Text(submitError!,
                  style: AppTypography.secondary.copyWith(color: t.danger)),
            // Переносом, а не одной строкой: на окне под тысячу пикселей
            // итоги и две кнопки в строку не встают, и раньше выезжали за
            // край вместе с «Создать».
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RouteCreateTotals(totals: _totals),
                Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppButton(
                      label: l10n.commonCancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    AppButton(
                      label: switch ((_draft.isEmpty, submitting)) {
                        (_, true) => l10n.commonCreating,
                        (true, false) => l10n.routeCreateSubmitEmpty,
                        (false, false) => l10n.routeCreateSubmit(_draft.length),
                      },
                      enabled: _valid && !submitting,
                      onPressed: () => _create(compact: false),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Колонка с подписью — «ЗАКАЗЧИКИ» и «МАРШРУТ».
  Widget _panel(
    BuildContext context, {
    required String label,
    required String trailing,
    required Widget child,
  }) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Row(
            spacing: AppSpacing.sm,
            children: [
              Text(label,
                  style: AppTypography.sectionLabel.copyWith(color: t.text2)),
              const Spacer(),
              Flexible(
                child: Text(
                  trailing,
                  style: AppTypography.secondary.copyWith(color: t.text3),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  // ---- Телефонная раскладка: список и шторка ----

  Widget _compactLayout(BuildContext context, BoxConstraints constraints) {
    final t = context.tokens;
    final l10n = context.l10n;

    if (_loading || _loadFailed) {
      return DetailScaffold(
        title: l10n.routeFormTitle,
        body: _loadingBody(context),
      );
    }

    // Высота шторки — из одного источника, от неё же нижний отступ списка и
    // позиция тоста. `maxHeight` уже учитывает клавиатуру, поэтому
    // развёрнутая шторка не вылезает за экран при открытом вводе.
    final available = constraints.maxHeight;
    final sheetHeight = _sheetExpanded
        ? RouteCreateSheetMetrics.expanded(available)
        : math.min(RouteCreateSheetMetrics.peek, available);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.sm,
                    children: [
                      Row(
                        spacing: AppSpacing.md,
                        children: [
                          const CircleBackButton(),
                          Expanded(
                            child: Text(
                              l10n.routeFormTitle,
                              style: AppTypography.appBarTitle
                                  .copyWith(color: t.text),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      RouteCreateHeader(
                        compact: true,
                        date: _date,
                        driverId: _driverId,
                        drivers: _drivers,
                        onDate: (date) => setState(() => _date = date),
                        onDriver: (id) => setState(() => _driverId = id),
                      ),
                      SearchField(
                        hint: l10n.routeCreateSearchHint,
                        onChanged: (q) => setState(() => _query = q),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _customersList(compact: true)),
              ],
            ),
            // Затемнение под развёрнутой шторкой: тап по нему возвращает к
            // списку, как и кнопка «К списку».
            if (_sheetExpanded)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _sheetExpanded = false),
                  child: ColoredBox(color: t.overlay),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: 0,
              height: sheetHeight,
              child: RouteCreateSheet(
                expanded: _sheetExpanded,
                title: _draft.isEmpty
                    ? l10n.routeCreateSheetEmpty
                    : l10n.routeCreateSheetTitle(
                        l10n.routeStopsCount(_draft.length)),
                summary: _draft.isEmpty
                    ? l10n.routeCreateSheetEmptyHint
                    : l10n.routeCreateSheetSummary(
                        l10n.capsulesCount(_totals.capsules),
                        MoneyFormatter.sum(l10n, _totals.money),
                      ),
                summaryWarn: _totals
                    .exceedsCapacity(ProductConfig.vehicleCapsuleCapacity),
                onToggle: () => setState(() {
                  _sheetExpanded = !_sheetExpanded;
                  _expandedId = null;
                }),
                onCollapse: () => setState(() {
                  _sheetExpanded = false;
                  _expandedId = null;
                }),
                stops: _stopsList(compact: true),
                submit: AppButton(
                  label: switch ((_draft.isEmpty, submitting, _sheetExpanded)) {
                    (_, true, _) => l10n.commonCreating,
                    (true, false, _) => l10n.routeCreateSubmitEmpty,
                    (false, false, true) =>
                      l10n.routeCreateSubmit(_draft.length),
                    (false, false, false) =>
                      l10n.routeCreateSubmitShort(_draft.length),
                  },
                  enabled: _valid && !submitting,
                  onPressed: () => _create(compact: true),
                ),
              ),
            ),
            if (_toast != null)
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: sheetHeight + AppSpacing.xl,
                child: _Toast(message: _toast!),
              ),
          ],
        ),
      ),
    );
  }

  // ---- Общие части ----

  Widget _loadingBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: ErrorRetryView(
        onRetry: _load,
        message: context.l10n.routeFormLoadFailed,
      ),
    );
  }

  Widget _customersList({required bool compact}) {
    final l10n = context.l10n;
    final customers = _visibleCustomers;

    if (_customers.isEmpty) {
      return _hint(context, l10n.routeFormNoCustomers);
    }
    if (customers.isEmpty) {
      return _hint(context, l10n.commonNothingFound);
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.lg : 0,
        AppSpacing.xs,
        compact ? AppSpacing.lg : 0,
        // Иначе последняя строка уезжает под шторку, и до неё не дотянуться.
        compact ? RouteCreateSheetMetrics.listBottomPadding : AppSpacing.xs,
      ),
      itemCount: customers.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final customer = customers[i];
        return RouteCreateCustomerRow(
          customer: customer,
          selected: _draft.contains(customer.id),
          usualQty: _habits.cached(customer.id),
          today: _today,
          compact: compact,
          onTap: () => _toggle(customer, compact: compact),
        );
      },
    );
  }

  Widget _stopsList({required bool compact}) {
    if (_draft.isEmpty) return _emptyStops(context);

    final stops = _draft.stops;
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.lg : 0,
        AppSpacing.xs,
        compact ? AppSpacing.lg : 0,
        AppSpacing.md,
      ),
      itemCount: stops.length,
      // Перетаскивание начинается только с грипа: иначе на десктопе ломается
      // выделение текста и работа с полями, а на телефоне — прокрутка.
      buildDefaultDragHandles: false,
      // Под курсором и пальцем едет не копия карточки, а её свёрнутый вид.
      //
      // Копия раскрытой карточки уносит в оверлей вторые экземпляры полей
      // ввода, и сборка падает: «A _RenderLayoutBuilder was mutated in
      // _RenderLayoutBuilder.performLayout» — на месте списка точек остаётся
      // красный экран ошибки. Свёрнутая карточка полей не содержит, и
      // перетаскивание проходит спокойно (см. route_create_drag_test.dart).
      proxyDecorator: (_, index, _) => _draggedCard(index, compact: compact),
      onReorderItem: (from, to) =>
          setState(() => _draft = _draft.reorder(from, to)),
      itemBuilder: (context, i) {
        final stop = stops[i];
        final customer = _customer(stop.customerId);
        final expanded = _expandedId == stop.customerId;
        return Padding(
          key: ValueKey(stop.customerId),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: RouteCreateStopCard(
            number: i + 1,
            name: customer?.name ?? stop.customerId,
            stop: stop,
            unitPrice: _pricing.unitPriceFor(stop.customerId),
            usualQty: _habits.cached(stop.customerId),
            expanded: expanded,
            compact: compact,
            // Раскрытую точку не тащим: её карточка бывает выше видимой
            // части списка, а такой элемент Flutter перетаскивать не умеет
            // (см. [RouteCreateGrip.enabled]).
            grip: expanded
                ? RouteCreateGrip(compact: compact, enabled: false)
                : ReorderableDragStartListener(
                    index: i,
                    child: RouteCreateGrip(compact: compact),
                  ),
            onExpand: () => setState(() => _expandedId =
                _expandedId == stop.customerId ? null : stop.customerId),
            onRemove: () => setState(() {
              _draft = _draft.remove(stop.customerId);
              if (_expandedId == stop.customerId) _expandedId = null;
              _qtyTouched.remove(stop.customerId);
            }),
            onPurpose: (purpose) => setState(
                () => _draft = _draft.patch(stop.customerId, purpose: purpose)),
            onQty: (qty) => setState(() {
              _qtyTouched.add(stop.customerId);
              _draft = _draft.patch(stop.customerId, qty: qty);
            }),
            onPrice: (price) => setState(
                () => _draft = _draft.patch(stop.customerId, price: price)),
            onComment: (comment) => setState(() =>
                _draft = _draft.patch(stop.customerId, comment: comment)),
            onMoveUp: i > 0
                ? () => setState(
                    () => _draft = _draft.shift(stop.customerId, -1))
                : null,
            onMoveDown: i < stops.length - 1
                ? () => setState(
                    () => _draft = _draft.shift(stop.customerId, 1))
                : null,
          ),
        );
      },
    );
  }

  /// Карточка под курсором во время перетаскивания.
  ///
  /// Строится заново, а не оборачивает готовую: у перетаскиваемой копии не
  /// должно быть ни полей ввода, ни кнопок — она ничего не редактирует, её
  /// только видно. [index] — место точки на момент начала перетаскивания;
  /// состав маршрута до отпускания не меняется.
  Widget _draggedCard(int index, {required bool compact}) {
    final stops = _draft.stops;
    if (index < 0 || index >= stops.length) return const SizedBox.shrink();
    final stop = stops[index];

    return Material(
      color: Colors.transparent,
      child: RouteCreateStopCard(
        number: index + 1,
        name: _customer(stop.customerId)?.name ?? stop.customerId,
        stop: stop,
        unitPrice: _pricing.unitPriceFor(stop.customerId),
        usualQty: _habits.cached(stop.customerId),
        expanded: false,
        compact: compact,
        dragging: true,
        grip: RouteCreateGrip(compact: compact, hint: false),
        onExpand: () {},
        onRemove: () {},
        onPurpose: (_) {},
        onQty: (_) {},
        onPrice: (_) {},
        onComment: (_) {},
      ),
    );
  }

  Widget _emptyStops(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: t.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            Text(l10n.routeCreateEmptyTitle,
                style: AppTypography.bodyStrong.copyWith(color: t.text2),
                textAlign: TextAlign.center),
            Text(l10n.routeCreateEmptyHint,
                style: AppTypography.secondary.copyWith(color: t.text3),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _hint(BuildContext context, String message) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.secondary
              .copyWith(color: context.tokens.text2),
        ),
      );
}

/// Тост над шторкой: «М Горький · 6 капсул».
///
/// Не `SnackBar`: тот прилипает к самому низу экрана — то есть под шторку,
/// где его не видно.
class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: t.softOf(t.primary),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: t.primary),
          boxShadow: t.cardShadow,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.secondary
              .copyWith(color: t.text, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

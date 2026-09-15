import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/filter_chips.dart';
import '../../../core/widgets/load_more_notifier.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/utils/stats_period.dart';
import '../../../data/models/enums.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_source.dart';
import 'order_detail_page.dart';
import 'widgets/order_card.dart';

/// Экран «Заказы» — список за всё время с отбором и поиском.
///
/// Открывается обеими ролями: админ видит все заказы, водитель — свои.
/// Различие целиком в [OrdersSource], который передаёт вызывающий экран, —
/// там, где нужный репозиторий и лежит.
class OrdersPage extends StatelessWidget {
  const OrdersPage({
    super.key,
    required this.source,
    required this.title,
    this.notifications,
    this.showBack = true,
    this.canManage = false,
  });

  final OrdersSource source;

  /// Заголовок: у админа «Заказы», у водителя «Мои заказы».
  final String title;

  /// Поток уведомлений — по нему список перечитывается, когда заказ закрыли.
  final Stream<dynamic>? notifications;

  /// Показывать кнопку «назад»: у водителя экран открывается поверх списка
  /// маршрутов, у админа он сам по себе вкладка.
  final bool showBack;

  /// Заказом можно управлять — перенести и поправить оплату. Это админские
  /// ручки под `/admin/*`, водителю их показывать нечестно.
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrdersBloc(
        source,
        notifications: notifications?.cast(),
      )..add(const OrdersRequested()),
      child: _OrdersView(
        source: source,
        title: title,
        showBack: showBack,
        canManage: canManage,
      ),
    );
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView({
    required this.source,
    required this.title,
    required this.showBack,
    required this.canManage,
  });

  final OrdersSource source;
  final String title;
  final bool showBack;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersBloc, OrdersState>(
      builder: (context, state) {
        final bloc = context.read<OrdersBloc>();
        final l10n = context.l10n;

        // Порядок чипов «Все, …» совпадает со списком значений, поэтому
        // индекс отбора — это индекс в этом же списке плюс единица.
        const statuses = DeliveryStatus.values;
        const purposes = OrderPurpose.values;

        // Не DetailScaffold: он прокручивает тело целиком и добавляет
        // боковые отступы, а здесь список должен листаться сам, а чипы —
        // уходить под край экрана, как на остальных списках.
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.lg,
                    AppSpacing.page,
                    0,
                  ),
                  child: Row(
                    spacing: AppSpacing.md,
                    children: [
                      if (showBack) const CircleBackButton(),
                      Expanded(
                        child: ScreenHeader(
                          label: l10n.ordersCount(state.total),
                          title: title,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: SearchField(
                    hint: l10n.ordersSearch,
                    onChanged: (q) => bloc.add(OrdersSearchChanged(q)),
                  ),
                ),
                FilterChips(
                  labels: [
                    l10n.filterAll,
                    for (final s in statuses) s.label(l10n),
                  ],
                  selectedIndex: state.statusFilter == null
                      ? 0
                      : statuses.indexOf(state.statusFilter!) + 1,
                  onSelected: (i) => bloc.add(
                    OrdersStatusChanged(i == 0 ? null : statuses[i - 1]),
                  ),
                ),
                FilterChips(
                  labels: [
                    l10n.filterAll,
                    for (final p in purposes) p.label(l10n),
                  ],
                  selectedIndex: state.purposeFilter == null
                      ? 0
                      : purposes.indexOf(state.purposeFilter!) + 1,
                  onSelected: (i) => bloc.add(
                    OrdersPurposeChanged(i == 0 ? null : purposes[i - 1]),
                  ),
                ),
                _DateChips(state: state),
                // Список не стирается на время запроса — нужен отдельный
                // признак «запрос в пути». Высота зарезервирована всегда,
                // иначе список дёргается на каждую букву в поиске.
                SizedBox(
                  height: 2,
                  child: state.status == OrdersStatus.loading &&
                          state.orders.isNotEmpty
                      ? const LinearProgressIndicator(minHeight: 2)
                      : null,
                ),
                Expanded(
                  child: _OrdersList(
                    state: state,
                    bloc: bloc,
                    source: source,
                    canManage: canManage,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.state,
    required this.bloc,
    required this.source,
    required this.canManage,
  });

  final OrdersState state;
  final OrdersBloc bloc;
  final OrdersSource source;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    // Спиннер во весь экран — только когда показывать нечего: поиск шлёт
    // запрос по ходу набора, и стирать выдачу на каждое слово значило бы
    // мигать списком.
    if (state.status == OrdersStatus.initial ||
        (state.status == OrdersStatus.loading && state.orders.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == OrdersStatus.error) {
      return ErrorRetryView(
        onRetry: () => bloc.add(const OrdersRequested()),
        message: context.l10n.ordersLoadFailed,
      );
    }

    final items = state.orders;
    if (items.isEmpty) {
      if (state.isEmptySearch) {
        return EmptyStateView.noSearchResults(
          l10n: context.l10n,
          query: state.query.trim(),
          onClear: () => bloc.add(const OrdersSearchChanged('')),
        );
      }
      // Отбор пуст — сбрасывать надо чипы, а не поиск.
      return state.hasFilters
          ? EmptyStateView(
              icon: Icons.receipt_long_outlined,
              title: context.l10n.filterEmptyTitle,
              hint: context.l10n.filterEmptyHint,
              actionLabel: context.l10n.filterAll,
              onAction: () {
                bloc.add(const OrdersStatusChanged(null));
                bloc.add(const OrdersPurposeChanged(null));
              },
            )
          : EmptyStateView(
              icon: Icons.receipt_long_outlined,
              title: context.l10n.ordersEmpty,
              hint: context.l10n.ordersTileHint,
            );
    }

    return RefreshIndicator(
      onRefresh: () async => bloc.add(const OrdersRequested()),
      child: LoadMoreNotifier(
        onLoadMore: () => bloc.add(const OrdersNextPageRequested()),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          // Лишний элемент в конце — строка догрузки.
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            if (i == items.length) {
              return LoadMoreFooter(loading: state.loadingMore);
            }
            final order = items[i];
            return OrderCard(
              order: order,
              onTap: () async {
                final changed = await Navigator.of(context).push<bool>(
                  OverlayPageRoute(
                    builder: (_) => OrderDetailPage(
                      order: order,
                      canManage: canManage,
                      // Отмена — у обеих ролей, каждой своей ручкой.
                      onCancel: (reason) =>
                          source.cancel(orderId: order.id, reason: reason),
                    ),
                  ),
                );
                // Перенос и правка оплаты отвечают 204 — список после них
                // перечитываем целиком, а не правим карточку в памяти.
                if (changed == true) bloc.add(const OrdersRequested());
              },
            );
          },
        ),
      ),
    );
  }
}

/// Отбор по дате: «Все», три готовых периода и диапазон из календаря.
///
/// Последний чип не выбирает готовое значение, а открывает календарь, и
/// подписан выбранным диапазоном, когда тот задан: иначе выбранный период
/// негде было бы увидеть, а чип «Период…» выглядел бы невыбранным при
/// работающем отборе.
class _DateChips extends StatelessWidget {
  const _DateChips({required this.state});

  final OrdersState state;

  static const _presets = StatsPeriod.values;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<OrdersBloc>();
    final filter = state.dateFilter;
    final custom = filter is OrdersCustomDate ? filter : null;

    final rangeLabel = custom == null
        ? l10n.ordersDateRange
        : l10n.ordersDateRangeValue(
            custom.labelParts.$1,
            custom.labelParts.$2,
          );

    return FilterChips(
      labels: [
        l10n.filterAll,
        for (final period in _presets) period.label(l10n),
        rangeLabel,
      ],
      selectedIndex: switch (filter) {
        OrdersAnyDate() => 0,
        OrdersPeriodDate(:final period) => _presets.indexOf(period) + 1,
        OrdersCustomDate() => _presets.length + 1,
      },
      onSelected: (i) async {
        if (i == 0) {
          bloc.add(const OrdersDateChanged(OrdersAnyDate()));
          return;
        }
        if (i <= _presets.length) {
          bloc.add(OrdersDateChanged(OrdersPeriodDate(_presets[i - 1])));
          return;
        }

        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          // Заказы бывают старше года — нижнюю границу берём с запасом, а
          // будущее ограничиваем сегодняшним днём: заказов вперёд не бывает.
          firstDate: DateTime(now.year - 3),
          lastDate: DateTime(now.year, now.month, now.day),
          initialDateRange: custom == null
              ? null
              : DateTimeRange(start: custom.from, end: custom.to),
        );
        if (picked == null) return;
        bloc.add(OrdersDateChanged(OrdersCustomDate.of(picked)));
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/filter_chips.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../routes/presentation/widgets/hero_progress_card.dart';
import '../../routes/presentation/widgets/route_card.dart';
import '../bloc/my_routes_bloc.dart';
import 'my_route_detail_page.dart';

/// Главный экран водителя: сводка за день и список своих маршрутов.
class MyRoutesPage extends StatelessWidget {
  const MyRoutesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MyRoutesBloc(context.read<DriverRepository>())
        ..add(const MyRoutesRequested()),
      child: const _MyRoutesView(),
    );
  }
}

class _MyRoutesView extends StatelessWidget {
  const _MyRoutesView();

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd.MM.yy').format(DateTime.now());

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<MyRoutesBloc, MyRoutesState>(
          builder: (context, state) {
            final bloc = context.read<MyRoutesBloc>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.lg,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.lg,
                    AppSpacing.page,
                    0,
                  ),
                  child: ScreenHeader(
                    label: context.l10n.routesHeaderToday(dateLabel),
                    title: context.l10n.myRoutesTitle,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Column(
                    spacing: AppSpacing.md,
                    children: [
                      // Денег здесь нет намеренно: сводный отчёт — админский
                      // эндпоинт, да и в ТЗ на экране водителя выручки нет.
                      // Прогресс — за сегодня, как и подпись в шапке.
                      HeroProgressCard(
                        done: state.deliveredToday,
                        total: state.stopsToday,
                      ),
                      // IntrinsicHeight: подпись «доставлено сегодня» длиннее
                      // соседних и переносится на две строки — без этого
                      // карточки в ряду получаются разной высоты.
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: AppSpacing.md,
                          children: [
                            Expanded(
                              child: StatTile(
                                value: '${state.routesCount}',
                                label: context.l10n.myRoutesStatRoutes,
                                alignment: CrossAxisAlignment.center,
                              ),
                            ),
                            Expanded(
                              child: StatTile(
                                value: '${state.deliveredToday}',
                                label: context.l10n.myRoutesStatDeliveredToday,
                                alignment: CrossAxisAlignment.center,
                              ),
                            ),
                            Expanded(
                              child: StatTile(
                                value: '${state.stopsTotal}',
                                label: context.l10n.myRoutesStatOrders,
                                alignment: CrossAxisAlignment.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                FilterChips(
                  labels: [
                    for (final f in RouteFilter.values)
                      f.label(context.l10n),
                  ],
                  selectedIndex: state.filter.index,
                  onSelected: (i) =>
                      bloc.add(MyRoutesFilterChanged(RouteFilter.values[i])),
                ),
                // Список больше не стирается на время запроса, поэтому нужен
                // отдельный признак «запрос в пути». Высота зарезервирована
                // всегда — иначе список дёргается при каждом обновлении.
                SizedBox(
                  height: 2,
                  child: state.status == MyRoutesStatus.loading &&
                          state.routes.isNotEmpty
                      ? const LinearProgressIndicator(minHeight: 2)
                      : null,
                ),
                Expanded(child: _MyRoutesList(state: state, bloc: bloc)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MyRoutesList extends StatelessWidget {
  const _MyRoutesList({required this.state, required this.bloc});

  final MyRoutesState state;
  final MyRoutesBloc bloc;

  @override
  Widget build(BuildContext context) {
    // Спиннер во весь экран — только когда показывать нечего. При обновлении
    // список остаётся на месте: иначе RefreshIndicator вылетает из дерева
    // прямо во время жеста, а он здесь единственный способ обновить.
    if (state.status == MyRoutesStatus.initial ||
        (state.status == MyRoutesStatus.loading && state.routes.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == MyRoutesStatus.error) {
      return ErrorRetryView(
        onRetry: () => bloc.add(const MyRoutesRequested()),
        message: context.l10n.routesLoadFailed,
      );
    }

    final items = state.visible;
    if (items.isEmpty) {
      return EmptyStateView(
        icon: Icons.route_outlined,
        title: state.filter == RouteFilter.all
            ? context.l10n.routesEmptyTitle
            : context.l10n.filterEmptyTitle,
        hint: state.filter == RouteFilter.all
            ? context.l10n.myRoutesEmptyHint
            : context.l10n.filterEmptyHint,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          final route = items[i];
          return RouteCard(
            route: route,
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                OverlayPageRoute(
                  builder: (_) => MyRouteDetailPage(routeId: route.id),
                ),
              );
              if (changed == true) bloc.add(const MyRoutesRequested());
            },
          );
        },
      ),
    );
  }

  /// Ждём окончания загрузки: иначе индикатор обновления гаснет мгновенно.
  Future<void> _refresh() {
    bloc.add(const MyRoutesRequested());
    return bloc.stream.firstWhere((s) => s.status != MyRoutesStatus.loading);
  }
}

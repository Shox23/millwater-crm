import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/utils/day.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/date_tabs.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/filter_chips.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/crm_repository.dart';
import '../../settings/presentation/settings_page.dart';
import '../bloc/routes_bloc.dart';
import 'route_detail_page.dart';
import 'route_form_page.dart';
import 'widgets/hero_progress_card.dart';
import 'widgets/route_card.dart';

class RoutesPage extends StatelessWidget {
  const RoutesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          RoutesBloc(context.read<CrmRepository>())
            ..add(const RoutesRequested()),
      child: const _RoutesView(),
    );
  }
}

class _RoutesView extends StatelessWidget {
  const _RoutesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<RoutesBloc, RoutesState>(
          builder: (context, state) {
            final bloc = context.read<RoutesBloc>();
            final isToday = state.date == dayOnly(DateTime.now());
            final dateLabel = DateFormat('dd.MM.yy').format(state.date);

            // Вся страница — один скролл: индикатор обновления принадлежит
            // ей целиком, а не списку. Иначе потянуть можно было только за
            // карточки маршрутов, а за шапку и сводку — нет.
            return RefreshIndicator(
              onRefresh: () => _refresh(bloc),
              child: CustomScrollView(
                // Тянуть можно и когда содержимого меньше экрана.
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
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
                            // Подпись идёт за лентой: «Сегодня · 14.08.26»
                            // только когда выбран сегодняшний день.
                            label: isToday
                                ? context.l10n.routesHeaderToday(dateLabel)
                                : context.l10n.routesHeaderOn(dateLabel),
                            title: context.l10n.routesTitle,
                            action: Row(
                              spacing: AppSpacing.sm,
                              children: [
                                const _SettingsButton(),
                                AppButton(
                                  label: context.l10n.commonCreate,
                                  icon: Icons.add,
                                  height: 44,
                                  onPressed: () => _openForm(context, bloc),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DateTabs(
                          selected: state.date,
                          onSelected: (date) =>
                              bloc.add(RoutesDateChanged(date)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.page,
                          ),
                          child: HeroProgressCard(
                            done: state.stopsDone,
                            total: state.stopsTotal,
                            collected: state.collected,
                            collectedLabel:
                                isToday ? null : context.l10n.routeCollected,
                          ),
                        ),
                        // Кнопка обновления стоит в строке фильтров, а не в
                        // шапке: там уже настройки и «Создать», и третья
                        // кнопка выдавливает заголовок на узком экране.
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.page),
                          child: Row(
                            spacing: AppSpacing.sm,
                            children: [
                              Expanded(
                                child: FilterChips(
                                  labels: [
                                    for (final f in RouteFilter.values)
                                      f.label(context.l10n),
                                  ],
                                  selectedIndex: state.filter.index,
                                  onSelected: (i) => bloc.add(
                                      RoutesFilterChanged(
                                          RouteFilter.values[i])),
                                ),
                              ),
                              IconActionButton(
                                icon: Icons.refresh,
                                tooltip: context.l10n.routesRefresh,
                                // Пока запрос в пути — повтор ни к чему.
                                onPressed:
                                    state.status == RoutesStatus.loading
                                        ? null
                                        : () =>
                                            bloc.add(const RoutesRequested()),
                              ),
                            ],
                          ),
                        ),
                        // Жест обновления списка не стирает, поэтому нужен
                        // отдельный признак «запрос в пути». Высота под
                        // полоску зарезервирована всегда — иначе страница
                        // дёргается на каждом обновлении.
                        SizedBox(
                          height: 2,
                          child: state.status == RoutesStatus.loading &&
                                  state.routes.isNotEmpty
                              ? const LinearProgressIndicator(minHeight: 2)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  _RoutesSliver(state: state, bloc: bloc),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Ждём окончания загрузки: иначе индикатор обновления гаснет мгновенно.
  Future<void> _refresh(RoutesBloc bloc) {
    bloc.add(const RoutesRequested());
    return bloc.stream.firstWhere((s) => s.status != RoutesStatus.loading);
  }

  Future<void> _openForm(BuildContext context, RoutesBloc bloc) async {
    final created = await Navigator.of(
      context,
    ).push<bool>(OverlayPageRoute(builder: (_) => const RouteFormPage()));
    if (created == true) {
      bloc.add(const RoutesRequested());
      if (context.mounted) showAppSnackBar(context, context.l10n.routesCreated);
    }
  }
}

/// Вход в настройки: тема и выход из аккаунта живут там.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    return IconActionButton(
      icon: Icons.settings_outlined,
      tooltip: context.l10n.settingsTitle,
      onPressed: () => Navigator.of(
        context,
      ).push(OverlayPageRoute<void>(builder: (_) => const SettingsPage())),
    );
  }
}

/// Содержимое страницы под шапкой: спиннер, ошибка, пустой день или список.
///
/// Отдаёт именно сливер, а не виджет: страница — один `CustomScrollView`,
/// и жест обновления должен ловиться на всей её высоте.
class _RoutesSliver extends StatelessWidget {
  const _RoutesSliver({required this.state, required this.bloc});

  final RoutesState state;
  final RoutesBloc bloc;

  /// Занимает остаток экрана — так спиннер и заглушки стоят по центру
  /// свободного места, а страница остаётся тянущейся.
  static Widget _fill(Widget child) =>
      SliverFillRemaining(hasScrollBody: false, child: Center(child: child));

  @override
  Widget build(BuildContext context) {
    // Спиннер во весь экран — только когда показывать нечего. При обновлении
    // список остаётся на месте, чтобы жест не терял позицию скролла. Смена дня
    // очищает список в блоке, поэтому там спиннер по-прежнему будет.
    if (state.status == RoutesStatus.initial ||
        (state.status == RoutesStatus.loading && state.routes.isEmpty)) {
      return _fill(const CircularProgressIndicator());
    }
    if (state.status == RoutesStatus.error) {
      return _fill(ErrorRetryView(
        onRetry: () => bloc.add(const RoutesRequested()),
        message: context.l10n.routesLoadFailed,
      ));
    }

    final items = state.visible;
    if (items.isEmpty) {
      return _fill(EmptyStateView(
        // Страница прокручивается сама — свой скролл заглушки перехватывал бы
        // жест обновления ровно там, где он нужнее всего: на пустом дне.
        scrollable: false,
        icon: Icons.route_outlined,
        title: state.filter == RouteFilter.all
            ? context.l10n.routesEmptyTitle
            : context.l10n.filterEmptyTitle,
        hint: state.filter == RouteFilter.all
            ? context.l10n
                .routesEmptyDayHint(DateFormat('dd.MM.yy').format(state.date))
            : context.l10n.filterEmptyHint,
      ));
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          final route = items[i];
          return RouteCard(
            route: route,
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                OverlayPageRoute(
                  builder: (_) => RouteDetailPage(routeId: route.id),
                ),
              );
              if (changed == true) bloc.add(const RoutesRequested());
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/filter_chips.dart';
import '../../../core/widgets/screen_header.dart';
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
    final dateLabel = DateFormat('dd.MM.yy').format(DateTime.now());

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<RoutesBloc, RoutesState>(
          builder: (context, state) {
            final bloc = context.read<RoutesBloc>();
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
                    label: 'Сегодня · $dateLabel',
                    title: 'Маршруты',
                    action: Row(
                      spacing: AppSpacing.sm,
                      children: [
                        const _SettingsButton(),
                        AppButton(
                          label: 'Создать',
                          icon: Icons.add,
                          height: 44,
                          onPressed: () => _openForm(context, bloc),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: HeroProgressCard(
                    done: state.stopsDone,
                    total: state.stopsTotal,
                    collected: state.collected,
                  ),
                ),
                FilterChips(
                  labels: [for (final f in RouteFilter.values) f.label],
                  selectedIndex: state.filter.index,
                  onSelected: (i) =>
                      bloc.add(RoutesFilterChanged(RouteFilter.values[i])),
                ),
                Expanded(
                  child: _RoutesList(state: state, bloc: bloc),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, RoutesBloc bloc) async {
    final created = await Navigator.of(
      context,
    ).push<bool>(OverlayPageRoute(builder: (_) => const RouteFormPage()));
    if (created == true) {
      bloc.add(const RoutesRequested());
      if (context.mounted) showAppSnackBar(context, 'Маршрут создан');
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
      tooltip: 'Настройки',
      onPressed: () => Navigator.of(
        context,
      ).push(OverlayPageRoute<void>(builder: (_) => const SettingsPage())),
    );
  }
}

class _RoutesList extends StatelessWidget {
  const _RoutesList({required this.state, required this.bloc});

  final RoutesState state;
  final RoutesBloc bloc;

  @override
  Widget build(BuildContext context) {
    if (state.status == RoutesStatus.loading ||
        state.status == RoutesStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == RoutesStatus.error) {
      return ErrorRetryView(
        onRetry: () => bloc.add(const RoutesRequested()),
        message: 'Не удалось загрузить маршруты',
      );
    }

    final items = state.visible;
    if (items.isEmpty) {
      return EmptyStateView(
        icon: Icons.route_outlined,
        title: state.filter == RouteFilter.all
            ? 'Маршрутов пока нет'
            : 'В этом фильтре пусто',
        hint: state.filter == RouteFilter.all
            ? 'Создайте маршрут: выберите водителя, дату и заказчиков'
            : 'Попробуйте другой фильтр',
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

  /// Ждём окончания загрузки: иначе индикатор обновления гаснет мгновенно.
  Future<void> _refresh() {
    bloc.add(const RoutesRequested());
    return bloc.stream.firstWhere((s) => s.status != RoutesStatus.loading);
  }
}

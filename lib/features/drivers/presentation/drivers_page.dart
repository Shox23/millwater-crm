import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/search_field.dart';
import '../../../data/repositories/crm_repository.dart';
import '../bloc/drivers_bloc.dart';
import 'driver_detail_page.dart';
import 'driver_form_page.dart';
import 'widgets/driver_card.dart';

class DriversPage extends StatelessWidget {
  const DriversPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DriversBloc(context.read<CrmRepository>())
            ..add(const DriversRequested()),
      child: const _DriversView(),
    );
  }
}

class _DriversView extends StatelessWidget {
  const _DriversView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<DriversBloc, DriversState>(
          builder: (context, state) {
            final bloc = context.read<DriversBloc>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.lg,
                    AppSpacing.page,
                    AppSpacing.lg,
                  ),
                  child: ScreenHeader(
                    // Под поиском в списке лежат найденные, а не вся команда:
                    // «Команда · 1» на двух набранных буквах — неправда.
                    label: state.query.trim().isEmpty
                        ? context.l10n.driversHeader(state.drivers.length)
                        : context.l10n
                            .driversHeaderFound(state.drivers.length),
                    title: context.l10n.driversTitle,
                    action: AppButton(
                      label: context.l10n.commonAdd,
                      icon: Icons.add,
                      height: 44,
                      onPressed: () => _openForm(context, bloc),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Row(
                    spacing: AppSpacing.sm,
                    children: [
                      Expanded(
                        child: SearchField(
                          hint: context.l10n.driversSearch,
                          onChanged: (q) => bloc.add(DriversSearchChanged(q)),
                        ),
                      ),
                      IconActionButton(
                        icon: Icons.refresh,
                        tooltip: context.l10n.driversRefresh,
                        // Пока запрос в пути — повтор ни к чему.
                        onPressed: state.status == DriversStatus.loading
                            ? null
                            : () => bloc.add(const DriversRequested()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Список больше не стирается на время запроса, поэтому нужен
                // отдельный признак «запрос в пути». Высота зарезервирована
                // всегда — иначе список дёргается на каждую букву в поиске.
                SizedBox(
                  height: 2,
                  child: state.status == DriversStatus.loading &&
                          state.drivers.isNotEmpty
                      ? const LinearProgressIndicator(minHeight: 2)
                      : null,
                ),
                Expanded(
                  child: _DriversList(
                    state: state,
                    bloc: bloc,
                    onAdd: () => _openForm(context, bloc),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, DriversBloc bloc) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(OverlayPageRoute(builder: (_) => const DriverFormPage()));
    if (saved == true) {
      bloc.add(const DriversRequested());
      if (context.mounted) showAppSnackBar(context, context.l10n.driverAdded);
    }
  }
}

class _DriversList extends StatelessWidget {
  const _DriversList({
    required this.state,
    required this.bloc,
    required this.onAdd,
  });

  final DriversState state;
  final DriversBloc bloc;

  /// Открывает форму создания — из шапки и из пустого состояния.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    // Спиннер во весь экран — только когда показывать нечего. Иначе список
    // держим на месте: поиск шлёт запрос по ходу набора, и стирать выдачу на
    // каждое слово значило бы мигать списком. Заодно RefreshIndicator больше
    // не вылетает из дерева посреди жеста обновления.
    if (state.status == DriversStatus.initial ||
        (state.status == DriversStatus.loading && state.drivers.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    // Раньше сетевая ошибка доходила сюда и выглядела как «Ничего не найдено».
    if (state.status == DriversStatus.error) {
      return ErrorRetryView(
        onRetry: () => bloc.add(const DriversRequested()),
        message: context.l10n.driversLoadFailed,
      );
    }
    final items = state.visible;
    if (items.isEmpty) {
      return state.isEmptySearch
          ? EmptyStateView.noSearchResults(
              l10n: context.l10n,
              query: state.query.trim(),
              onClear: () => bloc.add(const DriversSearchChanged('')),
            )
          : EmptyStateView(
              icon: Icons.local_shipping_outlined,
              title: context.l10n.driversEmptyTitle,
              hint: context.l10n.driversEmptyHint,
              actionLabel: context.l10n.driversEmptyAction,
              onAction: onAdd,
            );
    }
    return RefreshIndicator(
      onRefresh: () => _refresh(),
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
          final driver = items[i];
          return DriverCard(
            driver: driver,
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                OverlayPageRoute(
                  builder: (_) => DriverDetailPage(driver: driver),
                ),
              );
              if (changed == true) bloc.add(const DriversRequested());
            },
            onEdit: () async {
              final saved = await Navigator.of(context).push<bool>(
                OverlayPageRoute(
                  builder: (_) => DriverFormPage(driver: driver),
                ),
              );
              if (saved == true) {
                bloc.add(const DriversRequested());
                if (context.mounted) {
                  showAppSnackBar(context, context.l10n.changesSaved);
                }
              }
            },
            onDelete: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: context.l10n.driverDeleteTitle,
                message: context.l10n.driverDeleteMessage(driver.fullName),
              );
              if (!confirmed || !context.mounted) return;
              final repo = context.read<CrmRepository>();
              final ok = await runGuarded(
                context,
                () => repo.deleteDriver(driver.id),
                fallback: context.l10n.driverDeleteFailed,
              );
              if (!ok) return;
              bloc.add(const DriversRequested());
              if (context.mounted) {
                showAppSnackBar(context, context.l10n.driverDeleted);
              }
            },
          );
        },
      ),
    );
  }

  /// Ждём окончания загрузки: иначе индикатор обновления гаснет мгновенно
  /// и выглядит так, будто ничего не произошло.
  Future<void> _refresh() {
    bloc.add(const DriversRequested());
    return bloc.stream.firstWhere((s) => s.status != DriversStatus.loading);
  }
}

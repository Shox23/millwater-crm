import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
                    label: 'Команда · ${state.drivers.length}',
                    title: 'Водители',
                    action: AppButton(
                      label: 'Добавить',
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
                  child: SearchField(
                    hint: 'Поиск водителя',
                    onChanged: (q) => bloc.add(DriversSearchChanged(q)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
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
      if (context.mounted) showAppSnackBar(context, 'Водитель добавлен');
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
    if (state.status == DriversStatus.loading ||
        state.status == DriversStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    // Раньше сетевая ошибка доходила сюда и выглядела как «Ничего не найдено».
    if (state.status == DriversStatus.error) {
      return ErrorRetryView(
        onRetry: () => bloc.add(const DriversRequested()),
        message: 'Не удалось загрузить водителей',
      );
    }
    final items = state.visible;
    if (items.isEmpty) {
      return state.isEmptySearch
          ? EmptyStateView.noSearchResults(
              query: state.query.trim(),
              onClear: () => bloc.add(const DriversSearchChanged('')),
            )
          : EmptyStateView(
              icon: Icons.local_shipping_outlined,
              title: 'Водителей пока нет',
              hint: 'Добавьте первого — на него можно будет назначить маршрут',
              actionLabel: 'Добавить водителя',
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
                  showAppSnackBar(context, 'Изменения сохранены');
                }
              }
            },
            onDelete: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Удалить водителя?',
                message: '${driver.fullName} будет удалён из списка.',
              );
              if (!confirmed || !context.mounted) return;
              final repo = context.read<CrmRepository>();
              final ok = await runGuarded(
                context,
                () => repo.deleteDriver(driver.id),
                fallback: 'Не удалось удалить водителя.',
              );
              if (!ok) return;
              bloc.add(const DriversRequested());
              if (context.mounted) {
                showAppSnackBar(context, 'Водитель удалён');
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

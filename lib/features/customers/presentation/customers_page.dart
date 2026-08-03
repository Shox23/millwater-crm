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
import '../bloc/customers_bloc.dart';
import 'customer_detail_page.dart';
import 'customer_form_page.dart';
import 'widgets/customer_card.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CustomersBloc(context.read<CrmRepository>())
            ..add(const CustomersRequested()),
      child: const _CustomersView(),
    );
  }
}

class _CustomersView extends StatelessWidget {
  const _CustomersView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<CustomersBloc, CustomersState>(
          builder: (context, state) {
            final bloc = context.read<CustomersBloc>();
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
                    label: 'База · ${state.customers.length}',
                    title: 'Заказчики',
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
                    hint: 'Поиск заказчика',
                    onChanged: (q) => bloc.add(CustomersSearchChanged(q)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: _CustomersList(
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

  Future<void> _openForm(BuildContext context, CustomersBloc bloc) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(OverlayPageRoute(builder: (_) => const CustomerFormPage()));
    if (saved == true) {
      bloc.add(const CustomersRequested());
      if (context.mounted) showAppSnackBar(context, 'Заказчик добавлен');
    }
  }
}

class _CustomersList extends StatelessWidget {
  const _CustomersList({
    required this.state,
    required this.bloc,
    required this.onAdd,
  });

  final CustomersState state;
  final CustomersBloc bloc;

  /// Открывает форму создания — из шапки и из пустого состояния.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (state.status == CustomersStatus.loading ||
        state.status == CustomersStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    // Раньше сетевая ошибка доходила сюда и выглядела как «Ничего не найдено».
    if (state.status == CustomersStatus.error) {
      return ErrorRetryView(
        onRetry: () => bloc.add(const CustomersRequested()),
        message: 'Не удалось загрузить заказчиков',
      );
    }
    final items = state.visible;
    if (items.isEmpty) {
      return state.isEmptySearch
          ? EmptyStateView.noSearchResults(
              query: state.query.trim(),
              onClear: () => bloc.add(const CustomersSearchChanged('')),
            )
          : EmptyStateView(
              icon: Icons.storefront_outlined,
              title: 'Заказчиков пока нет',
              hint: 'Добавьте первого — он появится в списке и в маршрутах',
              actionLabel: 'Добавить заказчика',
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
          final customer = items[i];
          return CustomerCard(
            customer: customer,
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                OverlayPageRoute(
                  builder: (_) => CustomerDetailPage(customer: customer),
                ),
              );
              if (changed == true) bloc.add(const CustomersRequested());
            },
            onEdit: () async {
              final saved = await Navigator.of(context).push<bool>(
                OverlayPageRoute(
                  builder: (_) => CustomerFormPage(customer: customer),
                ),
              );
              if (saved == true) {
                bloc.add(const CustomersRequested());
                if (context.mounted) {
                  showAppSnackBar(context, 'Изменения сохранены');
                }
              }
            },
            onDelete: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Удалить заказчика?',
                message: '${customer.name} будет удалён из базы.',
              );
              if (!confirmed || !context.mounted) return;
              final repo = context.read<CrmRepository>();
              final ok = await runGuarded(
                context,
                () => repo.deleteCustomer(customer.id),
                fallback: 'Не удалось удалить заказчика.',
              );
              if (!ok) return;
              bloc.add(const CustomersRequested());
              if (context.mounted) {
                showAppSnackBar(context, 'Заказчик удалён');
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
    bloc.add(const CustomersRequested());
    return bloc.stream.firstWhere((s) => s.status != CustomersStatus.loading);
  }
}

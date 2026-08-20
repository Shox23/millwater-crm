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
import '../../../core/widgets/load_more_notifier.dart';
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
                    // Под поиском в списке лежат найденные, а не вся база:
                    // «База · 1» на двух набранных буквах — неправда.
                    label: state.query.trim().isEmpty
                        ? context.l10n.customersHeader(state.total)
                        : context.l10n.customersHeaderFound(state.total),
                    title: context.l10n.customersTitle,
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
                  child: SearchField(
                    hint: context.l10n.customerSearch,
                    onChanged: (q) => bloc.add(CustomersSearchChanged(q)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Список больше не стирается на время запроса, поэтому нужен
                // отдельный признак «запрос в пути». Высота зарезервирована
                // всегда — иначе список дёргается на каждую букву в поиске.
                SizedBox(
                  height: 2,
                  child:
                      state.status == CustomersStatus.loading &&
                          state.customers.isNotEmpty
                      ? const LinearProgressIndicator(minHeight: 2)
                      : null,
                ),
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
      if (context.mounted) showAppSnackBar(context, context.l10n.customerAdded);
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
    // Спиннер во весь экран — только когда показывать нечего. Иначе список
    // держим на месте: поиск шлёт запрос по ходу набора, и стирать выдачу на
    // каждое слово значило бы мигать списком. Заодно RefreshIndicator больше
    // не вылетает из дерева посреди жеста обновления — а здесь протяжка
    // единственный способ обновить, кнопки на экране нет.
    if (state.status == CustomersStatus.initial ||
        (state.status == CustomersStatus.loading && state.customers.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    // Раньше сетевая ошибка доходила сюда и выглядела как «Ничего не найдено».
    if (state.status == CustomersStatus.error) {
      return ErrorRetryView(
        onRetry: () => bloc.add(const CustomersRequested()),
        message: context.l10n.customersLoadFailed,
      );
    }
    final items = state.visible;
    if (items.isEmpty) {
      return state.isEmptySearch
          ? EmptyStateView.noSearchResults(
              l10n: context.l10n,
              query: state.query.trim(),
              onClear: () => bloc.add(const CustomersSearchChanged('')),
            )
          : EmptyStateView(
              icon: Icons.storefront_outlined,
              title: context.l10n.customersEmptyTitle,
              hint: context.l10n.customersEmptyHint,
              actionLabel: context.l10n.customersEmptyAction,
              onAction: onAdd,
            );
    }
    return RefreshIndicator(
      onRefresh: () => _refresh(),
      child: LoadMoreNotifier(
        onLoadMore: () => bloc.add(const CustomersNextPageRequested()),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          // Лишний элемент в конце — строка догрузки.
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            if (i == items.length) {
              return LoadMoreFooter(loading: state.loadingMore);
            }
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
                    showAppSnackBar(context, context.l10n.changesSaved);
                  }
                }
              },
              onDelete: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: context.l10n.customerDeleteTitle,
                  message: context.l10n.customerDeleteMessage(customer.name),
                );
                if (!confirmed || !context.mounted) return;
                final repo = context.read<CrmRepository>();
                final ok = await runGuarded(
                  context,
                  () => repo.deleteCustomer(customer.id),
                  fallback: context.l10n.customerDeleteFailed,
                );
                if (!ok) return;
                bloc.add(const CustomersRequested());
                if (context.mounted) {
                  showAppSnackBar(context, context.l10n.customerDeleted);
                }
              },
            );
          },
        ),
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

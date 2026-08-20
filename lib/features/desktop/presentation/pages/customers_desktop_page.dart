import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/widgets/load_more_notifier.dart';
import '../../../../core/utils/uz_phone.dart';
import '../../../../data/models/customer.dart';
import '../../../customers/bloc/customers_bloc.dart';
import '../../theme/desktop_typography.dart';
import '../../widgets/desktop_badge.dart';
import '../../widgets/desktop_button.dart';
import '../../widgets/desktop_empty.dart';
import '../../widgets/desktop_table.dart';

/// Раздел «Заказчики»: таблица базы с балансом и действиями.
class CustomersDesktopPage extends StatelessWidget {
  const CustomersDesktopPage({
    super.key,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final ValueChanged<Customer> onOpen;
  final ValueChanged<Customer> onEdit;
  final ValueChanged<Customer> onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return BlocBuilder<CustomersBloc, CustomersState>(
      builder: (context, state) {
        if (state.status == CustomersStatus.initial ||
            (state.status == CustomersStatus.loading &&
                state.customers.isEmpty)) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == CustomersStatus.error) {
          return DesktopEmpty(
            icon: Icons.cloud_off_outlined,
            title: l10n.customersLoadFailed,
          );
        }

        final customers = state.visible;

        // Таблица показывает загруженные страницы; прокрутка до низа
        // добирает следующую — как и в мобильном списке, блок у них общий.
        return LoadMoreNotifier(
          onLoadMore: () => context.read<CustomersBloc>().add(
            const CustomersNextPageRequested(),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
            child: DesktopTable(
              columns: [
                DesktopColumn(l10n.desktopColCustomer, flex: 22),
                DesktopColumn(l10n.desktopColAddress, flex: 20),
                DesktopColumn(l10n.desktopColCapsulesShort, flex: 10),
                DesktopColumn(l10n.desktopColLastOrder, flex: 10),
                DesktopColumn(l10n.desktopColBalance, flex: 12),
                const DesktopColumn('', width: 96),
              ],
              itemCount: customers.length,
              onRowTap: (i) => onOpen(customers[i]),
              empty: DesktopEmpty(
                icon: Icons.storefront_outlined,
                title: state.isEmptySearch
                    ? l10n.emptySearchTitle(state.query)
                    : l10n.customersEmptyTitle,
                hint: state.isEmptySearch
                    ? l10n.emptySearchHint
                    : l10n.customersEmptyHint,
              ),
              cellsBuilder: (i) {
                final customer = customers[i];

                return [
                  _NameCell(customer: customer),
                  Text(
                    customer.address,
                    style: DesktopTypography.tableCellSub.copyWith(
                      color: t.text2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${customer.capsuleBalance}',
                    style: DesktopTypography.tableCell.copyWith(color: t.text),
                  ),
                  Text(
                    customer.lastOrderDate == null
                        ? '—'
                        : DateFormat(
                            'dd.MM.yy',
                          ).format(customer.lastOrderDate!),
                    style: DesktopTypography.tableCell.copyWith(color: t.text2),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _BalanceCell(customer: customer),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: AppSpacing.sm,
                    children: [
                      DesktopIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: l10n.commonEdit,
                        size: 36,
                        onPressed: () => onEdit(customer),
                      ),
                      DesktopIconButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: l10n.commonDelete,
                        size: 36,
                        color: t.danger,
                        onPressed: () => onDelete(customer),
                      ),
                    ],
                  ),
                ];
              },
            ),
          ),
        );
      },
    );
  }
}

/// Заказчик: иконка типа, название и «тип · телефон».
///
/// «Тип» — это кулер: отдельного поля «Бизнес/Дом» в API нет, а кулер как раз
/// и отличает точку, где капсулу ставят, от той, где воду переливают.
class _NameCell extends StatelessWidget {
  const _NameCell({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final cooler = customer.hasCooler;
    final color = cooler ? t.aqua : t.primary;

    return Row(
      spacing: AppSpacing.md,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.softOf(color),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            cooler ? Icons.storefront_outlined : Icons.home_outlined,
            size: 19,
            color: color,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              Text(
                customer.name,
                style: DesktopTypography.tableCell.copyWith(color: t.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${cooler ? l10n.desktopWithCooler : l10n.desktopWithoutCooler}'
                ' · ${UzPhone.format(customer.phone)}',
                style: DesktopTypography.tableCellSub.copyWith(color: t.text3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceCell extends StatelessWidget {
  const _BalanceCell({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    if (customer.debt > 0) {
      return DesktopBadge(
        text: l10n.desktopBalanceDebt(MoneyFormatter.amount(customer.debt)),
        color: t.danger,
      );
    }
    if (customer.prepayment > 0) {
      return DesktopBadge(
        text: l10n.desktopBalancePrepaid(
          MoneyFormatter.amount(customer.prepayment),
        ),
        color: t.success,
      );
    }
    return Text(
      '—',
      style: DesktopTypography.tableCell.copyWith(color: t.text3),
    );
  }
}

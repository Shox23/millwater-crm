import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/phone_contact_row.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../data/models/customer.dart';
import '../../../data/repositories/crm_repository.dart';
import 'customer_form_page.dart';
import 'widgets/placeholder_avatar.dart';

/// Экран «Заказчик» — детали, финансы, контакты.
class CustomerDetailPage extends StatelessWidget {
  const CustomerDetailPage({super.key, required this.customer});

  final Customer customer;

  Future<void> _delete(BuildContext context) async {
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
    if (ok && context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _edit(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      OverlayPageRoute(builder: (_) => CustomerFormPage(customer: customer)),
    );
    if (saved == true && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lastOrder = customer.lastOrderDate == null
        ? '—'
        : DateFormat('dd.MM').format(customer.lastOrderDate!);

    return DetailScaffold(
      title: context.l10n.customerTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: [
                Row(
                  spacing: AppSpacing.md,
                  children: [
                    const PlaceholderAvatar(size: 56),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(customer.name,
                              style: AppTypography.cardTitle
                                  .copyWith(color: t.text)),
                          if (customer.comment != null)
                            Text(customer.comment!,
                                style: AppTypography.secondary
                                    .copyWith(color: t.text2)),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  spacing: 4,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: t.text2),
                    Expanded(
                      child: Text(customer.address,
                          style:
                              AppTypography.secondary.copyWith(color: t.text2)),
                    ),
                  ],
                ),
                // Кулер отмечаем только когда он есть: строка «кулера нет» у
                // большинства заказчиков была бы шумом.
                if (customer.hasCooler)
                  Row(
                    spacing: 4,
                    children: [
                      Icon(Icons.water_drop_outlined,
                          size: 16, color: t.primary),
                      Text(context.l10n.customerHasCooler,
                          style: AppTypography.secondary
                              .copyWith(color: t.primary)),
                    ],
                  ),
              ],
            ),
          ),
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: StatTile(
                  // Это остаток тары на руках (серверное `bottle_balance`),
                  // а не количество капсул в заказе.
                  value: '${customer.capsuleBalance}',
                  label: context.l10n.customerCapsulesBalance,
                ),
              ),
              Expanded(
                child: StatTile(value: lastOrder, label: context.l10n.customerLastOrder),
              ),
            ],
          ),
          // Оба поля независимы — показываем каждое ненулевое. Долг выше:
          // раньше он полностью скрывался за предоплатой.
          if (customer.debt > 0)
            _FinanceBanner(
              label: context.l10n.financeDebt,
              amount: customer.debt,
              isDebt: true,
            ),
          if (customer.prepayment > 0)
            _FinanceBanner(
              label: context.l10n.financePrepayment,
              amount: customer.prepayment,
              isDebt: false,
            ),
          AppCard(child: PhoneContactRow(phone: customer.phone)),
        ],
      ),
      bottomBar: BottomActionBar(
        child: Row(
          spacing: AppSpacing.md,
          children: [
            IconActionButton.delete(
              size: 52,
              onPressed: () => _delete(context),
            ),
            Expanded(
              child: AppButton(
                label: context.l10n.commonEdit,
                onPressed: () => _edit(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Крупный финансовый баннер (предоплата или долг) на экране деталей.
class _FinanceBanner extends StatelessWidget {
  const _FinanceBanner({
    required this.label,
    required this.amount,
    required this.isDebt,
  });

  final String label;
  final int amount;
  final bool isDebt;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tone = isDebt ? t.danger : t.success;
    final bg = isDebt ? t.dangerBg : t.successBg;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: Colors.white, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(label, style: AppTypography.badge.copyWith(color: tone)),
              MoneyText(
                amount: amount,
                numberStyle: AppTypography.statNumber
                    .copyWith(color: tone, fontSize: 20),
                currencyColor: tone,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

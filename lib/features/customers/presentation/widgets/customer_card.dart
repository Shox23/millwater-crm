import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/plurals.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/customer.dart';
import 'finance_tag.dart';
import 'placeholder_avatar.dart';

/// Карточка заказчика в списке.
class CustomerCard extends StatelessWidget {
  const CustomerCard({
    super.key,
    required this.customer,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final Customer customer;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final finance = FinanceTag.forCustomer(customer);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.md,
            children: [
              const PlaceholderAvatar(size: 48),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(customer.name,
                        style: AppTypography.cardTitle.copyWith(color: t.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Row(
                      spacing: 4,
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 15, color: t.text2),
                        Expanded(
                          child: Text(
                            customer.address,
                            style: AppTypography.secondary
                                .copyWith(color: t.text2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                spacing: AppSpacing.sm,
                children: [
                  IconActionButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Редактировать',
                    onPressed: onEdit,
                  ),
                  IconActionButton.delete(onPressed: onDelete),
                ],
              ),
            ],
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.md,
              children: [
                Expanded(child: _CapsuleTag(customer: customer)),
                ?finance,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Светлый тег «N капсул · посл. заказ DD.MM».
class _CapsuleTag extends StatelessWidget {
  const _CapsuleTag({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lastOrder = customer.lastOrderDate == null
        ? '—'
        : DateFormat('dd.MM').format(customer.lastOrderDate!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          Icon(Icons.water_drop_outlined, size: 18, color: t.aqua),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(Plurals.capsules(customer.capsuleBalance),
                    style: AppTypography.bodyStrong
                        .copyWith(fontSize: 14, color: t.text)),
                Text('посл. заказ $lastOrder',
                    style: AppTypography.secondary
                        .copyWith(fontSize: 12, color: t.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

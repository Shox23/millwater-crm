import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/customer.dart';
import 'activity_background.dart';
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
    final finance = FinanceTag.forCustomer(context.l10n, customer);

    return AppCard(
      onTap: onTap,
      // Замолчавший заказчик виден ещё до того, как админ прочитал дату
      // последнего заказа в теге ниже.
      color: activityBackground(t, customer.activityOn(DateTime.now())),
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
                    // Кулеры и своя цена — то, чем этот заказчик отличается
                    // от остальных. Обычному не показываем ни строки: пустой
                    // признак у большинства карточек был бы шумом.
                    if (customer.hasCooler || customer.hasIndividualPrice)
                      // Wrap, а не Row: рядом с кнопками правки и удаления на
                      // строку двух пометок не хватает, и цена обрезалась до
                      // «Своя ц…» — то есть исчезало ровно то число, ради
                      // которого пометка и стоит. Не поместились — вторая
                      // уходит на следующую строку целиком.
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: 4,
                        children: [
                          if (customer.hasCooler)
                            _MarkerText(
                              icon: Icons.water_drop_outlined,
                              text: context.l10n
                                  .coolersCount(customer.coolerCount),
                            ),
                          if (customer.hasIndividualPrice)
                            _MarkerText(
                              icon: Icons.sell_outlined,
                              text: context.l10n.customerCustomPrice(
                                MoneyFormatter.amount(
                                  customer.customWaterPrice!,
                                ),
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
                    tooltip: context.l10n.commonEdit,
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
                // Один бейдж занимает свою ширину, как и раньше. Два делят
                // остаток поровну — иначе на узкой карточке они выдавливают
                // блок с капсулами.
                if (finance.length == 1) finance.single,
                if (finance.length > 1)
                  for (final tag in finance) Expanded(child: tag),
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
                Text(context.l10n.capsulesCount(customer.capsuleBalance),
                    style: AppTypography.bodyStrong
                        .copyWith(fontSize: 14, color: t.text)),
                Text(context.l10n.customerLastOrderShort(lastOrder),
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

/// Отличительный признак заказчика в карточке: иконка и короткая подпись.
class _MarkerText extends StatelessWidget {
  const _MarkerText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Icon(icon, size: 14, color: t.primary),
        Flexible(
          child: Text(
            text,
            style: AppTypography.secondary.copyWith(color: t.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

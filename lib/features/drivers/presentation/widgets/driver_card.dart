import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/plurals.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/initials_avatar.dart';
import '../../../../data/models/driver.dart';

/// Карточка водителя в списке.
class DriverCard extends StatelessWidget {
  const DriverCard({
    super.key,
    required this.driver,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final Driver driver;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      onTap: onTap,
      child: Row(
        spacing: AppSpacing.md,
        children: [
          InitialsAvatar(name: driver.fullName, size: 48),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  driver.fullName,
                  style: AppTypography.cardTitle.copyWith(color: t.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: Plurals.trips(driver.tripCount)),
                      const TextSpan(text: '  ·  сегодня '),
                      TextSpan(
                        text: '${driver.todayTripCount}',
                        style: TextStyle(
                          color: t.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    style: AppTypography.secondary.copyWith(color: t.text2),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    );
  }
}

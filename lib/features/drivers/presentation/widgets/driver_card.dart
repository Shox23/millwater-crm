import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/uz_phone.dart';
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
                // ТЗ требует телефон в списке. Почта осталась в карточке:
                // в строку она не влезает, а звонят водителю по телефону.
                Text(
                  UzPhone.format(driver.phone),
                  style: AppTypography.secondary.copyWith(color: t.text2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                          text: context.l10n.tripsCount(driver.tripCount)),
                      // Разделитель принадлежит вёрстке, а не переводу:
                      // раньше эти пробелы стояли внутри строки локали, и
                      // первый же переводчик, не видящий экрана, стёр бы их.
                      const TextSpan(text: '  ·  '),
                      TextSpan(text: context.l10n.driverTripsAndToday),
                      const TextSpan(text: ' '),
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
                tooltip: context.l10n.commonEdit,
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

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
import '../../../core/widgets/contact_row.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/phone_contact_row.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/driver.dart';
import '../../../data/repositories/crm_repository.dart';
import 'driver_form_page.dart';

/// Экран «Водитель» — детали, статы, контакты.
class DriverDetailPage extends StatelessWidget {
  const DriverDetailPage({super.key, required this.driver});

  final Driver driver;

  Future<void> _delete(BuildContext context) async {
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
    if (ok && context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _edit(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      OverlayPageRoute(builder: (_) => DriverFormPage(driver: driver)),
    );
    if (saved == true && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final onRoute = driver.todayTripCount > 0;

    return DetailScaffold(
      title: context.l10n.driverTitle,
      body: Column(
        spacing: AppSpacing.lg,
        children: [
          Column(
            spacing: AppSpacing.md,
            children: [
              InitialsAvatar(name: driver.fullName, size: 88),
              Text(driver.fullName,
                  style: AppTypography.screenTitle
                      .copyWith(fontSize: 22, color: t.text)),
              // Признака «на линии» в API нет — показываем активность за сегодня.
              StatusBadge(
                text: onRoute ? context.l10n.driverOnRoute : context.l10n.driverNoTrips,
                tone: onRoute ? StatusTone.success : StatusTone.neutral,
                showDot: true,
              ),
            ],
          ),
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: StatTile(
                  value: '${driver.tripCount}',
                  label: context.l10n.driverTripsTotal,
                  alignment: CrossAxisAlignment.center,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${driver.todayTripCount}',
                  label: context.l10n.driverTripsToday,
                  valueColor: t.primary,
                  alignment: CrossAxisAlignment.center,
                ),
              ),
            ],
          ),
          AppCard(
            child: Column(
              spacing: AppSpacing.md,
              children: [
                PhoneContactRow(phone: driver.phone),
                const Divider(),
                ContactRow(
                  icon: Icons.event_outlined,
                  label: context.l10n.driverCreatedAt,
                  value: DateFormat('dd.MM.yyyy').format(driver.createdAt),
                ),
              ],
            ),
          ),
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

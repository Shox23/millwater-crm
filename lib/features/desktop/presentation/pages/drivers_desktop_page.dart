import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/load_more_notifier.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/uz_phone.dart';
import '../../../../core/widgets/initials_avatar.dart';
import '../../../../data/models/driver.dart';
import '../../../drivers/bloc/drivers_bloc.dart';
import '../../theme/desktop_typography.dart';
import '../../widgets/desktop_badge.dart';
import '../../widgets/desktop_button.dart';
import '../../widgets/desktop_cards.dart';
import '../../widgets/desktop_empty.dart';
import '../../widgets/desktop_segmented.dart';

/// Раздел «Водители»: сетка карточек по три в ряд.
///
/// Над сеткой — переключатель «Активные / Неактивные». Списки разные блоки:
/// активные — общий [DriversBloc] оболочки (его же читают сайдбар и касса),
/// неактивные — отдельный [InactiveDriversBloc], см. его описание.
class DriversDesktopPage extends StatelessWidget {
  const DriversDesktopPage({
    super.key,
    required this.inactive,
    required this.onInactiveChanged,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onActivate,
  });

  /// Показан список неактивных водителей.
  final bool inactive;
  final ValueChanged<bool> onInactiveChanged;
  final ValueChanged<Driver> onOpen;
  final ValueChanged<Driver> onEdit;
  final ValueChanged<Driver> onDelete;

  /// Вернуть неактивного водителя в работу.
  final ValueChanged<Driver> onActivate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final DriversBloc bloc = inactive
        ? context.read<InactiveDriversBloc>()
        : context.read<DriversBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
          child: SizedBox(
            width: 320,
            child: DesktopSegmented<bool>(
              options: [
                (false, l10n.driversFilterActive),
                (true, l10n.filterInactive),
              ],
              value: inactive,
              onChanged: onInactiveChanged,
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<DriversBloc, DriversState>(
            bloc: bloc,
            builder: (context, state) => _content(context, bloc, state),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, DriversBloc bloc, DriversState state) {
    if (state.status == DriversStatus.initial ||
        (state.status == DriversStatus.loading && state.drivers.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == DriversStatus.error) {
      return DesktopEmpty(
        icon: Icons.cloud_off_outlined,
        title: context.l10n.driversLoadFailed,
      );
    }

    final drivers = state.visible;
    if (drivers.isEmpty) {
      return DesktopEmpty(
        icon: inactive
            ? Icons.person_off_outlined
            : Icons.local_shipping_outlined,
        title: state.isEmptySearch
            ? context.l10n.emptySearchTitle(state.query)
            : inactive
                ? context.l10n.driversInactiveEmptyTitle
                : context.l10n.driversEmptyTitle,
        hint: state.isEmptySearch
            ? context.l10n.emptySearchHint
            : inactive
                ? context.l10n.driversInactiveEmptyHint
                : context.l10n.driversEmptyHint,
      );
    }

    return LoadMoreNotifier(
      onLoadMore: () => bloc.add(const DriversNextPageRequested()),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.lg,
            // Высота под аватар, две плитки статистики и ряд кнопок.
            mainAxisExtent: 246,
          ),
          itemCount: drivers.length,
          itemBuilder: (context, i) => _DriverCard(
            driver: drivers[i],
            inactive: inactive,
            onOpen: () => onOpen(drivers[i]),
            onEdit: () => onEdit(drivers[i]),
            onDelete: () => onDelete(drivers[i]),
            onActivate: () => onActivate(drivers[i]),
          ),
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.inactive,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onActivate,
  });

  final Driver driver;

  /// Карточка из списка неактивных: вместо правки и удаления — возврат.
  final bool inactive;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final onLine = !inactive && driver.todayTripCount > 0;

    return DesktopCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: [
          Row(
            spacing: AppSpacing.md,
            children: [
              InitialsAvatar(name: driver.fullName, size: 54, radius: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      driver.fullName,
                      style: DesktopTypography.cardTitle.copyWith(
                        color: t.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      UzPhone.format(driver.phone),
                      style: DesktopTypography.secondary.copyWith(
                        color: t.text2,
                      ),
                    ),
                  ],
                ),
              ),
              DesktopBadge(
                text: inactive
                    ? l10n.driverInactive
                    : onLine
                        ? l10n.desktopOnLine
                        : l10n.desktopFree,
                color: inactive
                    ? t.danger
                    : onLine
                        ? t.success
                        : t.text2,
                showDot: true,
              ),
            ],
          ),
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: _Stat(
                  value: '${driver.tripCount}',
                  label: l10n.driverTripsTotal,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '${driver.todayTripCount}',
                  label: l10n.driverTripsToday,
                  // Сегодняшние поездки — то, ради чего в этот раздел заходят.
                  valueColor: t.primary,
                ),
              ),
            ],
          ),
          if (inactive)
            DesktopButton(
              label: l10n.driverActivate,
              icon: Icons.restore_rounded,
              variant: DesktopButtonVariant.soft,
              expand: true,
              onPressed: onActivate,
            )
          else
            Row(
              spacing: AppSpacing.md,
              children: [
                Expanded(
                  child: DesktopButton(
                    label: l10n.commonEdit,
                    variant: DesktopButtonVariant.soft,
                    expand: true,
                    onPressed: onEdit,
                  ),
                ),
                DesktopIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: l10n.commonDelete,
                  size: 40,
                  color: t.danger,
                  onPressed: onDelete,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 1,
        children: [
          Text(
            value,
            style: DesktopTypography.kpiValue.copyWith(
              color: valueColor ?? t.text,
            ),
          ),
          Text(
            label,
            style: DesktopTypography.caption.copyWith(color: t.text2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

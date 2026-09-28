import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/day.dart';
import '../../../../core/widgets/initials_avatar.dart';
import '../../../../data/models/driver.dart';
import '../../../../l10n/l10n.dart';

/// Дата и водитель маршрута — два чипа в шапке.
///
/// Раньше это были две секции с радиокнопками на всех водителей: первые
/// 340px экрана уходили на то, что в девяти случаях из десяти остаётся
/// как есть — завтрашний день и «назначить позже».
class RouteCreateHeader extends StatelessWidget {
  const RouteCreateHeader({
    super.key,
    required this.date,
    required this.driverId,
    required this.drivers,
    required this.onDate,
    required this.onDriver,
    this.compact = false,
  });

  final DateTime date;

  /// `null` — «Назначить позже»: маршрут-заготовку собирают заранее, а
  /// исполнителя ставят, когда станет ясно, кто свободен.
  final String? driverId;
  final List<Driver> drivers;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<String?> onDriver;
  final bool compact;

  Driver? get _driver =>
      drivers.where((d) => d.id == driverId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final driver = _driver;

    final dateChip = _Chip(
      compact: compact,
      onTap: () => _pickDate(context),
      leading: Icon(Icons.calendar_today_outlined, size: 16, color: t.primary),
      label: _dateLabel(l10n),
      hint: _dateHint(l10n),
    );

    final driverChip = _DriverChip(
      compact: compact,
      driver: driver,
      drivers: drivers,
      onDriver: onDriver,
    );

    // На телефоне чипы делят строку пополам, на десктопе стоят по своей
    // ширине справа от заголовка.
    return compact
        ? Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(child: dateChip),
              Expanded(child: driverChip),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.sm,
            children: [dateChip, driverChip],
          );
  }

  /// «Сегодня», «Завтра» или дата: у ближайших двух дней имя понятнее числа,
  /// а они и есть подавляющее большинство.
  String _dateLabel(AppLocalizations l10n) {
    final days = dayOnly(date).difference(dayOnly(DateTime.now())).inDays;
    return switch (days) {
      0 => l10n.periodToday,
      1 => l10n.routeCreateTomorrow,
      _ => DateFormat('dd.MM.yyyy').format(date),
    };
  }

  /// Число рядом с именем дня — чтобы «завтра» не приходилось считать.
  String? _dateHint(AppLocalizations l10n) {
    final days = dayOnly(date).difference(dayOnly(DateTime.now())).inDays;
    return days == 0 || days == 1 ? DateFormat('dd.MM').format(date) : null;
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    var first = dayOnly(now);
    // Сервер отвергает создание маршрута в прошлом (422 DATE_IN_PAST), так
    // что прошедших дней в календаре нет вовсе — в отличие от правки, где
    // маршрут мог быть заведён давно.
    if (date.isBefore(first)) first = dayOnly(date);

    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) onDate(dayOnly(picked));
  }
}

/// Чип водителя: аватар, имя и выбор — меню на десктопе, шторка на телефоне.
class _DriverChip extends StatelessWidget {
  const _DriverChip({
    required this.compact,
    required this.driver,
    required this.drivers,
    required this.onDriver,
  });

  final bool compact;
  final Driver? driver;
  final List<Driver> drivers;
  final ValueChanged<String?> onDriver;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final name = driver?.fullName ?? l10n.routeFormAssignLater;

    final leading = driver == null
        ? Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.surface3,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.person_outline, size: 16, color: t.text2),
          )
        : InitialsAvatar(
            name: driver!.fullName,
            size: 26,
            radius: AppRadius.sm,
          );

    final chip = _Chip(
      compact: compact,
      leading: leading,
      label: name,
      trailing: Icon(Icons.expand_more_rounded, size: 18, color: t.text3),
      onTap: compact ? () => _pickInSheet(context) : null,
    );

    // На десктопе меню якорится к чипу: список водителей короткий, и
    // отдельная шторка ради трёх строк была бы лишним шагом.
    if (compact) return chip;
    return PopupMenuButton<String?>(
      tooltip: l10n.routeCreateDriverTitle,
      position: PopupMenuPosition.under,
      initialValue: driver?.id,
      onSelected: onDriver,
      itemBuilder: (context) => [
        PopupMenuItem(value: null, child: Text(l10n.routeFormAssignLater)),
        for (final d in drivers)
          PopupMenuItem(value: d.id, child: Text(d.fullName)),
      ],
      child: chip,
    );
  }

  Future<void> _pickInSheet(BuildContext context) async {
    final l10n = context.l10n;
    final t = context.tokens;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.routeCreateDriverTitle,
                style: AppTypography.sectionLabel.copyWith(color: t.text2),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _DriverTile(
                    title: l10n.routeFormAssignLater,
                    subtitle: l10n.routeFormAssignLaterHint,
                    selected: driver == null,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onDriver(null);
                    },
                  ),
                  for (final d in drivers)
                    _DriverTile(
                      title: d.fullName,
                      subtitle: d.phone,
                      selected: d.id == driver?.id,
                      leading: InitialsAvatar(name: d.fullName, size: 40),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onDriver(d.id);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverTile extends StatelessWidget {
  const _DriverTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      onTap: onTap,
      leading: leading ?? Icon(Icons.person_off_outlined, color: t.text2),
      title: Text(title,
          style: AppTypography.bodyStrong.copyWith(color: t.text)),
      subtitle: Text(subtitle,
          style: AppTypography.secondary.copyWith(color: t.text2)),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: t.primary)
          : null,
    );
  }
}

/// Компактный чип шапки: иконка, подпись и необязательная приписка.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.compact,
    required this.leading,
    required this.label,
    this.hint,
    this.trailing,
    this.onTap,
  });

  final bool compact;
  final Widget leading;
  final String label;
  final String? hint;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final body = Container(
      height: compact ? 48 : 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        spacing: AppSpacing.sm,
        children: [
          leading,
          Flexible(
            child: Text(
              label,
              style: AppTypography.secondary
                  .copyWith(color: t.text, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hint != null)
            Text(hint!, style: AppTypography.badge.copyWith(color: t.text2)),
          ?trailing,
        ],
      ),
    );

    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: body,
      ),
    );
  }
}

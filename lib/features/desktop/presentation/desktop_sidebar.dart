import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/theme_cubit.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../data/models/driver.dart';
import '../../customers/bloc/customers_bloc.dart';
import '../../drivers/bloc/drivers_bloc.dart';
import '../theme/desktop_typography.dart';
import '../widgets/desktop_badge.dart';
import '../widgets/desktop_segmented.dart';
import 'desktop_section.dart';

/// Боковая панель: навигация, сводка по смене, тема и учётная запись.
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.section,
    required this.onSectionChanged,
    required this.routesBadge,
  });

  final DesktopSection section;
  final ValueChanged<DesktopSection> onSectionChanged;

  /// Незавершённые доставки за выбранный день. `null` — ещё грузятся.
  final int? routesBadge;

  static const width = 252.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: t.sidebar,
        border: Border(right: BorderSide(color: t.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xl,
        children: [
          const _Brand(),
          _Nav(
            section: section,
            onSectionChanged: onSectionChanged,
            routesBadge: routesBadge,
          ),
          const _OnLineToday(),
          const Spacer(),
          const _ThemeSwitch(),
          const _UserCard(),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Row(
      spacing: AppSpacing.md,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: t.primary,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.water_drop_rounded,
              color: Colors.white, size: 21),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              Text(context.l10n.appTitle,
                  style: DesktopTypography.brand.copyWith(color: t.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(context.l10n.desktopBrandSubtitle,
                  style: DesktopTypography.brandSub.copyWith(color: t.text2)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({
    required this.section,
    required this.onSectionChanged,
    required this.routesBadge,
  });

  final DesktopSection section;
  final ValueChanged<DesktopSection> onSectionChanged;
  final int? routesBadge;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Должников считаем по уже загруженному справочнику: отдельный запрос
    // с фильтром `has_debt` ради одной цифры в меню не нужен.
    final debtors = context.select<CustomersBloc, int>(
      (b) => b.state.customers.where((c) => c.debt > 0).length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(context.l10n.desktopNavGroup,
              style: DesktopTypography.navGroup.copyWith(color: t.text3)),
        ),
        for (final item in DesktopSection.values)
          _NavItem(
            section: item,
            active: item == section,
            onTap: () => onSectionChanged(item),
            badge: switch (item) {
              DesktopSection.routes when (routesBadge ?? 0) > 0 =>
                DesktopCountBadge(count: routesBadge!, color: t.primary),
              DesktopSection.customers when debtors > 0 =>
                DesktopCountBadge(count: debtors, color: t.danger),
              _ => null,
            },
          ),
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.section,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final DesktopSection section;
  final bool active;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = widget.active ? t.primary : t.text2;

    return Semantics(
      button: true,
      selected: widget.active,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: widget.active
                  ? t.primarySoft
                  : (_hovered ? t.surface2 : Colors.transparent),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              spacing: AppSpacing.md,
              children: [
                Icon(widget.section.icon, size: 20, color: color),
                Expanded(
                  child: Text(
                    widget.section.label(context.l10n),
                    style: (widget.active
                            ? DesktopTypography.navItemActive
                            : DesktopTypography.navItem)
                        .copyWith(color: color),
                  ),
                ),
                if (widget.badge != null) widget.badge!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Сколько водителей сегодня в рейсе.
class _OnLineToday extends StatelessWidget {
  const _OnLineToday();

  /// Сколько аватаров показываем, пока стопка не начнёт вылезать за панель.
  static const _maxFaces = 5;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final drivers = context.select<DriversBloc, List<Driver>>(
      (b) => b.state.drivers,
    );
    final onLine = drivers.where((d) => d.todayTripCount > 0).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: t.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Text(context.l10n.desktopOnLineTitle,
              style: DesktopTypography.navGroup.copyWith(color: t.primary)),
          Text('${onLine.length}',
              style: DesktopTypography.bigNumber.copyWith(color: t.text)),
          Text(context.l10n.desktopOnLineOf(drivers.length),
              style: DesktopTypography.caption.copyWith(color: t.text2)),
          if (onLine.isNotEmpty)
            SizedBox(
              height: 30,
              // Перекрытие -7px: стопка читается как группа, а не как список.
              child: Stack(
                children: [
                  for (final (i, driver)
                      in onLine.take(_maxFaces).indexed)
                    Positioned(
                      left: i * 23,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: t.sidebar,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InitialsAvatar(
                          name: driver.fullName,
                          size: 26,
                          radius: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch();

  @override
  Widget build(BuildContext context) {
    // Системного режима на десктопе не предлагаем — в макете два сегмента.
    // Активным подсвечиваем тот, что сейчас на экране: при `system` иначе
    // не горел бы ни один.
    final isDark = context.tokens.isDark;

    return DesktopSegmented<bool>(
      options: [
        (false, context.l10n.themeLight),
        (true, context.l10n.themeDark),
      ],
      value: isDark,
      onChanged: (dark) => context
          .read<ThemeCubit>()
          .select(dark ? ThemeMode.dark : ThemeMode.light),
    );
  }
}

/// Карточка вошедшего.
///
/// Имени у учётной записи нет: `/auth/me` отдаёт только id, телефон и роль —
/// поэтому в заголовке телефон, а под ним роль. Аватар с инициалами здесь
/// был бы выдумкой из цифр.
class _UserCard extends StatelessWidget {
  const _UserCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.border),
      ),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.person_outline, size: 20, color: t.primary),
          ),
          Expanded(
            child: Text(
              context.l10n.roleAdmin,
              style: DesktopTypography.bodyStrong.copyWith(color: t.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

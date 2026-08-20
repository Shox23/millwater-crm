import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/day.dart';
import '../bloc/day_deliveries_bloc.dart';
import '../theme/desktop_typography.dart';

/// Лента дат: два дня назад, сегодня, два вперёд.
///
/// Занимает всю ширину карточки равными табами — по макету это главный
/// переключатель раздела, а не второстепенный фильтр.
class DesktopDateTabs extends StatelessWidget {
  const DesktopDateTabs({
    super.key,
    required this.days,
    required this.selected,
    required this.meta,
    required this.onSelected,
  });

  final List<DateTime> days;
  final DateTime selected;

  /// Счётчики по дням: чем закончился день или сколько в нём запланировано.
  final Map<DateTime, DayMeta> meta;

  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = dayOnly(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: t.border),
        boxShadow: t.cardShadow,
      ),
      child: Row(
        spacing: 6,
        children: [
          for (final day in days)
            Expanded(
              child: _Tab(
                day: day,
                active: day == selected,
                isToday: day == today,
                isFuture: day.isAfter(today),
                meta: meta[day],
                onTap: () => onSelected(day),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    required this.day,
    required this.active,
    required this.isToday,
    required this.isFuture,
    required this.meta,
    required this.onTap,
  });

  final DateTime day;
  final bool active;
  final bool isToday;
  final bool isFuture;
  final DayMeta? meta;
  final VoidCallback onTap;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  /// Подпись под датой: результат дня или его план.
  String _metaLabel(AppLocalizations l10n) {
    final meta = widget.meta;
    if (meta == null || meta.total == 0) return '—';
    if (widget.isFuture) return l10n.desktopDatePlanned(meta.total);
    return '${meta.done} / ${meta.total}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final fg = widget.active ? Colors.white : t.text;
    final fgMuted = widget.active ? Colors.white70 : t.text3;

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
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: widget.active
                  ? t.primary
                  : (_hovered ? t.surface2 : Colors.transparent),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: t.primaryLine,
                        blurRadius: 18,
                        spreadRadius: -8,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              spacing: 2,
              children: [
                Text(
                  // Символы дат для активного языка поднимает
                  // GlobalMaterialLocalizations, поэтому короткое имя дня
                  // берём у intl, а не заводим свой справочник на два языка.
                  DateFormat.E(Localizations.localeOf(context).languageCode)
                      .format(widget.day)
                      .toUpperCase(),
                  style: DesktopTypography.dateTabWeekday.copyWith(
                    color: fgMuted,
                  ),
                ),
                Text(
                  // Сегодняшний день подписан словом: дату «18.08» глазами
                  // ещё надо сверить с календарём, а «сегодня» — нет.
                  widget.isToday
                      ? l10n.desktopDateToday
                      : DateFormat('dd.MM').format(widget.day),
                  style: DesktopTypography.dateTabDay.copyWith(color: fg),
                ),
                Text(
                  _metaLabel(l10n),
                  style: DesktopTypography.dateTabMeta.copyWith(color: fgMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

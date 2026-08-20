import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/search_field.dart';
import '../theme/desktop_typography.dart';
import '../widgets/desktop_button.dart';
import 'desktop_section.dart';

/// Шапка рабочей области: где мы, поиск и первичное действие раздела.
class DesktopHeader extends StatelessWidget {
  const DesktopHeader({
    super.key,
    required this.section,
    required this.subtitle,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onAdd,
    required this.hasFreshEvents,
  });

  final DesktopSection section;

  /// Строка под заголовком: счётчики базы или сводка дня.
  final String subtitle;

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  /// Перечитать активный раздел — действие кнопки уведомлений.
  final VoidCallback onRefresh;

  /// Создать водителя или заказчика; `null` — в этом разделе создавать нечего.
  final VoidCallback? onAdd;

  /// Пришло событие, которого пользователь ещё не видел.
  final bool hasFreshEvents;

  static const height = 72.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 2,
              children: [
                Text(section.title(context.l10n),
                    style:
                        DesktopTypography.sectionTitle.copyWith(color: t.text)),
                Text(subtitle,
                    style:
                        DesktopTypography.sectionSub.copyWith(color: t.text2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (section.hasSearch)
            SizedBox(
              width: 320,
              child: SearchField(
                hint: context.l10n.desktopSearchHint,
                controller: searchController,
                onChanged: onSearchChanged,
              ),
            ),
          // Точка горит, когда с сервера пришло событие: список под ним уже
          // устарел, и нажатие его перечитывает. Отдельного экрана
          // уведомлений нет — показывать там было бы нечего.
          DesktopIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: context.l10n.desktopNotifications,
            badge: hasFreshEvents,
            onPressed: onRefresh,
          ),
          if (onAdd != null)
            DesktopButton(
              label: switch (section) {
                DesktopSection.drivers => context.l10n.desktopAddDriver,
                _ => context.l10n.desktopAddCustomer,
              },
              icon: Icons.add,
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }
}

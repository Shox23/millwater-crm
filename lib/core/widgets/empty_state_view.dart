import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import 'app_button.dart';

/// Пустое состояние списка.
///
/// Пустая база и безрезультатный поиск — разные вещи: в первом случае нужна
/// кнопка «добавить первого», во втором — подсказка сбросить запрос.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.actionLabel,
    this.onAction,
  });

  /// Ничего не найдено по запросу [query].
  factory EmptyStateView.noSearchResults({
    required String query,
    required VoidCallback onClear,
  }) {
    return EmptyStateView(
      icon: Icons.search_off_rounded,
      title: 'По запросу «$query» ничего нет',
      hint: 'Проверьте написание или сбросьте поиск',
      actionLabel: 'Сбросить поиск',
      onAction: onClear,
    );
  }

  final IconData icon;
  final String title;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.surface2,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: t.text3, size: 28),
            ),
            Text(
              title,
              style: AppTypography.bodyStrong.copyWith(color: t.text),
              textAlign: TextAlign.center,
            ),
            if (hint != null)
              Text(
                hint!,
                style: AppTypography.secondary.copyWith(color: t.text2),
                textAlign: TextAlign.center,
              ),
            if (actionLabel != null && onAction != null)
              AppButton(
                label: actionLabel!,
                height: 44,
                variant: AppButtonVariant.secondary,
                onPressed: onAction,
              ),
          ],
        ),
      ),
    );
  }
}

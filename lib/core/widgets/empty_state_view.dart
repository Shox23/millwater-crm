import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

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
    this.scrollable = true,
  });

  /// Ничего не найдено по запросу [query].
  ///
  /// Локаль передаётся снаружи: фабрика — не виджет, своего контекста у неё
  /// нет, а строки нужны на языке интерфейса.
  factory EmptyStateView.noSearchResults({
    required AppLocalizations l10n,
    required String query,
    required VoidCallback onClear,
  }) {
    return EmptyStateView(
      icon: Icons.search_off_rounded,
      title: l10n.emptySearchTitle(query),
      hint: l10n.emptySearchHint,
      actionLabel: l10n.emptySearchAction,
      onAction: onClear,
    );
  }

  final IconData icon;
  final String title;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Прокручивать ли содержимое самостоятельно.
  ///
  /// `false` — когда виджет стоит внутри уже прокручиваемой страницы: свой
  /// скролл там перехватывал бы жест обновления, а `LayoutBuilder` ломает
  /// расчёт высоты в сливере.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    if (!scrollable) return content;
    // Пустое состояние делит экран с шапкой, сводкой и фильтрами. Когда места
    // хватает — центрируем; на невысоких экранах даём прокрутить, иначе
    // подсказка с кнопкой обрезаются.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
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

import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// Сегментированный выбор. [columns] задаёт число колонок сетки.
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.columns = 2,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += columns) {
      final chunk = options.skip(i).take(columns).toList();
      rows.add(Row(
        spacing: AppSpacing.md,
        children: [
          for (final option in chunk) Expanded(child: _cell(context, option)),
          // Добиваем неполный ряд, чтобы ячейки не растягивались.
          for (var k = chunk.length; k < columns; k++)
            const Expanded(child: SizedBox()),
        ],
      ));
    }
    return Column(spacing: AppSpacing.md, children: rows);
  }

  Widget _cell(BuildContext context, SegmentOption<T> option) {
    final t = context.tokens;
    final selected = option.value == value;
    return Material(
      color: selected ? t.softOf(t.primary) : t.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(option.value),
        mouseCursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? t.primary : t.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            option.label,
            style: AppTypography.bodyStrong
                .copyWith(color: selected ? t.primary : t.text),
          ),
        ),
      ),
    );
  }
}

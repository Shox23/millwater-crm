import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../theme/desktop_typography.dart';

/// Пилюля-переключатель: активный сегмент залит акцентом.
///
/// Своя, а не мобильный `SegmentedToggle`: тот раскладывает варианты сеткой
/// крупных ячеек под палец, здесь же нужна компактная пилюля под курсор.
class DesktopSegmented<T> extends StatelessWidget {
  const DesktopSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  /// Пары «значение — подпись» в порядке отображения.
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surface3,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (final (optionValue, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: optionValue == value,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => onChanged(optionValue),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: optionValue == value
                            ? t.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        label,
                        style: DesktopTypography.badgeLarge.copyWith(
                          color:
                              optionValue == value ? Colors.white : t.text2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

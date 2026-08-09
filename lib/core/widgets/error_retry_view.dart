import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import 'app_button.dart';

/// Состояние «не удалось загрузить» с кнопкой повтора.
///
/// Ставится там, где раньше висел вечный спиннер или пустой список:
/// сетевая ошибка не должна выглядеть как отсутствие данных.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    required this.onRetry,
    this.message,
    this.hint,
  });

  final VoidCallback onRetry;
  final String? message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = message ?? context.l10n.errorLoadFailed;
    final subtitle = hint ?? context.l10n.errorCheckConnection;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.dangerBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.cloud_off_rounded, color: t.danger, size: 26),
            ),
            Text(
              text,
              style: AppTypography.bodyStrong.copyWith(color: t.text),
              textAlign: TextAlign.center,
            ),
            Text(
                subtitle,
                style: AppTypography.secondary.copyWith(color: t.text2),
                textAlign: TextAlign.center,
              ),
            // Ширину не фиксируем: при увеличенном системном шрифте
            // подпись с иконкой перестаёт помещаться в жёсткий размер.
            AppButton(
              label: context.l10n.commonRetry,
              icon: Icons.refresh,
              height: 44,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

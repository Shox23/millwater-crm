import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';

/// Диалог подтверждения действия. Возвращает true при согласии.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final t = context.tokens;
      return AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(title,
            style: AppTypography.cardTitle.copyWith(color: t.text)),
        content: Text(message,
            style: AppTypography.secondary.copyWith(color: t.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel ?? context.l10n.commonCancelShort,
                style: AppTypography.bodyStrong.copyWith(color: t.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirmLabel ?? context.l10n.commonDelete,
              style: AppTypography.bodyStrong
                  .copyWith(color: destructive ? t.danger : t.primary),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

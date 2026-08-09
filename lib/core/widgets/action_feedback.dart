import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import '../../data/network/api_envelope.dart';

/// Короткое уведомление в стиле приложения.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final t = context.tokens;
  // Фон обычного снек-бара — цвет текста темы: в светлой теме он тёмный,
  // в тёмной — почти белый. Поэтому подпись берётся с поверхности, а не
  // белым: белым по светлому фону в тёмной теме читать было нечего.
  // У ошибки фон красный в обеих темах — там белый подходит.
  final foreground = isError ? Colors.white : t.surface;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.secondary.copyWith(color: foreground),
        ),
        backgroundColor: isError ? t.danger : t.text,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: const EdgeInsets.all(AppSpacing.page),
        duration: const Duration(seconds: 4),
      ),
    );
}

/// Выполняет [action] и показывает ошибку снек-баром. Возвращает true при успехе.
///
/// Нужен там, где действие запускается из списка и своего места под текст
/// ошибки на экране нет: удаление, отмена маршрута.
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  required String fallback,
}) async {
  try {
    await action();
    return true;
  } on DioException catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, apiErrorMessage(context.l10n, e, fallback: fallback),
          isError: true);
    }
  } catch (_) {
    if (context.mounted) showAppSnackBar(context, fallback, isError: true);
  }
  return false;
}

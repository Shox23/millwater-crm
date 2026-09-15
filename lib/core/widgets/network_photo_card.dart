import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import '../../data/network/api_config.dart';

/// Фото с сервера под подписью — карточкой, с состоянием ошибки загрузки.
///
/// Вынесено из точки маршрута ([lib/features/routes/presentation/stop_detail_page.dart])
/// в общий виджет: то же фото оплаты нужно показывать и в карточке заказа
/// (`_PaymentRow`) — сервер отдаёт `payment_photo`/`photo_url` в обоих ответах,
/// и заводить вторую копию разметки ради одной картинки незачем.
class NetworkPhotoCard extends StatelessWidget {
  const NetworkPhotoCard({super.key, required this.label, required this.url});

  final String label;
  final String url;

  /// Сервер может отдать как полный URL, так и путь относительно API.
  String get _absolute =>
      url.startsWith('http') ? url : '${ApiConfig.baseUrl}/$url';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Text(label, style: AppTypography.fieldLabel.copyWith(color: t.text2)),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Image.network(
            _absolute,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              color: t.surface2,
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  Icon(Icons.broken_image_outlined, size: 20, color: t.text2),
                  Expanded(
                    child: Text(context.l10n.stopPhotoFailed,
                        style:
                            AppTypography.secondary.copyWith(color: t.text2)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

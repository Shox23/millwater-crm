import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/phone_contact_row.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/route_models.dart';
import '../../../data/network/api_config.dart';
import 'widgets/route_card.dart';

/// Точка маршрута глазами администратора — только просмотр.
///
/// Завершать доставку админ не может: `/driver/routes/customers/{id}/complete`
/// доступен лишь водителю маршрута, сервер отвечает 403.
class StopDetailPage extends StatelessWidget {
  const StopDetailPage({super.key, required this.stop});

  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final completedAt = stop.completedAt;

    return DetailScaffold(
      title: context.l10n.stopTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: [
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Expanded(
                      child: Text(stop.customerName,
                          style:
                              AppTypography.cardTitle.copyWith(color: t.text)),
                    ),
                    StatusBadge(
                      text: stop.status.label(context.l10n),
                      tone: deliveryTone(stop.status),
                    ),
                  ],
                ),
                Row(
                  spacing: 4,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: t.text2),
                    Expanded(
                      child: Text(stop.customerAddress,
                          style:
                              AppTypography.secondary.copyWith(color: t.text2)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: StatTile(
                  value: '${stop.deliveredCapsules ?? 0}',
                  label: context.l10n.stopCapsulesDelivered,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: MoneyFormatter.sum(context.l10n, stop.paymentAmount ?? 0),
                  label: context.l10n.stopPaid,
                ),
              ),
            ],
          ),
          if (completedAt != null)
            AppCard(
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  Icon(Icons.schedule_outlined, size: 20, color: t.text2),
                  Expanded(
                    child: Text(context.l10n.stopCompleted,
                        style:
                            AppTypography.secondary.copyWith(color: t.text2)),
                  ),
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(completedAt),
                    style: AppTypography.bodyStrong.copyWith(color: t.text),
                  ),
                ],
              ),
            ),
          if (stop.paymentPhoto case final String photo)
            _PaymentPhoto(url: photo),
          AppCard(child: PhoneContactRow(phone: stop.customerPhone)),
        ],
      ),
    );
  }
}

/// Фото оплаты, приложенное водителем при завершении доставки.
class _PaymentPhoto extends StatelessWidget {
  const _PaymentPhoto({required this.url});

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
        Text(context.l10n.stopPhotoLabel,
            style: AppTypography.fieldLabel.copyWith(color: t.text2)),
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

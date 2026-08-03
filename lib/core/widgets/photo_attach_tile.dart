import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import 'app_card.dart';

/// Плитка «Фото оплаты» — плейсхолдер прикрепления.
class PhotoAttachTile extends StatelessWidget {
  const PhotoAttachTile({
    super.key,
    this.title = 'Фото оплаты',
    this.subtitle = 'Прикрепите чек или фото доставки',
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      onTap: onTap,
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.add_a_photo_outlined, size: 20, color: t.text2),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(title,
                    style: AppTypography.bodyStrong.copyWith(color: t.text)),
                Text(subtitle,
                    style: AppTypography.secondary.copyWith(color: t.text2)),
              ],
            ),
          ),
          // Прикрепление ещё не реализовано: плитка не должна выглядеть
          // как рабочая кнопка, которая молча ничего не делает.
          if (onTap == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: t.surface2,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('Скоро',
                  style: AppTypography.badge.copyWith(color: t.text3)),
            ),
        ],
      ),
    );
  }
}

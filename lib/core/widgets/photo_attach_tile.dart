import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/l10n.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Прикрепление фото оплаты: камера или галерея, превью, удаление.
///
/// Наружу отдаётся [XFile] — отправкой занимается репозиторий
/// (`payment_photo` в multipart-теле завершения доставки).
class PhotoAttachTile extends StatefulWidget {
  const PhotoAttachTile({
    super.key,
    required this.photo,
    required this.onChanged,
    this.enabled = true,
    this.title,
    this.subtitle,
  });

  final XFile? photo;
  final ValueChanged<XFile?> onChanged;
  final bool enabled;
  final String? title;
  final String? subtitle;

  @override
  State<PhotoAttachTile> createState() => _PhotoAttachTileState();
}

class _PhotoAttachTileState extends State<PhotoAttachTile> {
  final _picker = ImagePicker();
  String? _error;

  Future<void> _pick(ImageSource source) async {
    setState(() => _error = null);
    try {
      final file = await _picker.pickImage(
        source: source,
        // Чек читаемый и на 1600 px, а водителю ещё отправлять это с мобильного.
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (file != null) widget.onChanged(file);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.photoError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final photo = widget.photo;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Row(
            spacing: AppSpacing.md,
            children: [
              _Thumb(photo: photo),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(widget.title ?? context.l10n.photoTitle,
                        style:
                            AppTypography.bodyStrong.copyWith(color: t.text)),
                    photo == null
                        ? Text(widget.subtitle ?? context.l10n.photoSubtitle,
                            style: AppTypography.secondary
                                .copyWith(color: t.text2))
                        : _FileLabel(photo: photo),
                  ],
                ),
              ),
              if (photo != null && widget.enabled)
                IconActionButton(
                  icon: Icons.close_rounded,
                  tooltip: context.l10n.photoRemove,
                  onPressed: () => widget.onChanged(null),
                ),
            ],
          ),
          if (photo == null && widget.enabled)
            Row(
              spacing: AppSpacing.md,
              children: [
                Expanded(
                  child: AppButton(
                    label: context.l10n.photoCamera,
                    icon: Icons.photo_camera_outlined,
                    height: 44,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _pick(ImageSource.camera),
                  ),
                ),
                Expanded(
                  child: AppButton(
                    label: context.l10n.photoGallery,
                    icon: Icons.photo_library_outlined,
                    height: 44,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _pick(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          if (_error != null)
            Text(_error!,
                style: AppTypography.secondary.copyWith(color: t.danger)),
        ],
      ),
    );
  }
}

/// Имя файла и размер — водителю важно понимать, что именно уедет.
class _FileLabel extends StatelessWidget {
  const _FileLabel({required this.photo});

  final XFile photo;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = AppTypography.secondary.copyWith(color: t.text2);

    return FutureBuilder<int>(
      future: photo.length(),
      builder: (context, snapshot) {
        final size = snapshot.data;
        final suffix = size == null ? '' : context.l10n.photoSize((size / 1024).round());
        return Text(
          '${photo.name}$suffix',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

/// Превью прикреплённого снимка либо иконка-заглушка.
///
/// Читаем байтами, а не через `Image.file`: так виджет остаётся без `dart:io`
/// и не ломает веб-сборку админской части.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo});

  final XFile? photo;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final photo = this.photo;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 44,
        height: 44,
        color: t.surface2,
        alignment: Alignment.center,
        child: photo == null
            ? Icon(Icons.add_a_photo_outlined, size: 20, color: t.text2)
            : FutureBuilder<Uint8List>(
                future: photo.readAsBytes(),
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null) {
                    return Icon(Icons.image_outlined, size: 20, color: t.text2);
                  }
                  return Image.memory(
                    bytes,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      size: 20,
                      color: t.text2,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

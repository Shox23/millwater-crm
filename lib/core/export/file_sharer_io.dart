import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'mime_types.dart';

/// Мобильная и десктопная реализация: временный файл + системный лист
/// «Поделиться».
Future<void> shareFile({
  required Uint8List bytes,
  required String filename,
  String? subject,
}) async {
  // Временный каталог, а не «Документы»: файл нужен ровно до того момента,
  // как пользователь выберет, куда его отправить. Система вычистит сама.
  final dir = await getTemporaryDirectory();
  final file = XFile.fromData(
    bytes,
    name: filename,
    mimeType: kXlsxMimeType,
    // Без пути share_plus на iOS отдаёт файл без имени, и в «Файлах» он
    // сохраняется как безымянный.
    path: '${dir.path}/$filename',
  );
  await file.saveTo('${dir.path}/$filename');

  await SharePlus.instance.share(
    ShareParams(files: [file], subject: subject),
  );
}

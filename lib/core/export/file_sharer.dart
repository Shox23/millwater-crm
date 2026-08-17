import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Отдаёт полученный файл системе: сохраняет и открывает «Поделиться».
///
/// Вынесено за интерфейс, потому что и файловая система, и системный лист
/// «Поделиться» — платформенные каналы: в тестах вместо них подставляется
/// [RecordingFileSharer].
abstract class FileSharer {
  /// Сохраняет [bytes] под именем [filename] и предлагает, что с ним сделать.
  ///
  /// [subject] — заголовок письма, если файл уходит почтой.
  Future<void> share({
    required Uint8List bytes,
    required String filename,
    String? subject,
  });
}

/// Боевая реализация: временный каталог + системный лист «Поделиться».
class PlatformFileSharer implements FileSharer {
  const PlatformFileSharer();

  @override
  Future<void> share({
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
      mimeType: _xlsxMimeType,
      // Без пути share_plus на iOS отдаёт файл без имени, и в «Файлах» он
      // сохраняется как безымянный.
      path: '${dir.path}/$filename',
    );
    await file.saveTo('${dir.path}/$filename');

    await SharePlus.instance.share(
      ShareParams(files: [file], subject: subject),
    );
  }

  static const _xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
}

/// Реализация для тестов: запоминает, что просили отдать.
class RecordingFileSharer implements FileSharer {
  final List<({String filename, int size})> shared = [];

  @override
  Future<void> share({
    required Uint8List bytes,
    required String filename,
    String? subject,
  }) async {
    shared.add((filename: filename, size: bytes.length));
  }
}

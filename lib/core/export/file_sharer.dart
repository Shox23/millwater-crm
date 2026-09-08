import 'dart:typed_data';

import 'file_sharer_io.dart'
    if (dart.library.js_interop) 'file_sharer_web.dart' as platform;

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

/// Боевая реализация. Способ отдать файл зависит от платформы и живёт в
/// `file_sharer_io.dart` / `file_sharer_web.dart`: на телефоне это временный
/// файл и системный лист «Поделиться», в браузере — скачивание по ссылке на
/// Blob, потому что веб-реализации `path_provider` не существует.
class PlatformFileSharer implements FileSharer {
  const PlatformFileSharer();

  @override
  Future<void> share({
    required Uint8List bytes,
    required String filename,
    String? subject,
  }) =>
      platform.shareFile(
        bytes: bytes,
        filename: filename,
        subject: subject,
      );
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

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'mime_types.dart';

/// Веб-реализация: браузер скачивает файл по ссылке на Blob.
///
/// `path_provider` веб не поддерживает — временного каталога, в который
/// пишет мобильная реализация, здесь просто нет. Системный лист «Поделиться»
/// тоже не годится: за компьютером отчёт открывают в Excel, а не отправляют
/// из браузера, и Web Share API для файлов на десктопе обычно недоступен.
///
/// Blob, а не `data:`-ссылка: адрес с base64 внутри раздувается на треть от
/// размера файла, и месячная выгрузка упёрлась бы в ограничения браузера.
///
/// [subject] здесь не нужен — это тема письма для системного «Поделиться».
Future<void> shareFile({
  required Uint8List bytes,
  required String filename,
  String? subject,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: kXlsxMimeType),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  web.URL.revokeObjectURL(url);
}

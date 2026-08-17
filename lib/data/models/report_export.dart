import 'dart:typed_data';

/// Выгрузка отчёта: файл целиком плюс имя, под которым его сохранять.
///
/// Имя приходит от сервера в `Content-Disposition`. Если заголовка нет,
/// собираем своё из периода — иначе файл лёг бы на устройство под именем
/// вида `export`, без расширения, и Excel его не открыл бы.
class ReportExport {
  const ReportExport({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  int get sizeBytes => bytes.length;
}

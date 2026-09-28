import 'package:crm_millwater/core/utils/cancel_reason.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// Причина отмены на экране.
///
/// Сервер при завершении маршрута отменяет открытые точки с русским текстом,
/// зашитым у него; узбекский интерфейс показывал его как есть.
void main() {
  test('серверная причина завершения маршрута локализуется', () async {
    final ru = await AppLocalizations.delegate.load(AppLocales.ru);
    final uz = await AppLocalizations.delegate.load(AppLocales.uz);

    expect(cancelReasonLabel(ru, routeCompletionCancelReason),
        'Не выполнен до завершения маршрута');
    expect(cancelReasonLabel(uz, routeCompletionCancelReason),
        'Marshrut yakunlangunga qadar bajarilmadi');
  });

  test('чужая причина — как есть, пустая — заглушка', () async {
    final ru = await AppLocalizations.delegate.load(AppLocales.ru);

    expect(cancelReasonLabel(ru, 'Не открыл дверь'), 'Не открыл дверь');
    expect(cancelReasonLabel(ru, null), 'Причина не указана');
    expect(cancelReasonLabel(ru, ''), 'Причина не указана');
    // Строгое сравнение: поменяет сервер текст — вернётся его русский.
    expect(cancelReasonLabel(ru, '$routeCompletionCancelReason.'),
        '$routeCompletionCancelReason.');
  });
}

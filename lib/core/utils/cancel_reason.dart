import '../../l10n/l10n.dart';

/// Причина, которую сервер сам ставит точкам, отменённым при завершении
/// маршрута (`POST /driver/routes/{id}/complete`). Текст зашит на сервере
/// по-русски и локали не знает.
const routeCompletionCancelReason = 'Заказ не выполнен до завершения маршрута';

/// Причина отмены для показа: серверную подменяем локализованной, чужую —
/// как есть, пустую — заглушкой.
///
/// Сравнение строгое: поменяет сервер текст — вернётся русский, и только.
String cancelReasonLabel(AppLocalizations l10n, String? reason) {
  if (reason == null || reason.isEmpty) return l10n.orderCancelReasonEmpty;
  if (reason == routeCompletionCancelReason) {
    return l10n.orderCancelReasonRouteCompleted;
  }
  return reason;
}

import 'package:flutter/material.dart';

import '../utils/date_period.dart';

/// Календарь диапазона для отчётов: телефон, десктоп и экран выгрузки
/// открывают один и тот же, чтобы границы и стартовый выбор не разошлись.
///
/// Виджет сам не даёт выбрать конец раньше начала (второй тап раньше
/// первого становится новым началом), а будущее закрыто `lastDate`:
/// отчётов вперёд не бывает. Нижняя граница — три года назад, с запасом.
///
/// `null` — пользователь закрыл календарь, ничего не выбрав.
Future<CustomPeriod?> pickCustomPeriod(
  BuildContext context, {
  DatePeriod? current,
}) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final (from, to) = current?.range ?? (today, today);

  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 3),
    lastDate: today,
    // Стартуем с текущего выбора, чем бы он ни был: с пресета календарь
    // открывается на его границах, и подправить «месяц» на «с 5-го» — один тап.
    initialDateRange: DateTimeRange(start: from, end: to),
  );
  return picked == null ? null : CustomPeriod.of(picked);
}

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import 'stats_period.dart';

/// Период отчёта: готовый пресет или диапазон, выбранный в календаре.
///
/// Sealed-класс, а не пара необязательных полей рядом с [StatsPeriod]:
/// «сегодня» и «с 3-го по 12-е» — состояния взаимоисключающие, и держать их
/// на договорённости «если даты заданы, пресет игнорируется» значило бы
/// однажды выгрузить не тот период, который показан на экране.
sealed class DatePeriod extends Equatable {
  const DatePeriod();

  /// Границы периода, обе включительно, без времени.
  (DateTime, DateTime) get range;

  /// Подпись на селекторе: название пресета либо две короткие даты.
  String label(AppLocalizations l10n);
}

/// Готовый период: сегодня, неделя, месяц.
class PresetPeriod extends DatePeriod {
  const PresetPeriod(this.period);

  final StatsPeriod period;

  @override
  (DateTime, DateTime) get range => period.range;

  @override
  String label(AppLocalizations l10n) => period.label(l10n);

  @override
  List<Object?> get props => [period];
}

/// Диапазон, выбранный руками.
///
/// Конструктор нормализует концы: время отбрасывается, а перепутанные
/// местами даты меняются обратно. Календарь (`showDateRangePicker`) сам не
/// даёт выбрать конец раньше начала, но объект может собрать и код — и
/// сервер на `date_from > date_to` вернул бы пустой отчёт молча.
class CustomPeriod extends DatePeriod {
  CustomPeriod(DateTime from, DateTime to)
      : from = _day(from.isAfter(to) ? to : from),
        to = _day(from.isAfter(to) ? from : to);

  /// Из результата календаря.
  factory CustomPeriod.of(DateTimeRange range) =>
      CustomPeriod(range.start, range.end);

  final DateTime from;
  final DateTime to;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  (DateTime, DateTime) get range => (from, to);

  @override
  String label(AppLocalizations l10n) {
    final (a, b) = formatDateRangeParts(from, to);
    return l10n.dateRangeValue(a, b);
  }

  @override
  List<Object?> get props => [from, to];
}

/// Две короткие даты для подписи диапазона.
///
/// Год ставится только когда концы приходятся на разные годы — иначе он
/// повторяется дважды и удлиняет подпись настолько, что чип уезжает за край
/// экрана. Одно место форматирования на заказы и отчёты, телефон и десктоп:
/// разойдясь, они бы подписывали один и тот же период по-разному.
(String, String) formatDateRangeParts(DateTime from, DateTime to) {
  final short = DateFormat('dd.MM');
  return (
    short.format(from),
    from.year == to.year ? short.format(to) : DateFormat('dd.MM.yy').format(to),
  );
}

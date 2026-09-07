import '../../l10n/l10n.dart';

/// Период, за который считаются показатели: сегодня, неделя, месяц.
///
/// Живёт в `core`, а не в фиче отчётов: тем же переключателем пользуются
/// админские отчёты и статистика в профиле водителя, а водителю админская
/// фича недоступна — у него в дереве нет даже её репозитория.
enum StatsPeriod {
  today,
  week,
  month;

  /// Подпись периода на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        StatsPeriod.today => l10n.periodToday,
        StatsPeriod.week => l10n.periodWeek,
        StatsPeriod.month => l10n.periodMonth,
      };

  /// Границы периода, обе включительно.
  ///
  /// Считаются одним местом на всех: посчитай их каждый экран сам — и
  /// однажды выгрузка ушла бы не за тот период, который показан рядом.
  /// Дата берётся с устройства: серверного «сегодня» в ответах нет.
  (DateTime, DateTime) get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      StatsPeriod.today => (today, today),
      StatsPeriod.week => (today.subtract(const Duration(days: 6)), today),
      StatsPeriod.month => (DateTime(now.year, now.month, 1), today),
    };
  }
}

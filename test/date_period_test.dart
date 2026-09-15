import 'package:crm_millwater/core/utils/date_period.dart';
import 'package:crm_millwater/core/utils/stats_period.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Период отчёта: пресет или диапазон из календаря.
void main() {
  final ru = lookupAppLocalizations(AppLocales.ru);

  group('CustomPeriod', () {
    test('перепутанные концы меняются местами — «от» не позже «до»', () {
      final period = CustomPeriod(DateTime(2026, 9, 12), DateTime(2026, 9, 3));

      expect(period.from, DateTime(2026, 9, 3));
      expect(period.to, DateTime(2026, 9, 12));
      expect(period.from.isAfter(period.to), isFalse);
    });

    test('время отбрасывается: границы — дни, как у routes.date', () {
      final period = CustomPeriod(
        DateTime(2026, 9, 3, 14, 30),
        DateTime(2026, 9, 12, 23, 59),
      );

      expect(period.range, (DateTime(2026, 9, 3), DateTime(2026, 9, 12)));
    });

    test('один день — допустимый диапазон', () {
      final period = CustomPeriod(DateTime(2026, 9, 3), DateTime(2026, 9, 3));

      expect(period.range, (DateTime(2026, 9, 3), DateTime(2026, 9, 3)));
    });

    test('из результата календаря', () {
      final period = CustomPeriod.of(DateTimeRange(
        start: DateTime(2026, 9, 3),
        end: DateTime(2026, 9, 12),
      ));

      expect(period, CustomPeriod(DateTime(2026, 9, 3), DateTime(2026, 9, 12)));
    });

    test('подпись — две короткие даты, год только при разных годах', () {
      expect(
        CustomPeriod(DateTime(2026, 9, 3), DateTime(2026, 9, 12)).label(ru),
        '03.09 — 12.09',
      );
      expect(
        CustomPeriod(DateTime(2025, 12, 28), DateTime(2026, 1, 4)).label(ru),
        '28.12 — 04.01.26',
      );
    });
  });

  group('PresetPeriod', () {
    test('границы и подпись берутся у пресета', () {
      const period = PresetPeriod(StatsPeriod.month);

      expect(period.range, StatsPeriod.month.range);
      expect(period.label(ru), StatsPeriod.month.label(ru));
    });

    test('сравнивается по значению', () {
      expect(
        const PresetPeriod(StatsPeriod.week),
        const PresetPeriod(StatsPeriod.week),
      );
      expect(
        const PresetPeriod(StatsPeriod.week),
        isNot(const PresetPeriod(StatsPeriod.month)),
      );
    });
  });
}

import 'dart:io';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/app/theme/app_typography.dart';
import 'package:crm_millwater/features/desktop/theme/desktop_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Шрифты лежат в сборке, а не качаются с fonts.gstatic.com при первом
/// запуске. Проверяется связка, которую легко разорвать по частям: файлы на
/// диске, объявление в pubspec и семейство в стилях.
void main() {
  const weights = [400, 500, 600, 700, 800];

  test('файлы всех объявленных начертаний лежат на диске', () {
    for (final family in ['Inter', 'Onest']) {
      for (final weight in weights) {
        final file = File('assets/fonts/$family-$weight.ttf');
        expect(file.existsSync(), isTrue, reason: '${file.path} не найден');
        // Пустой или обрезанный файл Flutter молча проигнорирует, подставив
        // системный шрифт, — интерфейс поедет, но ошибки не будет.
        expect(file.lengthSync(), greaterThan(20 * 1024),
            reason: '${file.path} подозрительно мал');
      }
    }
  });

  test('лицензии шрифтов лежат рядом — SIL OFL требует их сохранять', () {
    for (final name in ['Inter-OFL.txt', 'Onest-OFL.txt']) {
      expect(File('assets/fonts/$name').existsSync(), isTrue, reason: name);
    }
  });

  test('pubspec объявляет ровно те же файлы', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
    final fonts = (pubspec['flutter'] as Map)['fonts'] as List;

    final declared = <String, List<int>>{};
    for (final family in fonts.cast<Map>()) {
      declared[family['family'] as String] = [
        for (final f in (family['fonts'] as List).cast<Map>())
          f['weight'] as int,
      ];
    }

    expect(declared.keys, containsAll(['Inter', 'Onest']));
    for (final family in ['Inter', 'Onest']) {
      expect(declared[family], weights, reason: family);
    }
  });

  test('стили ссылаются на объявленные семейства', () {
    expect(AppTypography.fontFamily, 'Inter');
    expect(DesktopTypography.fontFamily, 'Onest');

    // Ни один стиль не должен остаться без семейства: без него текст
    // отрисуется системным шрифтом и разъедется с остальным экраном.
    final styles = <String, TextStyle>{
      'screenTitle': AppTypography.screenTitle,
      'body': AppTypography.body,
      'badge': AppTypography.badge,
      'button': AppTypography.button,
      'tableCell': DesktopTypography.tableCell,
      'kpiValue': DesktopTypography.kpiValue,
      'modalTitle': DesktopTypography.modalTitle,
    };
    styles.forEach((name, style) {
      expect(style.fontFamily, isNotNull, reason: name);
    });
  });

  test('тема отдаёт текст тем же шрифтом', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(theme.textTheme.bodyMedium?.fontFamily, AppTypography.fontFamily);
      expect(theme.inputDecorationTheme.hintStyle?.fontFamily,
          AppTypography.fontFamily);
      expect(theme.inputDecorationTheme.errorStyle?.fontFamily,
          AppTypography.fontFamily);
    }
  });

  test('используемые начертания объявлены', () {
    // Стиль с весом, которого нет в pubspec, Flutter подменит ближайшим —
    // заметить это можно только глазами на устройстве.
    final used = <TextStyle>[
      AppTypography.screenTitle,
      AppTypography.cardTitle,
      AppTypography.body,
      AppTypography.secondary,
      DesktopTypography.navItem,
      DesktopTypography.tableCell,
      DesktopTypography.kpiValue,
    ];
    for (final style in used) {
      final value = style.fontWeight!.value;
      expect(weights, contains(value),
          reason: 'вес $value не объявлен в pubspec');
    }
  });
}

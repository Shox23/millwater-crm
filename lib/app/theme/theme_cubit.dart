import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Режим темы приложения: по умолчанию следует системе.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);

  /// Переключает light → dark → system по кругу.
  void toggle() {
    emit(switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    });
  }

  /// Явный выбор режима — из настроек.
  void select(ThemeMode mode) => emit(mode);

  /// Иконка текущего режима для кнопки переключения.
  static IconData iconFor(ThemeMode mode) => switch (mode) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };

  /// Подпись режима для интерфейса.
  static String labelFor(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Как в системе',
        ThemeMode.light => 'Светлая',
        ThemeMode.dark => 'Тёмная',
      };
}

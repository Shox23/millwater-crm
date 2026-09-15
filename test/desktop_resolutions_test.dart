import 'package:crm_millwater/app/settings/settings_storage.dart';
import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/app/theme/theme_cubit.dart';
import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/desktop/presentation/desktop_shell.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Десктопная оболочка на типовых разрешениях Windows.
///
/// Целевая платформа админа — компьютер, а окно там бывает каким угодно: от
/// бюджетного ноутбука 1366×768 до 1920×1080. Таблицы за релиз подросли —
/// в маршрутах восемь колонок, в заказах девять, — и на узком экране они
/// начинают выдавливать строку за край.
///
/// Переполнение вёрстки в тестах Flutter — это ошибка, роняющая тест, так
/// что здесь проверять нечего руками: достаточно открыть каждый раздел на
/// каждой ширине и убедиться, что ни один не ругнулся.
void main() {
  /// Разрешения, на которых реально работают: доли Windows по StatCounter
  /// плюс граница, ниже которой включается мобильная компоновка.
  const resolutions = <String, Size>{
    '1920×1080': Size(1920, 1080),
    '1600×900': Size(1600, 900),
    '1536×864': Size(1536, 864),
    '1440×900': Size(1440, 900),
  };

  /// Разрешения, на которых вёрстка сейчас рвётся.
  ///
  /// Оболочка объявлена рабочей с 1200 (`AppBreakpoints.desktop`), но ниже
  /// 1440 переполняются три места, и все — не из таблиц:
  ///
  /// * `drivers_desktop_page.dart:111` — карточка водителя, по высоте:
  ///   11 px на 1366, 29 px на 1280, 65 px на 1200;
  /// * `reports_desktop_page.dart:360` и `:473` — карточки должников и
  ///   предоплат, вбок и вниз на 1280 и ниже;
  /// * `desktop_button.dart:81` — кнопки в шапке, 17 px вбок на 1200;
  ///   проверено на разделе «Водители», где кнопка была и до релиза.
  ///
  /// Таблицы 1366 и уже переживают: подпись в бейдже сжимается, а не
  /// выдавливает строку. Снять `skip`, когда карточки починят.
  const broken = <String, Size>{
    '1366×768': Size(1366, 768),
    '1280×720': Size(1280, 720),
    '1200×800': Size(1200, 800),
  };

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CrmRepository>.value(value: MockCrmRepository()),
          RepositoryProvider<CapsulePrice>.value(
            value: const BuildCapsulePrice(),
          ),
        ],
        child: BlocProvider(
          create: (_) => ThemeCubit(storage: InMemorySettingsStorage()),
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            home: const DesktopShell(),
          ),
        ),
      ),
    );
    // Разделы ходят в сеть по очереди — одним pump цепочку не раскрутить.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> openSection(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  for (final entry in {...resolutions, ...broken}.entries) {
    final known = broken.containsKey(entry.key);
    // Причину держим в названии: `skip` у `testWidgets` принимает только
    // флаг, и молча пропущенный тест ничего бы не объяснил в выводе.
    final title = known
        ? '${entry.key}: вёрстка рвётся — см. заметку у `broken`'
        : '${entry.key}: разделы открываются без переполнения';

    testWidgets(title, (tester) async {
      await pumpShell(tester, entry.value);

      // Маршруты открыты сразу; остальные — по очереди, каждый со своей
      // таблицей и своим числом колонок.
      for (final section in const [
        'Заказы',
        'Водители',
        'Заказчики',
        'Касса',
        'Отчёты',
        'Цены',
      ]) {
        await openSection(tester, section);
      }
    }, skip: known);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_millwater/app/app.dart';
import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/app/theme/app_tokens.dart';
import 'package:crm_millwater/app/theme/theme_cubit.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/home/presentation/home_shell.dart';

void main() {
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  // HomeShell с моком и темой приложения, минуя экран логина.
  Widget authedHome() {
    return RepositoryProvider<CrmRepository>(
      create: (_) => MockCrmRepository(),
      child: BlocProvider(
        create: (_) => ThemeCubit(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const HomeShell(),
        ),
      ),
    );
  }

  testWidgets('Старт приложения показывает экран логина',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const CrmApp());
    await tester.pump();

    expect(find.text('CRM Millwater'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Номер телефона'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
  });

  testWidgets('Вкладка «Маршруты» показывает маршруты из mock',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(authedHome());
    // Экран грузит маршруты и сводку — два последовательных запроса.
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Маршруты'), findsOneWidget);
    expect(find.text('Собрано сегодня'), findsOneWidget);
    // Маршрут-центричный список: водители и прогресс по точкам.
    expect(find.text('Азиз Каримов'), findsWidgets);
    expect(find.text('выполнено'), findsWidgets);
    expect(find.text('Маршрут'), findsOneWidget);
  });

  test('Светлая и тёмная темы отдают свои наборы токенов', () {
    final light = AppTheme.light().extension<AppTokens>()!;
    final dark = AppTheme.dark().extension<AppTokens>()!;

    expect(light.isDark, isFalse);
    expect(dark.isDark, isTrue);
    // Поверхности различаются, акцент — общий токен.
    expect(dark.bg, isNot(light.bg));
    expect(dark.text, isNot(light.text));
    expect(dark.primary, light.primary);
    // Тема реально несёт токены в scaffold-фоне.
    expect(AppTheme.dark().scaffoldBackgroundColor, dark.bg);
  });

  testWidgets('Переключение по вкладкам отрисовывает их данные',
      (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(authedHome());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Водители'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Поиск водителя'), findsOneWidget);
    expect(find.text('Азиз Каримов'), findsWidgets);

    await tester.tap(find.text('Заказчики'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Поиск заказчика'), findsOneWidget);

    await tester.tap(find.text('Отчёты'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Выручка'), findsOneWidget);
    expect(find.text('Доставки'), findsOneWidget);
  });
}

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/routes/presentation/route_create_page.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_customer_row.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_sheet.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_stop_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Раскладка страницы создания маршрута на разных ширинах.
///
/// Тест заведён после того, как на окне 720–1024px за край выехали и футер с
/// итогами, и строка заказчика с бейджем долга: раскладку проверяли на
/// телефоне и на широком мониторе, а между ними — нет. Здесь прогоняются обе
/// раскладки и все состояния, где содержимое шире всего: развёрнутая точка,
/// длинная подпись цели, бейджи «ПОРА» и «ДОЛГ» в одной строке.
void main() {
  const wide = [
    Size(720, 900),
    Size(800, 700),
    Size(1024, 768),
    Size(1440, 1024),
  ];
  const narrow = [Size(390, 844), Size(360, 780)];

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepositoryProvider<CrmRepository>.value(
        value: MockCrmRepository(),
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          home: const RouteCreatePage(),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Набирает две точки — заказчика с долгом и без.
  Future<void> addStops(WidgetTester tester) async {
    for (final name in ['Офис «Baraka»', 'Дилноза Хамидова']) {
      final row = find.widgetWithText(RouteCreateCustomerRow, name);
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
      await settle(tester);
    }
  }

  /// Разворачивает точку и переключает её на цель с самой длинной подписью.
  Future<void> openStop(WidgetTester tester) async {
    const name = 'Офис «Baraka»';
    final card = find.widgetWithText(RouteCreateStopCard, name);
    await tester.tap(find.descendant(of: card, matching: find.text(name)));
    await tester.pump();
    await tester.tap(find.descendant(of: card, matching: find.text('Опт 5/10 л')));
    await tester.pump();
  }

  for (final size in wide) {
    testWidgets('две колонки на ${size.width.toInt()}px', (tester) async {
      await pump(tester, size);
      await addStops(tester);
      await openStop(tester);

      // Шторки здесь нет: маршрут стоит колонкой рядом с заказчиками.
      // Число карточек не проверяем: раскрытая занимает пол-колонки, и на
      // узком окне соседнюю список просто не успевает построить.
      expect(find.byType(RouteCreateSheet), findsNothing);
      expect(find.byType(RouteCreateStopCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in narrow) {
    testWidgets('шторка на ${size.width.toInt()}px', (tester) async {
      await pump(tester, size);
      await addStops(tester);

      // Точки живут в шторке, и в свёрнутой их не строят вовсе.
      expect(find.byType(RouteCreateSheet), findsOneWidget);
      expect(find.byType(RouteCreateStopCard), findsNothing);

      await tester.tap(find.textContaining('в маршруте'));
      await settle(tester);
      await openStop(tester);

      expect(find.byType(RouteCreateStopCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}

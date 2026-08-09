import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/app/theme/app_tokens.dart';
import 'package:crm_millwater/data/models/driver.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/core/widgets/action_feedback.dart';
import 'package:crm_millwater/features/drivers/presentation/drivers_page.dart';
import 'package:crm_millwater/features/routes/presentation/routes_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Считает обращения к спискам.
class _CountingRepository extends MockCrmRepository {
  int driverRequests = 0;
  int routeRequests = 0;

  @override
  Future<List<Driver>> getDrivers({String? search}) {
    driverRequests++;
    return super.getDrivers(search: search);
  }

  @override
  Future<List<RouteListItem>> getRoutes({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? driverId,
    RouteStatus? status,
  }) {
    routeRequests++;
    return super.getRoutes(
      dateFrom: dateFrom,
      dateTo: dateTo,
      driverId: driverId,
      status: status,
    );
  }
}

void main() {
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> pumpPage(
    WidgetTester tester,
    CrmRepository repo,
    Widget page,
  ) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      RepositoryProvider<CrmRepository>.value(
        value: repo,
        child: MaterialApp(
            // Строки интерфейса берутся из локали: тесты идут на русской.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,theme: AppTheme.light(), home: page),
      ),
    );
    await settle(tester);
  }

  group('Кнопка обновления', () {
    testWidgets('перезапрашивает список водителей', (tester) async {
      final repo = _CountingRepository();
      await pumpPage(tester, repo, const DriversPage());
      expect(repo.driverRequests, 1);

      await tester.tap(find.byTooltip('Обновить список'));
      await settle(tester);

      expect(repo.driverRequests, 2);
    });

    testWidgets('перезапрашивает маршруты', (tester) async {
      final repo = _CountingRepository();
      await pumpPage(tester, repo, const RoutesPage());
      expect(repo.routeRequests, 1);

      await tester.tap(find.byTooltip('Обновить маршруты'));
      await settle(tester);

      expect(repo.routeRequests, 2);
    });
  });

  group('Снек-бар', () {
    /// Показывает сообщение по нажатию — как это делают экраны после
    /// удаления или сохранения.
    Future<void> pumpSnackBar(
      WidgetTester tester, {
      required ThemeData theme,
      bool isError = false,
    }) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
            // Строки интерфейса берутся из локали: тесты идут на русской.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
          theme: theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showAppSnackBar(context, 'Готово', isError: isError),
                  child: const Text('показать'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('показать'));
      await settle(tester);
    }

    Color? textColor(WidgetTester tester) =>
        tester.widget<Text>(find.text('Готово')).style?.color;

    Color? background(WidgetTester tester) =>
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor;

    testWidgets('в тёмной теме подпись не сливается с фоном', (tester) async {
      await pumpSnackBar(tester, theme: AppTheme.dark());

      // Фон — цвет текста темы (почти белый), поэтому подпись тёмная.
      expect(background(tester), AppTokens.dark.text);
      expect(textColor(tester), AppTokens.dark.surface);
      expect(textColor(tester), isNot(background(tester)));
    });

    testWidgets('в светлой теме подпись остаётся светлой', (tester) async {
      await pumpSnackBar(tester, theme: AppTheme.light());

      expect(background(tester), AppTokens.light.text);
      expect(textColor(tester), AppTokens.light.surface);
    });

    testWidgets('ошибка остаётся белой на красном', (tester) async {
      await pumpSnackBar(tester, theme: AppTheme.dark(), isError: true);

      expect(background(tester), AppTokens.dark.danger);
      expect(textColor(tester), Colors.white);
    });
  });
}

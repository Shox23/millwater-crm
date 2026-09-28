import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/core/widgets/photo_attach_tile.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_expense.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/presentation/expense_form_page.dart';
import 'package:crm_millwater/features/driver/presentation/route_cash_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Касса маршрута и форма расхода.
///
/// Это деньги, которые водитель сдаёт в конце дня: остаток считает сервер, а
/// экран обязан показать его как есть — включая минус, когда водитель
/// заправился на свои.
class _CashRepository extends MockDriverRepository {
  _CashRepository({this.route, this.expenses = const []})
      : super(driverId: 'd1');

  final RouteDetail? route;
  final List<RouteExpense> expenses;

  final deleted = <String>[];
  ExpenseCategory? savedCategory;
  int? savedAmount;
  String? savedComment;
  String? savedKey;

  @override
  Future<RouteDetail?> getMyRoute(String id) async => route;

  @override
  Future<List<RouteExpense>> getRouteExpenses(String routeId) async => expenses;

  @override
  Future<void> deleteExpense(String expenseId) async => deleted.add(expenseId);

  @override
  Future<RouteExpense> addExpense({
    required String routeId,
    required int amount,
    required ExpenseCategory category,
    String? comment,
    String? photoPath,
    String? idempotencyKey,
  }) async {
    savedAmount = amount;
    savedCategory = category;
    savedComment = comment;
    savedKey = idempotencyKey;
    return RouteExpense(
      id: 'e-new',
      routeId: routeId,
      driverId: 'd1',
      amount: amount,
      category: category,
      createdAt: DateTime(2026, 9, 3, 9, 30),
    );
  }
}

RouteDetail _route({
  int? cash = 95000,
  int? cashless = 20000,
  int? debt = 15000,
  int? expenses = 35000,
  int? balance = 60000,
  RouteStatus status = RouteStatus.inProgress,
}) =>
    RouteDetail(
      id: 'r-1',
      date: DateTime(2026, 9, 3),
      status: status,
      completedCount: 1,
      totalCustomers: 2,
      stops: const [],
      cashCollected: cash,
      cashlessCollected: cashless,
      debtAmount: debt,
      expensesTotal: expenses,
      cashBalance: balance,
    );

RouteExpense _expense({
  String id = 'e-1',
  int amount = 35000,
  ExpenseCategory category = ExpenseCategory.fuel,
  String? comment = 'АЗС на Чиланзаре',
}) =>
    RouteExpense(
      id: id,
      routeId: 'r-1',
      driverId: 'd1',
      amount: amount,
      category: category,
      comment: comment,
      createdAt: DateTime(2026, 9, 3, 9, 30),
    );

void main() {
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Прокачивает кадры вместо `pumpAndSettle`: мигающий курсор в поле суммы
  /// не даёт экрану остановиться никогда.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpWidgetWith(
    WidgetTester tester,
    DriverRepository repo,
    Widget home,
  ) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      RepositoryProvider<DriverRepository>.value(
        value: repo,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  group('Касса маршрута', () {
    testWidgets('показывает серверные числа, а не свой подсчёт',
        (tester) async {
      final repo = _CashRepository(route: _route(), expenses: [_expense()]);
      await pumpWidgetWith(tester, repo, const RouteCashPage(routeId: 'r-1'));

      // Сервер видит правки оплаты и возвраты, которых в точках не видно.
      expect(find.textContaining('95 000'), findsOneWidget);
      expect(find.textContaining('20 000'), findsOneWidget);
      expect(find.textContaining('15 000'), findsOneWidget);
      expect(find.textContaining('60 000'), findsOneWidget);
    });

    testWidgets('отрицательный остаток показывается как есть', (tester) async {
      // Расход больше собранного разрешён: водитель заправился на свои, и
      // прятать минус нельзя — по нему считают, кто кому должен.
      final repo = _CashRepository(
        route: _route(cash: 10000, expenses: 35000, balance: -25000),
      );
      await pumpWidgetWith(tester, repo, const RouteCashPage(routeId: 'r-1'));

      expect(find.textContaining('-25 000'), findsOneWidget);
    });

    testWidgets('расход показан с категорией и комментарием', (tester) async {
      final repo = _CashRepository(route: _route(), expenses: [_expense()]);
      await pumpWidgetWith(tester, repo, const RouteCashPage(routeId: 'r-1'));

      expect(find.text('Топливо'), findsOneWidget);
      expect(find.text('АЗС на Чиланзаре'), findsOneWidget);
    });

    testWidgets('у закрытого маршрута расход не добавить', (tester) async {
      // Сервер принимает расход только у маршрута в работе (409
      // `ROUTE_NOT_IN_PROGRESS`); глухая кнопка честнее отказа после формы.
      final repo = _CashRepository(route: _route(status: RouteStatus.completed));
      await pumpWidgetWith(tester, repo, const RouteCashPage(routeId: 'r-1'));

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Добавить расход'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('пустой список объясняет себя, а не молчит', (tester) async {
      final repo = _CashRepository(route: _route());
      await pumpWidgetWith(tester, repo, const RouteCashPage(routeId: 'r-1'));

      expect(find.text('Расходов пока нет'), findsOneWidget);
    });

    testWidgets('удаление расхода спрашивает подтверждение', (tester) async {
      final repo = _CashRepository(route: _route(), expenses: [_expense()]);
      await pumpWidgetWith(tester, repo, const RouteCashPage(routeId: 'r-1'));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await settle(tester);

      // Расход вычитается из кассы — случайное удаление меняет то, что
      // водитель сдаёт.
      expect(find.textContaining('вычтется из кассы'), findsOneWidget);
      expect(repo.deleted, isEmpty);
    });

    testWidgets('маршрут не загрузился — предлагает повтор', (tester) async {
      final repo = _CashRepository();
      await pumpWidgetWith(tester, repo, const RouteCashPage(routeId: 'r-1'));

      expect(find.textContaining('Не удалось загрузить'), findsOneWidget);
    });
  });

  group('Форма расхода', () {
    testWidgets('нулевую сумму сохранить нельзя', (tester) async {
      final repo = _CashRepository();
      await pumpWidgetWith(tester, repo, const ExpenseFormPage(routeId: 'r-1'));

      expect(
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Сохранить'))
            .enabled,
        isFalse,
      );

      await tester.enterText(find.byType(TextField).first, '0');
      await settle(tester);

      // Ноль расходом не бывает — сервер требует сумму больше нуля.
      expect(
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Сохранить'))
            .enabled,
        isFalse,
      );
    });

    testWidgets('сумма, категория и комментарий уходят в репозиторий',
        (tester) async {
      final repo = _CashRepository();
      await pumpWidgetWith(tester, repo, const ExpenseFormPage(routeId: 'r-1'));

      await tester.enterText(find.byType(TextField).first, '35000');
      await settle(tester);
      await tester.tap(find.text('Обед'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Плов');
      await settle(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await settle(tester);

      expect(repo.savedAmount, 35000);
      expect(repo.savedCategory, ExpenseCategory.lunch);
      expect(repo.savedComment, 'Плов');
    });

    testWidgets('ключ идемпотентности уходит вместе с расходом',
        (tester) async {
      final repo = _CashRepository();
      await pumpWidgetWith(tester, repo, const ExpenseFormPage(routeId: 'r-1'));

      await tester.enterText(find.byType(TextField).first, '12000');
      await settle(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
      await settle(tester);

      // Без ключа повтор после обрыва списал бы деньги второй раз.
      expect(repo.savedKey, isNotNull);
      expect(repo.savedKey, startsWith('expense'));
    });

    testWidgets('чек можно приложить к любому расходу', (tester) async {
      final repo = _CashRepository();
      await pumpWidgetWith(tester, repo, const ExpenseFormPage(routeId: 'r-1'));

      // В отчёте спрашивают за наличные, потраченные в дороге, — снимок
      // нужен не только у части категорий.
      expect(find.byType(PhotoAttachTile), findsOneWidget);
    });
  });
}

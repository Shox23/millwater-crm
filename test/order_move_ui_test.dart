import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/utils/day.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/orders/presentation/move_order_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Экран переноса заказа.
///
/// Ниже экрана перенос уже проверен на репозитории (order_move_test.dart);
/// здесь — то, что решает сам экран и чего репозиторий не видит: какой из
/// двух взаимоисключающих вариантов уходит на сервер (маршрут ИЛИ дата),
/// предупреждён ли человек про маршрут без водителя ДО отправки и не
/// предлагается ли маршрут, в котором заказ уже лежит.
///
/// Маршруты отдаёт подставной репозиторий, а не мок-стор: набор маршрутов
/// дня здесь — условие проверки, и зависеть от демо-данных ему нельзя.
class _MoveRepository extends MockCrmRepository {
  _MoveRepository({this.routes = const [], this.failure});

  /// Что сервер отдаёт на любой запрошенный день.
  final List<RouteListItem> routes;

  /// Чем ответить на перенос; `null` — принять.
  final Object? failure;

  /// Даты, за которые экран спрашивал маршруты, по порядку.
  final requestedDates = <DateTime>[];
  final movedToRoute = <String>[];
  final movedToDate = <DateTime>[];

  @override
  Future<List<RouteListItem>> getRoutes({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? driverId,
    RouteStatus? status,
  }) async {
    if (dateFrom != null) requestedDates.add(dateFrom);
    return routes;
  }

  @override
  Future<void> moveOrderToRoute({
    required String orderId,
    required String targetRouteId,
  }) async {
    if (failure != null) throw failure!;
    movedToRoute.add(targetRouteId);
  }

  @override
  Future<void> moveOrderToDate({
    required String orderId,
    required DateTime date,
    String? driverId,
  }) async {
    if (failure != null) throw failure!;
    movedToDate.add(date);
  }
}

void main() {
  /// Отказ сервера конвертом бизнес-ошибки — так приходит и DATE_IN_PAST.
  DioException failure(String code, {int status = 422}) {
    final options = RequestOptions(path: '/admin/orders/o-1/move');
    return DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: status,
        data: {
          'success': false,
          'error': {'code': code, 'message': 'rejected'},
        },
      ),
    );
  }

  RouteListItem route(String id, String driver) => RouteListItem(
        id: id,
        date: dayOnly(DateTime.now()),
        status: RouteStatus.created,
        completedCount: 0,
        totalCustomers: 3,
        driverId: 'd-$id',
        driverFullName: driver,
      );

  Order order({String? routeId}) => Order(
        id: 'o-1',
        number: 41,
        status: DeliveryStatus.pending,
        purpose: OrderPurpose.delivery19l,
        createdAt: DateTime(2026, 9, 1),
        customerId: 'c-1',
        customerName: 'Кафе «Nasiba»',
        routeId: routeId,
      );

  void useLargeSurface(WidgetTester tester) {
    // В тестах вместо Inter подставляется шрифт тестового рендерера с более
    // широкими глифами — на узком экране подписи в него не влезают.
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Прокачивает кадры вместо `pumpAndSettle`: календарь держит анимацию, а
  /// мок отвечает через паузу — «до полной остановки» экран не доходит.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpMove(
    WidgetTester tester, {
    required _MoveRepository repo,
    required Order target,
  }) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      RepositoryProvider<CrmRepository>.value(
        value: repo,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: MoveOrderPage(order: target),
        ),
      ),
    );
    // Первая загрузка маршрутов идёт из initState — без этого на экране
    // осталась бы крутилка.
    await settle(tester);
  }

  Future<void> openCalendar(WidgetTester tester) async {
    await tester.tap(find.text('Дата'));
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await settle(tester);
    await tester.tap(target);
    await settle(tester);
  }

  /// Выбирает 15-е число следующего месяца и возвращает эту дату.
  ///
  /// Именно так, а не «завтра»: завтра в последний день месяца уезжает за
  /// границу листа календаря, и тест ломался бы раз в месяц.
  Future<DateTime> pickNextMonth(WidgetTester tester) async {
    await openCalendar(tester);
    final dialog = find.byType(DatePickerDialog);

    await tester.tap(
      find.descendant(of: dialog, matching: find.byIcon(Icons.chevron_right)),
    );
    await settle(tester);
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('15')),
    );
    await settle(tester);
    // Из двух кнопок диалога подтверждение — вторая.
    await tester.tap(
      find.descendant(of: dialog, matching: find.byType(TextButton)).last,
    );
    await settle(tester);

    final today = dayOnly(DateTime.now());
    return DateTime(today.year, today.month + 1, 15);
  }

  Future<void> tapMove(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(AppButton, 'Перенести'));
    await settle(tester);
  }

  const noDriverWarning =
      'У нового маршрута не будет водителя — назначьте его на экране маршрутов';

  testWidgets('выбор другой даты перезапрашивает маршруты', (tester) async {
    final repo = _MoveRepository(routes: [route('r-2', 'Бекзод Юсупов')]);
    await pumpMove(tester, repo: repo, target: order());
    expect(repo.requestedDates, hasLength(1));

    final picked = await pickNextMonth(tester);

    // Набор маршрутов целиком определяется датой: без перезапроса человек
    // выбирал бы маршрут другого дня.
    expect(repo.requestedDates, hasLength(2));
    expect(repo.requestedDates.last, picked);
  });

  testWidgets('календарь не пускает в прошлое', (tester) async {
    final repo = _MoveRepository();
    await pumpMove(tester, repo: repo, target: order());

    await openCalendar(tester);

    // Дату в прошлом сервер отвергает (422 DATE_IN_PAST) — до отказа дело
    // доходить не должно.
    final dialog =
        tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(dialog.firstDate, dayOnly(DateTime.now()));
  });

  testWidgets('маршрут, в котором заказ уже лежит, не предлагается',
      (tester) async {
    final repo = _MoveRepository(
      routes: [route('r-1', 'Алишер Каримов'), route('r-2', 'Бекзод Юсупов')],
    );

    await pumpMove(tester, repo: repo, target: order(routeId: 'r-1'));

    // Перенос в тот же маршрут — не перенос, а лишний запрос.
    expect(find.textContaining('Алишер'), findsNothing);
    expect(find.textContaining('Бекзод'), findsOneWidget);
  });

  testWidgets('«Новый маршрут» предупреждает про водителя до отправки',
      (tester) async {
    final repo = _MoveRepository(routes: [route('r-2', 'Бекзод Юсупов')]);
    await pumpMove(tester, repo: repo, target: order());

    // «Новый маршрут» выбран по умолчанию — предупреждение видно сразу.
    expect(find.text(noDriverWarning), findsOneWidget);

    await tapText(tester, find.textContaining('Бекзод'));
    expect(find.text(noDriverWarning), findsNothing);

    await tapText(tester, find.text('Новый маршрут'));
    expect(find.text(noDriverWarning), findsOneWidget);

    // Предупреждение — до отправки, а не после: узнать про маршрут без
    // водителя из карточки заказчика уже поздно.
    expect(repo.movedToRoute, isEmpty);
    expect(repo.movedToDate, isEmpty);
  });

  testWidgets('выбранный маршрут уходит маршрутом, а не датой', (tester) async {
    final repo = _MoveRepository(routes: [route('r-2', 'Бекзод Юсупов')]);
    await pumpMove(tester, repo: repo, target: order());

    await tapText(tester, find.textContaining('Бекзод'));
    await tapMove(tester);

    // Сервер принимает ровно один из двух вариантов — экран обязан выбрать.
    expect(repo.movedToRoute, ['r-2']);
    expect(repo.movedToDate, isEmpty);
  });

  testWidgets('«Новый маршрут» уходит датой, а не маршрутом', (tester) async {
    final repo = _MoveRepository(routes: [route('r-2', 'Бекзод Юсупов')]);
    await pumpMove(tester, repo: repo, target: order());

    final picked = await pickNextMonth(tester);
    await tapMove(tester);

    expect(repo.movedToDate, [picked]);
    expect(repo.movedToRoute, isEmpty);
  });

  testWidgets('отказ сервера показывается текстом, экран не закрывается',
      (tester) async {
    final repo = _MoveRepository(failure: failure('DATE_IN_PAST'));
    await pumpMove(tester, repo: repo, target: order());

    await tapMove(tester);

    expect(find.text('Дата не может быть в прошлом'), findsOneWidget);
    // Серая кнопка без объяснения — тупик; экран остаётся с ошибкой.
    expect(find.text('Перенести заказ'), findsOneWidget);
  });
}

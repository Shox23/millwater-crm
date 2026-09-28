import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/mock/seed_data.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/routes/presentation/route_create_page.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_customer_row.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_stop_card.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_totals.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Запоминает, с чем ушёл созданный маршрут.
class _CreatingRepository extends MockCrmRepository {
  List<RouteOrderInput> sent = const [];
  DateTime? sentDate;
  String? sentDriverId;

  @override
  Future<RouteDetail> createRoute({
    required DateTime date,
    required List<RouteOrderInput> orders,
    String? driverId,
    OrderPurpose purpose = OrderPurpose.delivery19l,
    String? idempotencyKey,
  }) {
    sent = List.of(orders);
    sentDate = date;
    sentDriverId = driverId;
    return super.createRoute(
      date: date,
      orders: orders,
      driverId: driverId,
      purpose: purpose,
      idempotencyKey: idempotencyKey,
    );
  }
}

void main() {
  // Заказчики демо-режима, на которых опираются тесты:
  //  «Кафе «Nasiba»» (c1) — есть завершённая доставка на 5 капсул, то есть
  //      обычный объём подсмотреть можно;
  //  «Офис «Baraka»» (c2) — долг 120 000 и **нет** завершённых доставок,
  //      поэтому количество остаётся единицей;
  //  «Дилноза Хамидова» (c3) — ни долга, ни истории;
  //  «Салон «Zebo»» (c4) — 40 дней без заказа, то есть «ПОРА».
  const nasiba = 'Кафе «Nasiba»';
  const baraka = 'Офис «Baraka»';
  const dilnoza = 'Дилноза Хамидова';

  Widget app(CrmRepository repo) => RepositoryProvider<CrmRepository>.value(
        value: repo,
        child: MaterialApp(
          // Без темы приложения нет ThemeExtension с токенами, и первый же
          // context.tokens валит сборку экрана.
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          home: const RouteCreatePage(),
        ),
      );

  /// Страница грузит водителей, заказчиков и прайс последовательно: каждый
  /// следующий таймер ставится после срабатывания предыдущего, поэтому время
  /// двигаем шагами, а не одним прыжком.
  Future<void> settle(WidgetTester tester, {int steps = 8}) async {
    await tester.pump();
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> pumpWide(WidgetTester tester, CrmRepository repo) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(repo));
    await settle(tester);
  }

  /// Ровно тот экран, о котором договаривались: 390×844.
  Future<void> pumpPhone(WidgetTester tester, CrmRepository repo) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(repo));
    await settle(tester);
  }

  Finder rowOf(String name) => find.widgetWithText(RouteCreateCustomerRow, name);
  Finder cardOf(String name) => find.widgetWithText(RouteCreateStopCard, name);

  Future<void> pick(WidgetTester tester, String name) async {
    await tester.ensureVisible(rowOf(name));
    await tester.pump();
    await tester.tap(rowOf(name));
    // Объём заказчика подсматривается запросом — даём ему дойти.
    await settle(tester, steps: 3);
  }

  Future<void> expand(WidgetTester tester, String name) async {
    await tester.tap(find.descendant(of: cardOf(name), matching: find.text(name)));
    await tester.pump();
  }

  /// Разворачивает шторку маршрута. Высота едет неявной анимацией, а та
  /// требует нескольких кадров: одного pump на 300 мс не хватает — список
  /// точек успевает построиться в ещё невысокой шторке.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.textContaining('в маршруте'));
    await settle(tester, steps: 3);
  }

  Future<void> create(WidgetTester tester, String label) async {
    final button = find.widgetWithText(AppButton, label);
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('Выбор заказчика', () {
    testWidgets('не раскрывает форму в списке и не двигает список',
        (tester) async {
      await pumpWide(tester, _CreatingRepository());

      final rows = find.byType(RouteCreateCustomerRow);
      final before = tester.getTopLeft(rows.last);
      final count = rows.evaluate().length;

      await pick(tester, dilnoza);

      // Список не перестроился, последняя строка на том же месте.
      expect(rows.evaluate().length, count);
      expect(tester.getTopLeft(rows.last), before);
      // И ни одной формы точки внутри списка: она живёт в зоне маршрута.
      expect(
        find.descendant(
          of: find.byType(RouteCreateCustomerRow),
          matching: find.byType(RouteCreateStopCard),
        ),
        findsNothing,
      );
      expect(find.byType(RouteCreateStopCard), findsOneWidget);
    });

    testWidgets('строка показывает долг, адрес и давность доставки',
        (tester) async {
      await pumpWide(tester, _CreatingRepository());

      // Раньше в строке были только название и адрес, который название же и
      // повторял, — выбирать приходилось вслепую.
      expect(
        find.descendant(of: rowOf(baraka), matching: find.text('ДОЛГ 120 000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rowOf(baraka), matching: find.text('Юнусабад, кв-л 4')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: rowOf(baraka),
          matching: find.text('последняя 1 дн. назад'),
        ),
        findsOneWidget,
      );
      // «ПОРА» — у того, кто не получал воду неделю и больше.
      expect(find.text('ПОРА'), findsWidgets);
    });

    testWidgets('повторный тап убирает точку', (tester) async {
      await pumpWide(tester, _CreatingRepository());

      await pick(tester, dilnoza);
      expect(find.byType(RouteCreateStopCard), findsOneWidget);

      await tester.tap(rowOf(dilnoza));
      await tester.pump();

      expect(find.byType(RouteCreateStopCard), findsNothing);
    });

    testWidgets('поиск находит по фрагменту адреса', (tester) async {
      await pumpWide(tester, _CreatingRepository());

      await tester.enterText(find.byType(TextField).first, 'юнусабад');
      await tester.pump();

      // «Юнусабад» есть только в адресе — по названию этот заказчик не
      // нашёлся бы.
      expect(rowOf(baraka), findsOneWidget);
      expect(rowOf(nasiba), findsNothing);
    });
  });

  group('Новая точка', () {
    testWidgets('приходит заполненной и без красных ошибок', (tester) async {
      await pumpWide(tester, _CreatingRepository());

      // У этого заказчика истории нет — количество остаётся единицей, и это
      // законное состояние: ошибок до действий пользователя быть не должно.
      await pick(tester, dilnoza);

      final card = cardOf(dilnoza);
      expect(
        find.descendant(of: card, matching: find.text('Доставка 19 л')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('1 капсула')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('${SeedData.capsulePrice ~/ 1000} 000 сум'),
        ),
        findsOneWidget,
      );
      // Ни одной ошибки до первого действия пользователя.
      expect(find.text('Сумма должна быть больше нуля'), findsNothing);
      expect(find.text('Укажите, сколько капсул везти'), findsNothing);
      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Создать маршрут · 1'),
      );
      expect(button.enabled, isTrue);
    });

    testWidgets('обычный объём подставляется, когда история его знает',
        (tester) async {
      await pumpWide(tester, _CreatingRepository());

      await pick(tester, nasiba);

      // У этого заказчика завершённая доставка на 5 капсул — столько и везём.
      expect(
        find.descendant(of: cardOf(nasiba), matching: find.text('5 капсул')),
        findsOneWidget,
      );
      // И в строке списка появилась подсказка, откуда взялось число.
      expect(
        find.descendant(of: rowOf(nasiba), matching: find.textContaining('обычно 5')),
        findsOneWidget,
      );
    });

    testWidgets('количество вводится цифрой, а не двадцатью нажатиями',
        (tester) async {
      final repo = _CreatingRepository();
      await pumpWide(tester, repo);

      await pick(tester, baraka);
      await expand(tester, baraka);

      // Поле счётчика — единственное числовое в развёрнутой карточке.
      final qtyField = find
          .descendant(of: cardOf(baraka), matching: find.byType(TextField))
          .first;
      await tester.enterText(qtyField, '20');
      await tester.pump();

      expect(
        find.descendant(of: cardOf(baraka), matching: find.text('20 капсул')),
        findsOneWidget,
      );

      await create(tester, 'Создать маршрут · 1');
      expect(repo.sent.single.bottleSellCount, 20);
    });

    testWidgets('вывоз денег не приносит, пока не задана своя цена',
        (tester) async {
      final repo = _CreatingRepository();
      await pumpWide(tester, repo);

      await pick(tester, baraka);
      await expand(tester, baraka);
      await tester.tap(find.descendant(
        of: cardOf(baraka),
        matching: find.text('Вывоз'),
      ));
      await tester.pump();

      expect(
        find.descendant(of: cardOf(baraka), matching: find.text('без оплаты')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(RouteCreateTotals), matching: find.text('0 сум')),
        findsOneWidget,
      );

      // Договорная сумма у вывоза — единственный источник денег. Поле
      // ищем по подсказке: в карточке их теперь три (цена и комментарий,
      // а у доставки ещё количество), и «последнее» ничего не значит.
      final priceField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Без оплаты',
      );
      await tester.enterText(priceField, '50000');
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(RouteCreateTotals),
          matching: find.text('50 000 сум'),
        ),
        findsOneWidget,
      );

      await create(tester, 'Создать маршрут · 1');
      expect(repo.sent.single.purpose, OrderPurpose.pickup);
      expect(repo.sent.single.customPrice, 50000);
      // Задание в капсулах вывозу не отправляем — везти нечего.
      expect(repo.sent.single.bottleSellCount, isNull);
    });
  });

  group('Итоги и отправка', () {
    testWidgets('итоги видны всегда и совпадают с созданным маршрутом',
        (tester) async {
      final repo = _CreatingRepository();
      await pumpWide(tester, repo);

      // Итоги стоят перед кнопкой ещё до первой точки.
      expect(find.byType(RouteCreateTotals), findsOneWidget);
      expect(find.text('Точек'), findsOneWidget);
      expect(find.text('Капсул 19 л'), findsOneWidget);

      await pick(tester, baraka);
      await pick(tester, dilnoza);
      await expand(tester, baraka);
      await tester.tap(find.descendant(
        of: cardOf(baraka),
        matching: find.text('10'),
      ));
      await tester.pump();

      final totals = find.byType(RouteCreateTotals);
      expect(find.descendant(of: totals, matching: find.text('2')), findsOneWidget);
      expect(find.descendant(of: totals, matching: find.text('11')), findsOneWidget);
      expect(
        find.descendant(
          of: totals,
          matching: find.text('220 000 сум'),
        ),
        findsOneWidget,
      );

      await create(tester, 'Создать маршрут · 2');

      final capsules = repo.sent
          .map((o) => o.bottleSellCount ?? 0)
          .fold(0, (a, b) => a + b);
      expect(repo.sent.length, 2);
      expect(capsules, 11);
    });

    testWidgets('без точек создать нельзя', (tester) async {
      await pumpWide(tester, _CreatingRepository());

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Добавьте точку'),
      );
      expect(button.enabled, isFalse);
    });

    testWidgets('водитель выбирается шторкой и уходит вместе с маршрутом',
        (tester) async {
      final repo = _CreatingRepository();
      await pumpPhone(tester, repo);

      final driver = repo.store.drivers.first;

      // Чип водителя вместо секции с радиокнопками на всех сразу.
      await tester.tap(find.text('Назначить позже'));
      await settle(tester, steps: 3);
      await tester.tap(find.text(driver.fullName).last);
      await settle(tester, steps: 3);

      expect(find.text(driver.fullName), findsOneWidget);

      await pick(tester, dilnoza);
      await openSheet(tester);
      await create(tester, 'Создать маршрут · 1');

      expect(repo.sentDriverId, driver.id);
    });

    testWidgets('маршрут уходит на завтра и без водителя', (tester) async {
      final repo = _CreatingRepository();
      await pumpWide(tester, repo);

      await pick(tester, dilnoza);
      await create(tester, 'Создать маршрут · 1');

      // Маршруты планируют накануне, а исполнителя ставят, когда ясно, кто
      // свободен: «Назначить позже» — законное состояние.
      final now = DateTime.now();
      expect(repo.sentDate, DateTime(now.year, now.month, now.day + 1));
      expect(repo.sentDriverId, isNull);
    });
  });

  group('Порядок объезда', () {
    /// Номер, под которым точка стоит в маршруте.
    Finder numberOf(String name) =>
        find.descendant(of: cardOf(name), matching: find.text('1'));

    testWidgets('стрелки меняют порядок, и он уходит на сервер',
        (tester) async {
      final repo = _CreatingRepository();
      await pumpWide(tester, repo);

      await pick(tester, baraka);
      await pick(tester, dilnoza);
      expect(numberOf(baraka), findsOneWidget);

      // Стрелки — фолбэк к перетаскиванию и единственный путь с клавиатуры.
      await tester.tap(find.byTooltip('Ниже').first);
      await tester.pump();

      expect(numberOf(dilnoza), findsOneWidget);
      expect(numberOf(baraka), findsNothing);

      await create(tester, 'Создать маршрут · 2');

      expect(repo.sent.map((o) => o.sequence), [1, 2]);
      final names = repo.sent
          .map((o) => repo.store.customers
              .firstWhere((c) => c.id == o.customerId)
              .name)
          .toList();
      expect(names, [dilnoza, baraka]);
    });

    testWidgets('точка перетаскивается мышью за грип', (tester) async {
      final repo = _CreatingRepository();
      await pumpWide(tester, repo);

      await pick(tester, baraka);
      await pick(tester, dilnoza);

      final cards = find.byType(RouteCreateStopCard);
      final pitch =
          tester.getRect(cards.at(1)).top - tester.getRect(cards.at(0)).top;

      // Мышью — и только за грип: иначе на десктопе ломается выделение
      // текста и работа с полями ввода.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(RouteCreateGrip).first),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(0, pitch / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settle(tester, steps: 6);

      expect(numberOf(dilnoza), findsOneWidget);

      await create(tester, 'Создать маршрут · 2');
      expect(repo.sent.map((o) => o.customerId).first,
          repo.store.customers.firstWhere((c) => c.name == dilnoza).id);
    });

    testWidgets('точка перетаскивается за грип пальцем', (tester) async {
      final repo = _CreatingRepository();
      await pumpPhone(tester, repo);

      await pick(tester, baraka);
      await pick(tester, dilnoza);

      // Шторку разворачиваем — в свёрнутой точек нет вовсе.
      await openSheet(tester);

      final cards = find.byType(RouteCreateStopCard);
      final pitch = tester.getRect(cards.at(1)).top -
          tester.getRect(cards.at(0)).top;

      // Палец тянет за грип: шагами, а не прыжком, — распознаватель
      // перетаскивания ждёт движения, а не одного большого смещения.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(RouteCreateGrip).first),
      );
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(0, pitch / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      // Порядок в состоянии меняется по окончании анимации падения точки —
      // до неё список успел показать новый порядок, а данные ещё старые.
      await settle(tester, steps: 6);

      expect(numberOf(dilnoza), findsOneWidget);

      await create(tester, 'Создать маршрут · 2');
      final names = repo.sent
          .map((o) => repo.store.customers
              .firstWhere((c) => c.id == o.customerId)
              .name)
          .toList();
      expect(names, [dilnoza, baraka]);
    });
  });

  group('Телефон, 390×844', () {
    testWidgets('последний заказчик доступен для тапа, кнопка на экране',
        (tester) async {
      await pumpPhone(tester, _CreatingRepository());

      // Прокручиваем список до конца — под шторкой не должно остаться
      // ничего, до чего нельзя дотянуться.
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      final last = find.byType(RouteCreateCustomerRow).last;
      final name = tester
          .widget<RouteCreateCustomerRow>(last)
          .customer
          .name;
      await tester.tap(last);
      await tester.pump(const Duration(milliseconds: 300));

      // Тап дошёл до строки, а не до шторки.
      expect(find.text('1 точка в маршруте'), findsOneWidget);
      expect(find.textContaining(name), findsWidgets);

      final button = find.widgetWithText(AppButton, 'Создать · 1');
      expect(button, findsOneWidget);
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(844));
    });

    testWidgets('касания в карточке точки не меньше 44px', (tester) async {
      await pumpPhone(tester, _CreatingRepository());

      await pick(tester, baraka);
      await openSheet(tester);
      await expand(tester, baraka);

      // Счётчик, пресеты, цели и удаление — всё пальцем.
      final minus = find
          .ancestor(of: find.byIcon(Icons.remove), matching: find.byType(SizedBox))
          .first;
      expect(tester.getSize(minus).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(minus).width, greaterThanOrEqualTo(44));

      expect(
        tester.getSize(find.widgetWithText(Container, 'Вывоз').first).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSize(find.widgetWithText(Container, '10').first).height,
        greaterThanOrEqualTo(44),
      );
      final remove =
          tester.getSize(find.widgetWithIcon(IconButton, Icons.close_rounded));
      expect(remove.height, greaterThanOrEqualTo(44));
      expect(remove.width, greaterThanOrEqualTo(44));
    });

    testWidgets('после добавления шторка не разворачивается, а показывает тост',
        (tester) async {
      await pumpPhone(tester, _CreatingRepository());

      await pick(tester, baraka);

      // Путь «нашёл → тапнул → создать» не должен упираться в разворот
      // шторки, поэтому вместо неё — тост. Количество в нём то же, что в
      // точке: подсказка из истории приходит с задержкой и поправляет и его.
      expect(find.text('$baraka · 3 капсулы'), findsOneWidget);
      expect(find.byType(RouteCreateStopCard), findsNothing);

      // И тост гаснет сам.
      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining(baraka), findsWidgets);
      expect(find.text('$baraka · 3 капсулы'), findsNothing);
    });
  });
}

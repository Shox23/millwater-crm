import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/routes/presentation/route_create_page.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_customer_row.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_create_stop_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Перетаскивание точек: что тащится, что едет за курсором и что уходит на
/// сервер.
///
/// Два правила здесь пришли из живых поломок, и обе тесты сперва пропустили,
/// потому что таскали только свёрнутые карточки:
///
/// 1. под курсор уезжает **копия** карточки; копия раскрытой тащила с собой
///    вторые экземпляры полей ввода, и сборка отвечала «A _RenderLayoutBuilder
///    was mutated in _RenderLayoutBuilder.performLayout» — на месте списка
///    точек оставался красный экран ошибки. Лечится `proxyDecorator`: в
///    оверлей уходит свёрнутый вид карточки;
/// 2. раскрытая карточка бывает выше видимой части списка (в шторке телефона
///    это обычное дело), а такой элемент Flutter перетаскивать не умеет —
///    автопрокрутка упирается в «drag target is larger than scrollable size».
///    Поэтому у раскрытой точки грип не работает: сперва сверни.
void main() {
  const first = 'Офис «Baraka»';
  const second = 'Дилноза Хамидова';

  Future<void> settle(WidgetTester tester, {int steps = 4}) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Size size,
    double ratio, {
    CrmRepository? repo,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepositoryProvider<CrmRepository>.value(
        value: repo ?? MockCrmRepository(),
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          home: const RouteCreatePage(),
        ),
      ),
    );
    await tester.pump();
    await settle(tester, steps: 8);
  }

  Future<void> addStops(WidgetTester tester) async {
    for (final name in [first, second]) {
      final row = find.widgetWithText(RouteCreateCustomerRow, name);
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
      await settle(tester, steps: 3);
    }
  }

  Finder cardOf(String name) => find.widgetWithText(RouteCreateStopCard, name);

  /// Тап по названию: разворачивает и сворачивает редактирование.
  Future<void> toggle(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(of: cardOf(name), matching: find.text(name)),
    );
    await tester.pump();
  }

  /// Тянет первую точку вниз на высоту соседней.
  Future<void> dragFirstDown(
    WidgetTester tester, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    final cards = find.byType(RouteCreateStopCard);
    final start = tester.getRect(cards.at(0));
    // Соседняя карточка построена не всегда: раскрытая занимает почти всю
    // шторку. Тогда шагом берём её собственную высоту с промежутком.
    final pitch = cards.evaluate().length > 1
        ? tester.getRect(cards.at(1)).top - start.top
        : start.height + 8;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(RouteCreateGrip).first),
      kind: kind,
    );
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, pitch / 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    // Порядок в состоянии меняется по окончании анимации падения точки.
    await settle(tester, steps: 6);
  }

  /// Номер, под которым точка стоит в маршруте.
  Finder numberOf(String name) =>
      find.descendant(of: cardOf(name), matching: find.text('1'));

  group('Десктоп', () {
    testWidgets('свёрнутая точка перетаскивается мышью', (tester) async {
      await pump(tester, const Size(1440, 1024), 1);
      await addStops(tester);

      await dragFirstDown(tester, kind: PointerDeviceKind.mouse);

      expect(tester.takeException(), isNull);
      expect(numberOf(second), findsOneWidget);
    });

    testWidgets('раскрытую точку не тащат: сперва свернуть', (tester) async {
      await pump(tester, const Size(1440, 1024), 1);
      await addStops(tester);
      await toggle(tester, first);
      // Поиск заказчиков плюс количество, цена и комментарий точки.
      expect(find.byType(TextField), findsNWidgets(4));

      await dragFirstDown(tester, kind: PointerDeviceKind.mouse);

      // Ни ошибки, ни перестановки: грип у раскрытой точки не работает.
      expect(tester.takeException(), isNull);
      expect(numberOf(first), findsOneWidget);

      // Свернули — и порядок снова меняется.
      await toggle(tester, first);
      await dragFirstDown(tester, kind: PointerDeviceKind.mouse);

      expect(tester.takeException(), isNull);
      expect(numberOf(second), findsOneWidget);
    });

    testWidgets('в оверлей уходит карточка без полей и кнопок', (tester) async {
      await pump(tester, const Size(1440, 1024), 1);
      await addStops(tester);

      final cards = find.byType(RouteCreateStopCard);
      final pitch =
          tester.getRect(cards.at(1)).top - tester.getRect(cards.at(0)).top;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(RouteCreateGrip).first),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(Offset(0, pitch / 2));
      await tester.pump(const Duration(milliseconds: 50));

      // На месте точки в списке — пустое место (так устроен сам список),
      // видно только копию в оверлее. В копии нет ни полей ввода, ни второй
      // кнопки удаления: остались поле поиска и кнопка соседней точки.
      expect(cardOf(first), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await gesture.up();
      await settle(tester, steps: 6);
      expect(tester.takeException(), isNull);
    });
  });

  group('Телефон', () {
    testWidgets('свёрнутая точка перетаскивается пальцем', (tester) async {
      await pump(tester, const Size(1170, 2532), 3);
      await addStops(tester);

      await tester.tap(find.textContaining('в маршруте'));
      await settle(tester, steps: 3);
      await dragFirstDown(tester);

      expect(tester.takeException(), isNull);
      expect(numberOf(second), findsOneWidget);
    });

    testWidgets('раскрытая точка в шторке не тащится и не роняет экран',
        (tester) async {
      await pump(tester, const Size(1170, 2532), 3);
      await addStops(tester);

      await tester.tap(find.textContaining('в маршруте'));
      await settle(tester, steps: 3);
      await toggle(tester, first);
      expect(find.byType(TextField), findsWidgets);

      await dragFirstDown(tester);

      expect(tester.takeException(), isNull);
      expect(numberOf(first), findsOneWidget);
    });
  });

  testWidgets('порядок после перетаскивания уходит на сервер', (tester) async {
    final repo = _CreatingRepository();
    await pump(tester, const Size(1440, 1024), 1, repo: repo);
    await addStops(tester);
    await dragFirstDown(tester, kind: PointerDeviceKind.mouse);

    final button = find.widgetWithText(AppButton, 'Создать маршрут · 2');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final names = repo.sent
        .map((o) =>
            repo.store.customers.firstWhere((c) => c.id == o.customerId).name)
        .toList();
    expect(names, [second, first]);
    expect(repo.sent.map((o) => o.sequence), [1, 2]);
  });
}

/// Запоминает, с чем ушёл созданный маршрут.
class _CreatingRepository extends MockCrmRepository {
  List<RouteOrderInput> sent = const [];

  @override
  Future<RouteDetail> createRoute({
    required DateTime date,
    required List<RouteOrderInput> orders,
    String? driverId,
    OrderPurpose purpose = OrderPurpose.delivery19l,
    String? idempotencyKey,
  }) {
    sent = List.of(orders);
    return super.createRoute(
      date: date,
      orders: orders,
      driverId: driverId,
      purpose: purpose,
      idempotencyKey: idempotencyKey,
    );
  }
}

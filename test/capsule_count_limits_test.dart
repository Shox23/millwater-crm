import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/presentation/customer_form_page.dart';
import 'package:crm_millwater/features/desktop/overlays/entity_form_modal.dart';
import 'package:crm_millwater/features/routes/domain/route_draft.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/route_stop_editor.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Сколько капсул можно задать при создании заказа и заказчика.
///
/// Жалоба 2026-11-05: «нельзя ввести больше 99 капсул». В самом заказе
/// потолка 99 нет — поле количества берёт три цифры. В 99 упиралось поле
/// «Капсул у заказчика» — тара на руках — в форме заказчика на телефоне и на
/// десктопе: у офисов и дилеров её бывает больше сотни.
void main() {
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home, {CrmRepository? repo}) {
    final child = MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocales.supported,
      locale: AppLocales.ru,
      home: home,
    );
    return repo == null
        ? child
        : RepositoryProvider<CrmRepository>.value(value: repo, child: child);
  }

  /// Жмёт «+» счётчика под подписью [label] [times] раз.
  Future<void> tapPlus(WidgetTester tester, String label, int times) async {
    final plus = find
        .descendant(
          of: find
              .ancestor(of: find.text(label), matching: find.byType(Column))
              .first,
          matching: find.byIcon(Icons.add),
        )
        .first;
    await tester.ensureVisible(plus);
    await tester.pump();
    for (var i = 0; i < times; i++) {
      await tester.tap(plus);
      await tester.pump();
    }
  }

  /// Число в счётчике под подписью [label].
  Finder counter(String label, String value) => find.descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Column))
            .first,
        matching: find.text(value),
      );

  testWidgets('в количество заказа вводится 150 капсул', (tester) async {
    useLargeSurface(tester);
    int? qty;
    await tester.pumpWidget(app(Scaffold(
      body: SingleChildScrollView(
        child: RouteStopEditor(
          stop: const RouteDraftStop(customerId: 'c1', qty: 1),
          unitPrice: 20000,
          onPurpose: (_) {},
          onQty: (value) => qty = value,
          onPrice: (_) {},
          onComment: (_) {},
        ),
      ),
    )));

    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == '1',
    );
    await tester.enterText(field, '150');
    await tester.pump();

    expect(qty, 150);
  });

  testWidgets('форма заказчика: капсул на руках можно больше 99',
      (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      app(const CustomerFormPage(), repo: MockCrmRepository()),
    );
    // Автофокус держит мигающий курсор — без pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tapPlus(tester, 'Капсул у заказчика', 99);
    expect(counter('Капсул у заказчика', '99'), findsOneWidget);

    // Раньше «+» гас на 99 — сотое нажатие уже ничего не делало.
    await tapPlus(tester, 'Капсул у заказчика', 21);
    expect(counter('Капсул у заказчика', '120'), findsOneWidget);
  });

  testWidgets('десктоп: капсул на руках можно больше 99', (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(app(
      const Scaffold(body: SingleChildScrollView(child: CustomerFormModal())),
      repo: MockCrmRepository(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tapPlus(tester, 'Капсул у заказчика', 99);
    expect(counter('Капсул у заказчика', '99'), findsOneWidget);

    await tapPlus(tester, 'Капсул у заказчика', 21);
    expect(counter('Капсул у заказчика', '120'), findsOneWidget);
  });
}

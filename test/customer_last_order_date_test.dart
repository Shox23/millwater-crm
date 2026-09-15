import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/mock/mock_store.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/presentation/customer_form_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// Дата последнего заказа в форме заказчика.
///
/// Сервер принимает её при создании и правке, но с двумя оговорками, ради
/// которых и тесты: сравнивает с наивным `datetime.now()` — метка с зоной
/// роняет валидатор в 500, поэтому на провод уходит один день; и `null` в
/// PATCH выбрасывает — дату нельзя стереть, а форма без явной правки не
/// должна откатывать ту, что поставило закрытие доставки.
void main() {
  /// Подменяет заказчика в сторе — так «сервер» меняется за спиной у формы.
  void replaceCustomer(MockStore store, Customer c) {
    store.customers[store.customers.indexWhere((x) => x.id == c.id)] = c;
  }

  Customer customer({DateTime? lastOrder}) => Customer(
        id: 'c1',
        name: 'Кафе',
        phone: '+998901112233',
        address: 'ул. Тестовая, 1',
        lastOrderDate: lastOrder,
        createdAt: DateTime(2026, 1, 1),
      );

  group('На провод', () {
    test('без признака правки дата не уходит', () {
      final json = customer(lastOrder: DateTime(2026, 8, 10, 14, 30))
          .toUpdateJson();

      expect(json.containsKey('last_order_date'), isFalse);
    });

    test('с признаком — одним днём, без времени и зоны', () {
      final json = customer(lastOrder: DateTime(2026, 8, 10, 14, 30))
          .toUpdateJson(includeLastOrderDate: true);

      expect(json['last_order_date'], '2026-08-10');
    });

    test('признак без даты ничего не отправляет: стереть её нельзя', () {
      final json = customer().toUpdateJson(includeLastOrderDate: true);

      expect(json.containsKey('last_order_date'), isFalse);
    });
  });

  group('Мок ведёт себя как сервер', () {
    late MockCrmRepository repo;

    setUp(() => repo = MockCrmRepository());

    test('правка без признака не откатывает дату, поставленную доставкой',
        () async {
      final opened = repo.store.customers.first;
      // Пока форма открыта, водитель закрыл доставку — дата сдвинулась.
      final byDriver = DateTime(2026, 9, 14, 11);
      replaceCustomer(repo.store, opened.copyWith(lastOrderDate: byDriver));

      final saved = await repo.updateCustomer(opened.copyWith(name: 'Новое'));

      expect(saved.name, 'Новое');
      expect(saved.lastOrderDate, byDriver);
    });

    test('с признаком дата заменяется', () async {
      final opened = repo.store.customers.first;
      final manual = DateTime(2026, 7, 1);

      final saved = await repo.updateCustomer(
        opened.copyWith(lastOrderDate: manual),
        lastOrderDateChanged: true,
      );

      expect(saved.lastOrderDate, manual);
    });
  });

  group('Форма заказчика', () {
    late MockCrmRepository repo;

    setUp(() => repo = MockCrmRepository());

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> pumpForm(WidgetTester tester, {Customer? customer}) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            theme: AppTheme.light(),
            home: CustomerFormPage(customer: customer),
          ),
        ),
      );
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Finder inputFor(String label) => find.descendant(
          of: find
              .ancestor(of: find.text(label), matching: find.byType(Column))
              .first,
          matching: find.byType(TextField),
        );

    Future<void> fillRequired(WidgetTester tester) async {
      await tester.enterText(inputFor('Название / имя'), 'Кафе «Nasiba»');
      await tester.enterText(inputFor('Номер телефона'), '901234567');
      await tester.enterText(inputFor('Адрес доставки'), 'Чиланзар, 12');
      await settle(tester);
    }

    Future<void> submit(WidgetTester tester, String label) async {
      final button = find.widgetWithText(AppButton, label);
      await tester.ensureVisible(button);
      await settle(tester);
      await tester.tap(button);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
    }

    /// Открывает календарь по карточке и подтверждает предложенный день.
    Future<void> pickSuggestedDate(WidgetTester tester) async {
      final card = find.text('Последний заказ');
      await tester.ensureVisible(card);
      await settle(tester);
      await tester.tap(card);
      await settle(tester);

      final picker = find.byType(CalendarDatePicker);
      expect(picker, findsOneWidget);
      final ok = MaterialLocalizations.of(tester.element(picker)).okButtonLabel;
      await tester.tap(find.text(ok));
      await settle(tester);
    }

    testWidgets('у нового заказчика дата не указана и уходит выбранной',
        (tester) async {
      await pumpForm(tester);
      expect(find.text('Не указан'), findsOneWidget);

      await fillRequired(tester);
      // Календарь открывается на сегодня, и позже сегодняшнего не пускает.
      await pickSuggestedDate(tester);
      final today = DateTime.now();
      expect(find.text(DateFormat('dd.MM.yyyy').format(today)), findsOneWidget);

      await submit(tester, 'Добавить');

      final created = repo.store.customers.last;
      expect(created.name, 'Кафе «Nasiba»');
      expect(
        created.lastOrderDate,
        DateTime(today.year, today.month, today.day),
      );
    });

    testWidgets('правка открывается с прежней датой и без правки её не шлёт',
        (tester) async {
      final opened = repo.store.customers.first
          .copyWith(lastOrderDate: DateTime(2026, 8, 10, 14, 30));
      replaceCustomer(repo.store, opened);
      await pumpForm(tester, customer: opened);

      expect(find.text('10.08.2026'), findsOneWidget);

      // Пока форма открыта, доставка сдвинула дату на сервере.
      final byDriver = DateTime(2026, 9, 14, 11);
      replaceCustomer(repo.store, opened.copyWith(lastOrderDate: byDriver));

      await tester.enterText(inputFor('Название / имя'), 'Другое имя');
      await settle(tester);
      await submit(tester, 'Сохранить');

      final saved = repo.store.customers.firstWhere((c) => c.id == opened.id);
      expect(saved.name, 'Другое имя');
      expect(saved.lastOrderDate, byDriver);
    });
  });
}

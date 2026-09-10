import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/presentation/customer_form_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Новые поля формы заказчика: кулеры, стартовый баланс, своя цена.
///
/// Три вещи, которые сервер теперь принимает и на которых легко ошибиться:
/// кулеры стали числом вместо галочки, долг с предоплатой взаимоисключающи
/// (иначе 422 `BOTH_BALANCES_SET`), а индивидуальная цена — это `null`,
/// когда её убирают, а не ноль.
void main() {
  late MockCrmRepository repo;

  setUp(() => repo = MockCrmRepository());

  void useLargeSurface(WidgetTester tester) {
    // В тестах вместо Inter подставляется шрифт тестового рендерера с более
    // широкими глифами — на узком экране подписи кнопок в него не влезают.
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Прокачивает кадры вместо `pumpAndSettle`: автофокус держит мигающий
  /// курсор, и «до полной остановки» экран формы не доходит никогда.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpForm(WidgetTester tester, {Customer? customer}) async {
    useLargeSurface(tester);
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
    // Форма спрашивает действующий прайс для подсказки под ценой — даём
    // моку ответить, иначе подсказки на экране не будет.
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder inputFor(String label) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      );

  Future<void> fillRequired(WidgetTester tester) async {
    await tester.enterText(inputFor('Название / имя'), 'Кафе «Nasiba»');
    await tester.enterText(inputFor('Номер телефона'), '901234567');
    await tester.enterText(inputFor('Адрес доставки'), 'Чиланзар, 12');
    await settle(tester);
  }

  bool submitEnabled(WidgetTester tester, String label) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, label)).enabled;

  Future<Customer> saved(WidgetTester tester) async {
    final submit = find.widgetWithText(AppButton, 'Добавить');
    await tester.ensureVisible(submit);
    await settle(tester);
    await tester.tap(submit);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
    return repo.store.customers.last;
  }

  /// Нажимает по подписи, подведя её к видимой области: форма длиннее
  /// тестового окна, и нижние блоки без прокрутки не нажимаются.
  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text).first;
    await tester.ensureVisible(target);
    await settle(tester);
    await tester.tap(target);
    await settle(tester);
  }

  /// Плюс у степпера кулеров — единственный на экране.
  Future<void> addCooler(WidgetTester tester) async {
    final plus = find.byIcon(Icons.add);
    await tester.ensureVisible(plus.first);
    await tester.pump();
    await tester.tap(plus.first);
    await settle(tester);
  }

  group('Кулеры', () {
    testWidgets('счётчик уходит на сервер числом, а не галочкой',
        (tester) async {
      await pumpForm(tester);
      await fillRequired(tester);

      await addCooler(tester);
      await addCooler(tester);

      expect((await saved(tester)).coolerCount, 2);
    });

    testWidgets('правка открывается с прежним количеством', (tester) async {
      // Булев признак мигрирует сам: `hasCooler` теперь производное.
      final customer = repo.store.customers.first.copyWith(coolerCount: 3);
      await pumpForm(tester, customer: customer);

      expect(find.text('3'), findsWidgets);
    });
  });

  group('Капсулы у заказчика', () {
    testWidgets('счётчик уходит на сервер при создании', (tester) async {
      await pumpForm(tester);
      await fillRequired(tester);

      // Новый заказчик приходит со своей тарой от прежнего поставщика: без
      // этого числа первая же доставка разошлась бы со складом.
      await tapText(tester, 'Капсул у заказчика');
      final plus = find.byIcon(Icons.add);
      await tester.ensureVisible(plus.at(1));
      await tester.pump();
      await tester.tap(plus.at(1));
      await settle(tester);
      await tester.tap(plus.at(1));
      await settle(tester);

      expect((await saved(tester)).capsuleBalance, 2);
    });

    testWidgets('правка открывается с текущим остатком', (tester) async {
      final customer = repo.store.customers.first.copyWith(capsuleBalance: 7);
      repo.store.customers[0] = customer;
      await pumpForm(tester, customer: customer);

      expect(find.text('7'), findsWidgets);
    });

    testWidgets('правка чужого поля остаток не откатывает', (tester) async {
      // Пока админ правит комментарий, водитель может закрыть доставку и
      // изменить остаток. Форма не должна затирать его своим числом.
      final customer = repo.store.customers.first.copyWith(capsuleBalance: 5);
      repo.store.customers[0] = customer;
      await pumpForm(tester, customer: customer);

      await tester.enterText(inputFor('Комментарий'), 'Мирабад');
      await settle(tester);
      // Водитель закрыл доставку, пока форма была открыта.
      repo.store.customers[0] =
          repo.store.customers.first.copyWith(capsuleBalance: 2);

      final submit = find.widgetWithText(AppButton, 'Сохранить');
      await tester.ensureVisible(submit);
      await settle(tester);
      await tester.tap(submit);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.store.customers.first.capsuleBalance, 2);
    });
  });

  group('Стартовый баланс', () {
    testWidgets('поле суммы появляется только с выбранным видом',
        (tester) async {
      await pumpForm(tester);
      expect(find.text('Сумма'), findsNothing);

      await tapText(tester, 'Долг');

      expect(find.text('Сумма'), findsOneWidget);
    });

    testWidgets('вид без суммы отправить нельзя', (tester) async {
      await pumpForm(tester);
      await fillRequired(tester);
      expect(submitEnabled(tester, 'Добавить'), isTrue);

      await tapText(tester, 'Долг');

      // «Долг» с пустым полем — это не ноль, а недозаполненная форма.
      expect(submitEnabled(tester, 'Добавить'), isFalse);
    });

    testWidgets('долг уходит долгом, предоплата — предоплатой', (tester) async {
      await pumpForm(tester);
      await fillRequired(tester);

      await tapText(tester, 'Долг');
      await tester.enterText(inputFor('Сумма'), '50000');
      await settle(tester);

      final customer = await saved(tester);
      // Оба ненулевыми сервер не примет (422 BOTH_BALANCES_SET) — форма и не
      // даёт их собрать: вид один на двоих.
      expect(customer.debt, 50000);
      expect(customer.prepayment, 0);
    });

    testWidgets('переключение на «Нет» стирает сумму', (tester) async {
      await pumpForm(tester);
      await fillRequired(tester);

      await tapText(tester, 'Предоплата');
      await tester.enterText(inputFor('Сумма'), '30000');
      await settle(tester);

      await tapText(tester, 'Нет');

      final customer = await saved(tester);
      expect(customer.prepayment, 0);
      expect(customer.debt, 0);
    });
  });

  group('Индивидуальная цена', () {
    testWidgets('поле появляется по переключателю и уходит на сервер',
        (tester) async {
      await pumpForm(tester);
      await fillRequired(tester);
      expect(find.text('Цена для заказчика'), findsNothing);

      await tapText(tester, 'Своя');
      await tester.enterText(inputFor('Цена для заказчика'), '15000');
      await settle(tester);

      expect((await saved(tester)).customWaterPrice, 15000);
    });

    testWidgets('включённая своя цена без суммы форму блокирует',
        (tester) async {
      await pumpForm(tester);
      await fillRequired(tester);

      await tapText(tester, 'Своя');

      // Сервер требует цену больше нуля — пустое поле он отвергнет.
      expect(submitEnabled(tester, 'Добавить'), isFalse);
    });

    testWidgets('возврат «По прайсу» очищает цену, а не оставляет старую',
        (tester) async {
      final customer =
          repo.store.customers.first.copyWith(customWaterPrice: 15000);
      repo.store.customers[0] = customer;
      await pumpForm(tester, customer: customer);

      await tapText(tester, 'По прайсу');
      final submit = find.widgetWithText(AppButton, 'Сохранить');
      await tester.ensureVisible(submit);
      await settle(tester);
      await tester.tap(submit);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));

      // `null` — осмысленный вход: «считать по общему прайсу».
      expect(repo.store.customers.first.customWaterPrice, isNull);
      expect(repo.store.customers.first.hasIndividualPrice, isFalse);
    });
  });
}

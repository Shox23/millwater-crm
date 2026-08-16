import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/presentation/customer_detail_page.dart';
import 'package:crm_millwater/features/customers/presentation/customers_page.dart';
import 'package:crm_millwater/features/customers/presentation/widgets/customer_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Заказчик с обоими ненулевыми балансами — сервер такое допускает.
Customer _withBoth() => Customer(
      id: 'c-both',
      name: 'Кафе «Обе стороны»',
      phone: '+998901112233',
      address: 'ул. Тестовая, 1',
      capsuleBalance: 6,
      prepayment: 200000,
      debt: 300000,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late MockCrmRepository repo;

  setUp(() => repo = MockCrmRepository());

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Widget wrap(Widget page) => RepositoryProvider<CrmRepository>.value(
        value: repo,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: page,
        ),
      );

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    useLargeSurface(tester);
    await tester.pumpWidget(wrap(page));
    // Мок отвечает через Future.delayed — прокручиваем фейковые часы.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('Комментарий заказчика', () {
    test('пустое поле стирает комментарий, а не сохраняет прежний', () {
      final customer = Customer(
        id: 'c1',
        name: 'Кафе',
        phone: '+998901112233',
        address: 'ул. Тестовая, 1',
        comment: 'Мирабад',
        createdAt: DateTime(2026, 1, 1),
      );

      // Форма отдаёт null, когда поле очистили. Раньше `??` в copyWith
      // трактовал это как «не менять», и очистка молча терялась.
      expect(customer.copyWith(comment: null).comment, isNull);
      expect(customer.copyWith(comment: 'Юнусабад').comment, 'Юнусабад');
      // Не передали вовсе — значение остаётся прежним.
      expect(customer.copyWith(name: 'Другое').comment, 'Мирабад');
    });

    test('очищенный комментарий уходит в PATCH пустым', () {
      final customer = Customer(
        id: 'c1',
        name: 'Кафе',
        phone: '+998901112233',
        address: 'ул. Тестовая, 1',
        comment: 'Мирабад',
        createdAt: DateTime(2026, 1, 1),
      );

      final json = customer.copyWith(comment: null).toUpdateJson();
      expect(json['comment'], isNull);
    });
  });

  group('Долг и предоплата вместе', () {
    testWidgets('в списке видны оба', (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(wrap(
        Scaffold(body: CustomerCard(customer: _withBoth())),
      ));
      await tester.pump();

      // Раньше побеждала предоплата, и долг не показывался вовсе.
      expect(find.text('Долг'), findsOneWidget);
      expect(find.text('Предоплата'), findsOneWidget);
    });

    testWidgets('в карточке заказчика видны оба', (tester) async {
      await pumpPage(tester, CustomerDetailPage(customer: _withBoth()));

      expect(find.text('Долг'), findsOneWidget);
      expect(find.text('Предоплата'), findsOneWidget);
    });

    testWidgets('когда баланс один — бейдж один', (tester) async {
      final onlyDebt = _withBoth().copyWith(prepayment: 0);
      useLargeSurface(tester);
      await tester.pumpWidget(wrap(
        Scaffold(body: CustomerCard(customer: onlyDebt)),
      ));
      await tester.pump();

      expect(find.text('Долг'), findsOneWidget);
      expect(find.text('Предоплата'), findsNothing);
    });
  });

  group('Карточка заказчика', () {
    testWidgets('остаток капсул подписан как остаток, а не как заказ',
        (tester) async {
      await pumpPage(tester, CustomerDetailPage(customer: _withBoth()));

      // `bottle_balance` — тара на руках; «капсул / заказ» было неправдой.
      expect(find.text('капсул на руках'), findsOneWidget);
      expect(find.text('капсул / заказ'), findsNothing);
    });
  });

  group('Список заказчиков', () {
    testWidgets('поиск не стирает список, пока идёт запрос', (tester) async {
      await pumpPage(tester, const CustomersPage());
      expect(find.text('Кафе «Nasiba»'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Nasiba');
      // Дебаунс 300 мс, ответ мока ещё 150 — момент, когда запрос в пути.
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Кафе «Nasiba»'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('на первой загрузке спиннер всё-таки есть', (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(wrap(const CustomersPage()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('подпись шапки не выдаёт найденных за всю базу',
        (tester) async {
      await pumpPage(tester, const CustomersPage());
      // ScreenHeader рисует подпись капсом.
      expect(find.textContaining('БАЗА · '), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Nasiba');
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.textContaining('БАЗА · '), findsNothing);
      expect(find.textContaining('НАЙДЕНО · '), findsOneWidget);
    });
  });
}

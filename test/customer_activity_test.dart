import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/app/theme/app_tokens.dart';
import 'package:crm_millwater/core/widgets/app_card.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/features/customers/presentation/widgets/customer_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// «Сегодня» для всех проверок — фиксированный день, чтобы пороги не
/// зависели от того, когда запущен тест.
final _today = DateTime(2026, 9, 15, 10, 30);

Customer _customer({DateTime? lastOrder, DateTime? created}) => Customer(
      id: 'c1',
      name: 'Кафе',
      phone: '+998901112233',
      address: 'ул. Тестовая, 1',
      lastOrderDate: lastOrder,
      createdAt: created ?? DateTime(2026, 1, 1),
    );

DateTime _daysAgo(int days, {int hour = 12}) =>
    DateTime(_today.year, _today.month, _today.day - days, hour);

void main() {
  group('Давность последнего заказа', () {
    test('заказывал в последний месяц — обычный', () {
      expect(_customer(lastOrder: _daysAgo(0)).activityOn(_today),
          CustomerActivity.recent);
      expect(_customer(lastOrder: _daysAgo(30)).activityOn(_today),
          CustomerActivity.recent);
    });

    test('больше месяца — остывший', () {
      expect(_customer(lastOrder: _daysAgo(31)).activityOn(_today),
          CustomerActivity.stale);
      expect(_customer(lastOrder: _daysAgo(60)).activityOn(_today),
          CustomerActivity.stale);
    });

    test('больше двух месяцев — ушедший', () {
      expect(_customer(lastOrder: _daysAgo(61)).activityOn(_today),
          CustomerActivity.dormant);
      expect(_customer(lastOrder: _daysAgo(400)).activityOn(_today),
          CustomerActivity.dormant);
    });

    test('ни разу не заказывал — считается от дня, когда завели', () {
      // Заведён вчера — новичок, подсвечивать нечего.
      expect(
        _customer(created: _daysAgo(1)).activityOn(_today),
        CustomerActivity.recent,
      );
      // Заведён три месяца назад и молчит — та же потеря, что и ушедший.
      expect(
        _customer(created: _daysAgo(90)).activityOn(_today),
        CustomerActivity.dormant,
      );
    });

    test('порог считается по календарным дням, а не по часам', () {
      // Доставка поздно вечером ровно 30 дней назад: по часам до «сейчас»
      // меньше 30 суток нет, но и больше — тоже нет. Календарь говорит «30».
      expect(
        _customer(lastOrder: _daysAgo(30, hour: 23)).activityOn(_today),
        CustomerActivity.recent,
      );
      // А 31-й день начинается с полуночи, не с того же часа.
      expect(
        _customer(lastOrder: _daysAgo(31, hour: 23)).activityOn(_today),
        CustomerActivity.stale,
      );
    });
  });

  group('Карточка заказчика в списке', () {
    Widget wrap(Widget child) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: Scaffold(body: child),
        );

    Future<Color?> cardColor(WidgetTester tester, Customer customer) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(CustomerCard(customer: customer)));
      await tester.pump();
      return tester.widget<AppCard>(find.byType(AppCard)).color;
    }

    // Карточка берёт «сегодня» из часов устройства, поэтому даты здесь
    // считаются от настоящего дня.
    DateTime realDaysAgo(int days) =>
        DateTime.now().subtract(Duration(days: days));

    testWidgets('активный — без подсветки', (tester) async {
      final color = await cardColor(
        tester,
        _customer(lastOrder: realDaysAgo(3)),
      );
      expect(color, isNull);
    });

    testWidgets('месяц без заказов — жёлтая', (tester) async {
      final color = await cardColor(
        tester,
        _customer(lastOrder: realDaysAgo(40)),
      );
      expect(color, AppTokens.light.staleBg);
    });

    testWidgets('два месяца без заказов — светло-красная', (tester) async {
      final color = await cardColor(
        tester,
        _customer(lastOrder: realDaysAgo(75)),
      );
      expect(color, AppTokens.light.dormantBg);
    });
  });
}

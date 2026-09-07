import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/orders/presentation/order_detail_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Состав заказа в карточке.
///
/// Сервер отдаёт нули и по тем показателям, которых у этой цели не бывает,
/// — у вывоза внизу висели «Бутыли 5 л — 0» и «Бутыли 10 л — 0». Карточка
/// показывает свои показатели цели плюс всё ненулевое.
void main() {
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Order order(Map<String, dynamic> extra) => Order.fromJson({
        'id': 'o-1',
        'number': 42,
        // Не `delivered`: бейдж статуса подписан тем же словом, что и
        // строка состава «Доставлено», и поиск по тексту их не различит.
        'status': 'on_way',
        'created_at': '2026-09-04T08:00:00Z',
        'customer': {'customer_full_name': 'Кафе'},
        ...extra,
      });

  Future<void> pumpOrder(WidgetTester tester, Order value) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      RepositoryProvider<CrmRepository>.value(
        value: MockCrmRepository(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: OrderDetailPage(order: value),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('вывоз не показывает пустые строки опта', (tester) async {
    await pumpOrder(
      tester,
      order({
        'purpose': 'pickup',
        'picked_coolers': 2,
        'picked_bottles': 3,
        'damaged_bottles': 0,
        // Сервер шлёт нули по чужим показателям — их и не должно быть видно.
        'delivered_bottles': 0,
        'bulk_5l_count': 0,
        'bulk_10l_count': 0,
      }),
    );

    expect(find.text('Кулеров забрано'), findsOneWidget);
    expect(find.text('Капсул забрано'), findsOneWidget);
    // Брак — показатель вывоза тоже: за него берут штраф.
    expect(find.text('Повреждено'), findsOneWidget);

    expect(find.text('Бутыли 5 л'), findsNothing);
    expect(find.text('Бутыли 10 л'), findsNothing);
    expect(find.text('Доставлено'), findsNothing);
  });

  testWidgets('у доставки ноль своего показателя остаётся', (tester) async {
    // «Привезли ноль» — это результат, а не отсутствие данных: заказ могли
    // закрыть одним браком.
    await pumpOrder(
      tester,
      order({
        'purpose': 'delivery_19l',
        'delivered_bottles': 0,
        'damaged_bottles': 2,
        'picked_coolers': 0,
      }),
    );

    expect(find.text('Доставлено'), findsOneWidget);
    expect(find.text('Повреждено'), findsOneWidget);
    expect(find.text('Кулеров забрано'), findsNothing);
  });

  testWidgets('чужой ненулевой показатель показывается', (tester) async {
    // Заказы, закрытые до релиза: цели ещё не было, и всё шло одной строкой.
    await pumpOrder(
      tester,
      order({
        'purpose': 'bulk_water',
        'bulk_5l_count': 10,
        'bulk_10l_count': 0,
        'delivered_bottles': 4,
      }),
    );

    expect(find.text('Бутыли 5 л'), findsOneWidget);
    // Ноль своего показателя остаётся, чужой ненулевой — добавляется.
    expect(find.text('Бутыли 10 л'), findsOneWidget);
    expect(find.text('Доставлено'), findsOneWidget);
  });
}

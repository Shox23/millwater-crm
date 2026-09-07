import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/stop_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Итоговая строка закрытой точки маршрута.
///
/// Строка собиралась из доставленных капсул при любой цели, и закрытый вывоз
/// показывался как «0 капсул»: два кулера и три капсулы, которые водитель
/// увёз, из карточки пропадали. У опта так же пропадали проданные бутыли.
void main() {
  void useLargeSurface(WidgetTester tester) {
    // В тестах вместо Inter подставляется шрифт тестового рендерера с более
    // широкими глифами — на узком экране подписи в него не влезают.
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  RouteStop stop({
    required OrderPurpose purpose,
    int? delivered,
    int? pickedCoolers,
    int? pickedBottles,
    int? bulk5l,
    int? bulk10l,
  }) =>
      RouteStop(
        id: 's-1',
        customerId: 'c-1',
        customerName: 'Кафе',
        customerAddress: 'Чиланзар',
        customerPhone: '+998901234567',
        status: DeliveryStatus.delivered,
        completedAt: DateTime(2026, 9, 4),
        purpose: purpose,
        deliveredCapsules: delivered,
        pickedCoolers: pickedCoolers,
        pickedBottles: pickedBottles,
        bulk5lCount: bulk5l,
        bulk10lCount: bulk10l,
        paymentAmount: 0,
      );

  Future<void> pumpCard(WidgetTester tester, RouteStop value) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocales.supported,
        locale: AppLocales.ru,
        theme: AppTheme.light(),
        home: Scaffold(body: StopCard(stop: value)),
      ),
    );
    await tester.pump();
  }

  testWidgets('доставка считает капсулы', (tester) async {
    await pumpCard(tester, stop(purpose: OrderPurpose.delivery19l, delivered: 3));

    expect(find.text('3 капсулы'), findsOneWidget);
  });

  testWidgets('вывоз показывает забранное, а не ноль капсул', (tester) async {
    await pumpCard(
      tester,
      stop(purpose: OrderPurpose.pickup, pickedCoolers: 2, pickedBottles: 3),
    );

    expect(find.text('2 кулера · 3 капсулы'), findsOneWidget);
    // Именно от этой строки и уходим: доставленных капсул у вывоза нет.
    expect(find.text('0 капсул'), findsNothing);
  });

  testWidgets('нулевые позиции в строку не попадают', (tester) async {
    await pumpCard(
      tester,
      stop(purpose: OrderPurpose.pickup, pickedCoolers: 1, pickedBottles: 0),
    );

    expect(find.text('1 кулер'), findsOneWidget);
  });

  testWidgets('опт показывает бутыли', (tester) async {
    await pumpCard(
      tester,
      stop(purpose: OrderPurpose.bulkWater, bulk5l: 10, bulk10l: 4),
    );

    expect(find.text('10 × 5 л · 4 × 10 л'), findsOneWidget);
  });

  testWidgets('вывоз без позиций не оставляет пустую строку', (tester) async {
    // Точка закрыта одним браком: показать нечего, но и молчать нельзя —
    // пустая строка читалась бы как незагрузившиеся данные.
    await pumpCard(tester, stop(purpose: OrderPurpose.pickup));

    expect(find.text('ничего не забрали'), findsOneWidget);
  });
}

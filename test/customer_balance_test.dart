import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/core/widgets/quantity_stepper.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/presentation/delivery_completion_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Остаток капсул заказчика на экране завершения.
///
/// Сервер этим числом ЗАМЕНЯЕТ склад клиента (`customer.bottle_balance =
/// payload.bottle_balance`), а показать водителю прежнее значение до правки
/// было нечем: в заказе приходили кулеры, долг и предоплата — остатка не было.
void main() {
  RouteStop stop({int? balance, int? delivered}) => RouteStop(
        id: 'stop-1',
        customerId: 'c-1',
        customerName: 'Заказчик',
        customerAddress: 'Ташкент, Чиланзар 12',
        customerPhone: '+998901234567',
        status: DeliveryStatus.pending,
        deliveredCapsules: delivered,
        customerBottleBalance: balance,
      );

  Future<void> pumpPage(WidgetTester tester, RouteStop s) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepositoryProvider<DriverRepository>.value(
        value: MockDriverRepository(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: DeliveryCompletionPage(
            stop: s,
            price: const BuildCapsulePrice(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('Разбор остатка', () {
    test('берётся из вложенного customer', () {
      final s = RouteStop.fromJson(const {
        'id': 's1',
        'status': 'pending',
        'customer': {
          'customer_id': 'c1',
          'customer_full_name': 'Заказчик',
          'customer_address': 'Адрес',
          'customer_phone': '+998901112233',
          'customer_bottle_balance': 7,
        },
      });
      expect(s.customerBottleBalance, 7);
    });

    test('стенд без поля не роняет разбор — остаётся null', () {
      final s = RouteStop.fromJson(const {
        'id': 's1',
        'status': 'pending',
        'customer': {
          'customer_id': 'c1',
          'customer_full_name': 'Заказчик',
          'customer_address': 'Адрес',
          'customer_phone': '+998901112233',
        },
      });
      expect(s.customerBottleBalance, isNull);
    });
  });

  group('Экран завершения', () {
    testWidgets('к остатку с сервера прибавляются привезённые капсулы',
        (tester) async {
      await pumpPage(tester, stop(balance: 3, delivered: 2));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('было 3 + привезено 2'), findsOneWidget);
    });

    testWidgets('остаток пересчитывается за счётчиком капсул', (tester) async {
      await pumpPage(tester, stop(balance: 3, delivered: 2));
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();

      expect(find.text('было 3 + привезено 3'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('остаток руками не правится: счётчика у него нет',
        (tester) async {
      await pumpPage(tester, stop(balance: 3, delivered: 2));
      // Счётчики остаются только у количества, возврата и брака — у остатка
      // своего больше нет.
      expect(find.byType(QuantityStepper), findsNWidgets(3));
    });

    testWidgets('без остатка с сервера считается от нуля', (tester) async {
      await pumpPage(tester, stop(delivered: 2));
      expect(find.text('было 0 + привезено 2'), findsOneWidget);
    });
  });
}

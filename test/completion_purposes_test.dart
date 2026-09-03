import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/presentation/delivery_completion_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Экран завершения заказа под три цели.
///
/// Один экран отчитывается за три разных дела: привезли капсулы, забрали
/// кулер, продали опт. Поля и формула у них не совпадают, а ошибка стоит
/// дорого: сервер считает деньги по своим правилам и разницу запишет
/// заказчику в долг.
class _RecordingRepository extends MockDriverRepository {
  _RecordingRepository() : super(driverId: 'd1');

  OrderPurpose? purpose;
  int? amount;
  int? capsules;
  int? returned;
  int? damaged;
  int? balance;
  int? bulk5Count;
  int? bulk5Price;
  int? bulk10Count;
  int? bulk10Price;
  int? coolers;
  int? bottles;

  @override
  Future<void> completeDelivery({
    required String stopId,
    required OrderPurpose purpose,
    required int amount,
    required PaymentMethod method,
    int capsules = 0,
    int returnedCapsules = 0,
    int damagedCapsules = 0,
    int? bottleBalance,
    int bulk5lCount = 0,
    int? bulk5lPrice,
    int bulk10lCount = 0,
    int? bulk10lPrice,
    int pickedCoolers = 0,
    int pickedBottles = 0,
    String? photoPath,
    String? idempotencyKey,
    double? latitude,
    double? longitude,
  }) async {
    this.purpose = purpose;
    this.amount = amount;
    this.capsules = capsules;
    returned = returnedCapsules;
    damaged = damagedCapsules;
    balance = bottleBalance;
    bulk5Count = bulk5lCount;
    bulk5Price = bulk5lPrice;
    bulk10Count = bulk10lCount;
    bulk10Price = bulk10lPrice;
    coolers = pickedCoolers;
    bottles = pickedBottles;
  }
}

RouteStop _stop({
  OrderPurpose purpose = OrderPurpose.delivery19l,
  int? effectiveWaterPrice,
  int? damagedBottleFine,
}) =>
    RouteStop(
      id: 'stop-1',
      customerId: 'c-1',
      customerName: 'Кафе Тест',
      customerAddress: 'ул. Тестовая, 1',
      customerPhone: '+998900000002',
      status: DeliveryStatus.pending,
      purpose: purpose,
      effectiveWaterPrice: effectiveWaterPrice,
      damagedBottleFine: damagedBottleFine,
    );

void main() {
  late _RecordingRepository repo;

  setUp(() => repo = _RecordingRepository());

  Future<void> pumpPage(WidgetTester tester, RouteStop stop) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepositoryProvider<DriverRepository>.value(
        value: repo,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: DeliveryCompletionPage(
            stop: stop,
            price: const BuildCapsulePrice(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pump();
  }

  /// Что стоит в поле суммы. Проверяем контроллер, а не подпись: «Итого»
  /// форматируется с разделителями разрядов, и сверять его строкой хрупко.
  String amountText(WidgetTester tester, [int index = 0]) =>
      tester.widget<TextField>(find.byType(TextField).at(index)).controller!.text;

  bool submitEnabled(WidgetTester tester) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, 'Завершить'))
          .enabled;

  group('Доставка 19 л', () {
    testWidgets('цена берётся из заказа, а не из общего прайса',
        (tester) async {
      // У заказчика индивидуальная цена: общий прайс дал бы другую сумму, и
      // расчёт разошёлся бы с серверным.
      await pumpPage(tester, _stop(effectiveWaterPrice: 15000));

      expect(amountText(tester), '15000');
    });

    testWidgets('брак добавляет штраф к сумме', (tester) async {
      await pumpPage(
        tester,
        _stop(effectiveWaterPrice: 20000, damagedBottleFine: 40000),
      );

      // Счётчики по порядку: привезено, забрано пустых, повреждено, остаток.
      await tapVisible(tester, find.byIcon(Icons.add).at(2));

      // 1 × 20 000 + 1 × 40 000
      expect(amountText(tester), '60000');
    });

    testWidgets('возврат и брак уходят на сервер', (tester) async {
      await pumpPage(tester, _stop(effectiveWaterPrice: 20000));

      await tapVisible(tester, find.byIcon(Icons.add).at(1));
      await tapVisible(tester, find.byIcon(Icons.add).at(2));
      await tapVisible(tester, find.text('Завершить'));

      expect(repo.purpose, OrderPurpose.delivery19l);
      expect(repo.returned, 1);
      expect(repo.damaged, 1);
      // Остаток заказчика правит только доставка.
      expect(repo.balance, isNotNull);
    });
  });

  group('Вывоз', () {
    testWidgets('спрашивает кулеры и капсулы, а не доставку', (tester) async {
      await pumpPage(tester, _stop(purpose: OrderPurpose.pickup));

      expect(find.text('КУЛЕРОВ ЗАБРАНО'), findsOneWidget);
      expect(find.text('КАПСУЛ ЗАБРАНО'), findsOneWidget);
      // Привезённых капсул и остатка у клиента здесь нет: ничего не привозили.
      expect(find.text('КОЛИЧЕСТВО КАПСУЛ'), findsNothing);
      expect(find.text('КАПСУЛ У КЛИЕНТА'), findsNothing);
    });

    testWidgets('сумма нулевая и остаток не перезаписывается', (tester) async {
      await pumpPage(tester, _stop(purpose: OrderPurpose.pickup));

      await tapVisible(tester, find.byIcon(Icons.add).first);
      await tapVisible(tester, find.text('Завершить'));

      expect(repo.purpose, OrderPurpose.pickup);
      expect(repo.amount, 0);
      expect(repo.coolers, 1);
      // `bottle_balance` сервер трактует как новый остаток заказчика —
      // вывоз склад капсул не трогает.
      expect(repo.balance, isNull);
    });
  });

  group('Нулевая сумма', () {
    testWidgets('у вывоза способ сразу «в долг»', (tester) async {
      await pumpPage(tester, _stop(purpose: OrderPurpose.pickup));

      // Иначе первый же вывоз упирался бы в 422: сервер требует сумму
      // больше нуля для всех способов, кроме долга.
      await tapVisible(tester, find.byIcon(Icons.add).first);
      await tapVisible(tester, find.text('Завершить'));

      expect(repo.purpose, OrderPurpose.pickup);
      expect(repo.amount, 0);
      expect(repo.coolers, 1);
    });

    testWidgets('пустой вывоз отправить нельзя', (tester) async {
      await pumpPage(tester, _stop(purpose: OrderPurpose.pickup));

      // Сервер отвергает такой заказ (422 PICKUP_QUANTITY_REQUIRED): водитель
      // приехал и ничего не увёз — закрывать нечего.
      expect(submitEnabled(tester), isFalse);
      expect(find.textContaining('Укажите, что забрали'), findsOneWidget);
    });

    testWidgets('ноль наличными отправить нельзя', (tester) async {
      await pumpPage(tester, _stop(purpose: OrderPurpose.pickup));

      await tapVisible(tester, find.byIcon(Icons.add).first);
      await tapVisible(tester, find.text('Наличные'));

      expect(submitEnabled(tester), isFalse);
      expect(find.textContaining('только со способом'), findsOneWidget);
    });
  });

  group('Опт', () {
    testWidgets('сумма считается по договорным ценам', (tester) async {
      await pumpPage(tester, _stop(purpose: OrderPurpose.bulkWater));

      await tapVisible(tester, find.byIcon(Icons.add).first);
      // Поля по порядку: цена 5 л, цена 10 л, сумма оплаты.
      await tester.enterText(find.byType(TextField).first, '9000');
      await tester.pump();

      expect(amountText(tester, 2), '9000');
    });

    testWidgets('количество без цены отправить нельзя', (tester) async {
      await pumpPage(tester, _stop(purpose: OrderPurpose.bulkWater));

      await tapVisible(tester, find.byIcon(Icons.add).first);

      // Сервер отвергает такой заказ (422) — упираться в отказ у заказчика
      // незачем.
      expect(submitEnabled(tester), isFalse);
      expect(find.textContaining('Укажите цену за бутыль'), findsOneWidget);
    });

    testWidgets('количество и цены уходят на сервер', (tester) async {
      await pumpPage(tester, _stop(purpose: OrderPurpose.bulkWater));

      await tapVisible(tester, find.byIcon(Icons.add).first);
      await tester.enterText(find.byType(TextField).first, '9000');
      await tester.pump();
      await tapVisible(tester, find.text('Завершить'));

      expect(repo.purpose, OrderPurpose.bulkWater);
      expect(repo.bulk5Count, 1);
      expect(repo.bulk5Price, 9000);
      expect(repo.amount, 9000);
    });
  });
}

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/product_config.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/driver_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/features/driver/presentation/delivery_completion_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

RouteStop _stop({int? capsules, int? amount}) => RouteStop(
      id: 'stop-1',
      customerId: 'c-1',
      customerName: 'Заказчик',
      customerAddress: 'Ташкент, Чиланзар 12',
      customerPhone: '+998901234567',
      status: DeliveryStatus.pending,
      deliveredCapsules: capsules,
      paymentAmount: amount,
    );

/// Запоминает сумму, дошедшую до репозитория.
class _RecordingDriverRepository extends MockDriverRepository {
  int? amount;

  @override
  Future<void> completeDelivery({
    required String stopId,
    required int capsules,
    required int amount,
    required int bottleBalance,
    String? photoPath,
    String? idempotencyKey,
    double? latitude,
    double? longitude,
  }) async {
    this.amount = amount;
    return super.completeDelivery(
      stopId: stopId,
      capsules: capsules,
      amount: amount,
      bottleBalance: bottleBalance,
      photoPath: photoPath,
      idempotencyKey: idempotencyKey,
    );
  }
}

void main() {
  final price = ProductConfig.capsulePrice;

  Future<_RecordingDriverRepository> pumpPage(
    WidgetTester tester, {
    RouteStop? stop,
  }) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final repo = _RecordingDriverRepository();
    await tester.pumpWidget(
      RepositoryProvider<DriverRepository>.value(
        value: repo,
        child: MaterialApp(
            // Строки интерфейса берутся из локали: тесты идут на русской.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: DeliveryCompletionPage(stop: stop ?? _stop()),
        ),
      ),
    );
    await tester.pump();
    return repo;
  }

  /// Поле суммы — единственный TextField на экране.
  String amountText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  /// Плюс у «КОЛИЧЕСТВА КАПСУЛ»: второй такой же стоит у остатка клиента,
  /// он идёт ниже по экрану.
  Future<void> addCapsule(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
  }

  group('Сумма считается по прайсу', () {
    testWidgets('на открытии сумма равна капсулы × цена', (tester) async {
      await pumpPage(tester);

      // Одна капсула по умолчанию.
      expect(amountText(tester), '$price');
      expect(find.textContaining('По прайсу: 1 ×'), findsOneWidget);
    });

    testWidgets('количество меняется — сумма пересчитывается', (tester) async {
      await pumpPage(tester);

      await addCapsule(tester);
      expect(amountText(tester), '${price * 2}');

      await addCapsule(tester);
      expect(amountText(tester), '${price * 3}');
      expect(find.textContaining('По прайсу: 3 ×'), findsOneWidget);
    });

    testWidgets('расчёт уходит в репозиторий как есть', (tester) async {
      final repo = await pumpPage(tester);

      await addCapsule(tester);
      await tester.tap(find.text('Завершить'));
      await tester.pumpAndSettle();

      expect(repo.amount, price * 2);
    });
  });

  group('Ручная правка суммы', () {
    testWidgets('переживает изменение количества', (tester) async {
      await pumpPage(tester);

      await tester.enterText(find.byType(TextField), '5000');
      await tester.pump();

      // Частичная оплата или долг — цифра остаётся водителя.
      await addCapsule(tester);
      expect(amountText(tester), '5000');
    });

    testWidgets('возвращается к расчёту по кнопке', (tester) async {
      await pumpPage(tester);

      await tester.enterText(find.byType(TextField), '5000');
      await tester.pump();
      expect(find.text('Вернуть расчёт'), findsOneWidget);

      await tester.tap(find.text('Вернуть расчёт'));
      await tester.pump();

      expect(amountText(tester), '$price');
      // Сумма снова совпала с расчётом — возвращать больше нечего.
      expect(find.text('Вернуть расчёт'), findsNothing);

      // И снова идёт за количеством.
      await addCapsule(tester);
      expect(amountText(tester), '${price * 2}');
    });

    testWidgets('ранее проведённая сумма расчётом не перебивается',
        (tester) async {
      // Точку уже завершали: пришли свои капсулы и своя сумма.
      await pumpPage(tester, stop: _stop(capsules: 4, amount: 55000));

      expect(amountText(tester), '55000');

      await addCapsule(tester);
      expect(amountText(tester), '55000');
    });
  });
}

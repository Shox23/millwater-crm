import 'dart:async';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/core/product_config.dart';
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
    required PaymentMethod method,
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
      method: method,
      photoPath: photoPath,
      idempotencyKey: idempotencyKey,
    );
  }
}

/// Отдаёт цену тогда, когда её отдадут, — как медленная сеть.
///
/// Нужен, чтобы проверить сам момент подмены: до ответа сервера экран считает
/// по значению сборки, после — по прайсу.
class _DeferredCapsulePrice implements CapsulePrice {
  final _completer = Completer<int>();

  void send(int price) => _completer.complete(price);

  @override
  Future<int> value() => _completer.future;
}

void main() {
  final price = ProductConfig.capsulePrice;

  Future<_RecordingDriverRepository> pumpPage(
    WidgetTester tester, {
    RouteStop? stop,
    CapsulePrice? price,
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
          home: DeliveryCompletionPage(
            stop: stop ?? _stop(),
            price: price ?? const BuildCapsulePrice(),
          ),
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
  ///
  /// Экран в тестовое окно целиком не помещается, а часть проверок его
  /// прокручивает — поэтому перед нажатием подводим счётчик к видимой области.
  Future<void> addCapsule(WidgetTester tester) async {
    final plus = find.byIcon(Icons.add).first;
    await tester.ensureVisible(plus);
    await tester.pump();
    await tester.tap(plus);
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

      // Экран стал выше из-за предупреждения об остатке — ссылка теперь за
      // краем, и без прокрутки тап по ней промахивается.
      await tester.ensureVisible(find.text('Вернуть расчёт'));
      await tester.pump();
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

  group('Пустая сумма', () {
    /// Кнопка «Завершить» — единственная в нижней панели.
    bool submitEnabled(WidgetTester tester) =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Завершить'))
            .enabled;

    testWidgets('стёртое поле не даёт завершить доставку', (tester) async {
      await pumpPage(tester);
      expect(submitEnabled(tester), isTrue);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      // Раньше пустое поле читалось как ноль и уходило на сервер как
      // «оплачено 0» — неотличимо от осознанной оплаты в долг.
      expect(submitEnabled(tester), isFalse);
      expect(find.textContaining('Укажите сумму'), findsOneWidget);
    });

    testWidgets('явный ноль остаётся законным — это оплата в долг',
        (tester) async {
      final repo = await pumpPage(tester);

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();

      expect(submitEnabled(tester), isTrue);
      await tester.tap(find.text('Завершить'));
      await tester.pumpAndSettle();

      expect(repo.amount, 0);
    });

    testWidgets('после возврата текста кнопка снова доступна', (tester) async {
      await pumpPage(tester);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(submitEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), '5000');
      await tester.pump();
      expect(submitEnabled(tester), isTrue);
      expect(find.textContaining('Укажите сумму'), findsNothing);
    });
  });

  group('Остаток капсул у клиента', () {
    testWidgets('пока счётчик не трогали — предупреждает о перезаписи',
        (tester) async {
      await pumpPage(tester);

      // Значение подставлено само и уйдёт на сервер как новый остаток.
      expect(find.textContaining('заменит прежний остаток'), findsOneWidget);
    });

    testWidgets('правка счётчика убирает предупреждение', (tester) async {
      await pumpPage(tester);

      // Второй «плюс» на экране — у остатка клиента.
      await tester.tap(find.byIcon(Icons.add).at(1));
      await tester.pump();

      expect(find.textContaining('заменит прежний остаток'), findsNothing);
    });

    testWidgets('смена количества предупреждение не снимает', (tester) async {
      await pumpPage(tester);

      // Остаток тянется за количеством, но подтверждением это не считается.
      await addCapsule(tester);

      expect(find.textContaining('заменит прежний остаток'), findsOneWidget);
    });
  });

  group('Живая цена с сервера', () {
    /// Отдаёт цену и даёт экрану перестроиться.
    Future<void> sendPrice(
      WidgetTester tester,
      _DeferredCapsulePrice source,
      int value,
    ) async {
      source.send(value);
      await tester.pump();
    }

    testWidgets('прайс сервера заменяет значение сборки', (tester) async {
      final source = _DeferredCapsulePrice();
      await pumpPage(tester, price: source);

      // Экран открылся раньше ответа: ждать сеть у двери заказчика нечего.
      expect(amountText(tester), '$price');

      await sendPrice(tester, source, 25000);

      expect(amountText(tester), '25000');
      expect(find.textContaining('По прайсу: 1 ×'), findsOneWidget);
    });

    testWidgets('дальше сумма идёт за количеством по живой цене',
        (tester) async {
      final source = _DeferredCapsulePrice();
      await pumpPage(tester, price: source);
      await sendPrice(tester, source, 25000);

      await addCapsule(tester);

      expect(amountText(tester), '50000');
    });

    testWidgets('введённую вручную сумму не перебивает', (tester) async {
      final source = _DeferredCapsulePrice();
      await pumpPage(tester, price: source);

      await tester.enterText(find.byType(TextField), '5000');
      await tester.pump();
      await sendPrice(tester, source, 25000);

      // Частичная оплата остаётся цифрой водителя: ответ сервера не должен
      // менять её за его спиной — деньги он уже принял.
      expect(amountText(tester), '5000');
    });

    testWidgets('ранее проведённую сумму не перебивает', (tester) async {
      final source = _DeferredCapsulePrice();
      await pumpPage(
        tester,
        stop: _stop(capsules: 4, amount: 55000),
        price: source,
      );

      await sendPrice(tester, source, 25000);

      expect(amountText(tester), '55000');
    });
  });
}

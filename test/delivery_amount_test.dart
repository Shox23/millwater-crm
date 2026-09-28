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

RouteStop _stop({int? capsules, int? amount, int? balance}) => RouteStop(
      id: 'stop-1',
      customerId: 'c-1',
      customerName: 'Заказчик',
      customerAddress: 'Ташкент, Чиланзар 12',
      customerPhone: '+998901234567',
      status: DeliveryStatus.pending,
      deliveredCapsules: capsules,
      paymentAmount: amount,
      customerBottleBalance: balance,
    );

/// Запоминает сумму, дошедшую до репозитория.
class _RecordingDriverRepository extends MockDriverRepository {
  int? amount;

  @override
  Future<void> completeDelivery({
    required String stopId,
    required OrderPurpose purpose,
    required int amount,
    required PaymentMethod method,
    int capsules = 0,
    int returnedCapsules = 0,
    int returnedFullCapsules = 0,
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
    this.amount = amount;
    return super.completeDelivery(
      stopId: stopId,
      purpose: purpose,
      capsules: capsules,
      returnedCapsules: returnedCapsules,
      damagedCapsules: damagedCapsules,
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

  /// Подводит элемент в зону видимости и нажимает.
  ///
  /// Экран завершения вырос: у доставки теперь ещё возврат и брак, и способ
  /// оплаты уехал за нижний край тестового окна — прямой `tap` промахивался.
  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pump();
  }

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
      await tapVisible(tester, find.text('Завершить'));
      await tester.pumpAndSettle();

      expect(repo.amount, price * 2);
    });
  });

  group('Оплата в долг', () {
    // Правило серверное: при `payment_method = debt` он требует ровно ноль и
    // иначе отвечает 422 с английским текстом, который до водителя не
    // доходит. Раньше клиент подставлял «капсулы × цена» при любом способе и
    // упирался в этот отказ на каждой доставке в долг.
    testWidgets('обнуляет сумму и показывает начисление', (tester) async {
      await pumpPage(tester);
      await addCapsule(tester);
      expect(amountText(tester), '${price * 2}');

      await tapVisible(tester, find.text('В долг'));
      await tester.pump();

      expect(amountText(tester), '0');
      // Ноль в поле — это не «привезли бесплатно»: стоимость целиком уходит
      // заказчику, и водитель должен видеть, сколько именно ему записали.
      expect(find.text('Уйдёт в долг'), findsOneWidget);
    });

    testWidgets('на сервер уходит ровно ноль', (tester) async {
      final repo = await pumpPage(tester);

      await tapVisible(tester, find.text('В долг'));
      await tester.pump();
      await tapVisible(tester, find.text('Завершить'));
      await tester.pumpAndSettle();

      expect(repo.amount, 0);
      expect(repo.lastMethod, PaymentMethod.debt);
    });

    testWidgets('смена счётчика после выбора долга держит ноль', (tester) async {
      // Поле в долг `readOnly`: переписанную расчётом сумму водителю было бы
      // нечем вернуть, и каждая смена количества заканчивалась 422.
      final repo = await pumpPage(tester);

      await tapVisible(tester, find.text('В долг'));
      await tester.pump();
      await addCapsule(tester);

      expect(amountText(tester), '0');
      expect(find.text('Уйдёт в долг'), findsOneWidget);

      await tapVisible(tester, find.text('Завершить'));
      await tester.pumpAndSettle();
      expect(repo.amount, 0);
      expect(repo.lastMethod, PaymentMethod.debt);
    });

    testWidgets('возврат к наличным восстанавливает расчёт', (tester) async {
      await pumpPage(tester);
      await addCapsule(tester);

      await tapVisible(tester, find.text('В долг'));
      await tester.pump();
      expect(amountText(tester), '0');

      await tapVisible(tester, find.text('Наличные'));
      await tester.pump();

      expect(amountText(tester), '${price * 2}');
      expect(find.text('Уйдёт в долг'), findsNothing);
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
      await tapVisible(tester, find.text('Вернуть расчёт'));
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

    testWidgets('явный ноль законен только как оплата в долг',
        (tester) async {
      final repo = await pumpPage(tester);

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();

      // Ноль наличными сервер отвергает: «payment_amount must be greater
      // than 0 for payment_method CASH». Ловим до отправки — иначе водитель
      // видит общее «Не удалось» и не понимает, что делать.
      expect(submitEnabled(tester), isFalse);
      expect(find.textContaining('только со способом'), findsOneWidget);

      await tapVisible(tester, find.text('В долг'));

      expect(submitEnabled(tester), isTrue);
      await tapVisible(tester, find.text('Завершить'));
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
    testWidgets('складывается из прежнего остатка и привезённых',
        (tester) async {
      await pumpPage(tester, stop: _stop(balance: 3));

      expect(find.text('было 3 + привезено 1'), findsOneWidget);

      await addCapsule(tester);
      expect(find.text('было 3 + привезено 2'), findsOneWidget);
    });

    testWidgets('на сервер уходит сумма прежнего остатка и привезённых',
        (tester) async {
      // Сервер этим числом ЗАМЕНЯЕТ склад клиента, так что уйти обязано
      // именно 3 + 2, а не одни привезённые.
      final repo = await pumpPage(tester, stop: _stop(balance: 3));

      await addCapsule(tester);
      await tapVisible(tester, find.text('Завершить'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.lastBottleBalance, 5);
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

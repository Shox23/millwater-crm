import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/core/widgets/photo_attach_tile.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/orders/presentation/order_payment_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Экран правки оплаты закрытого заказа.
///
/// Главное здесь — контракт ручки: `amount` это **вся сумма заказа**, а не
/// доплата, разницу сервер считает сам. Экран, который отправит доплату,
/// испортит заказчику баланс молча — 204 без тела сервер вернёт и на неё.
///
/// Остальное — то, чем экран удерживает человека от бессмысленного запроса:
/// кнопка молчит, пока цифры те же, а снимок спрашивается только там, где
/// сервер его ждёт.
class _PaymentRepository extends MockCrmRepository {
  _PaymentRepository({this.failure});

  /// Чем ответить на правку; `null` — принять.
  final Object? failure;

  /// Что ушло на сервер: суммы и способы, по порядку.
  final amounts = <int>[];
  final methods = <PaymentMethod>[];
  final photos = <String?>[];

  @override
  Future<void> updateOrderPayment({
    required String orderId,
    required int amount,
    required PaymentMethod method,
    String? note,
    String? photoPath,
  }) async {
    if (failure != null) throw failure!;
    amounts.add(amount);
    methods.add(method);
    photos.add(photoPath);
  }
}

void main() {
  late _PaymentRepository repo;

  setUp(() => repo = _PaymentRepository());

  /// Отказ сервера конвертом бизнес-ошибки — так приходит ORDER_NOT_COMPLETED.
  DioException failure(String code, {int status = 409}) {
    final options = RequestOptions(path: '/admin/orders/o-1/payment');
    return DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: status,
        data: {
          'success': false,
          'error': {'code': code, 'message': 'rejected'},
        },
      ),
    );
  }

  /// Закрытый заказ на 100 000 наличными — исходное состояние экрана.
  ///
  /// Заказчик берётся из мок-стора, чтобы экран нашёл его по `customerId` и
  /// показал блок с балансом: без заказчика половина экрана не строится.
  Order order(MockCrmRepository source) => Order(
        id: 'o-1',
        number: 41,
        status: DeliveryStatus.delivered,
        purpose: OrderPurpose.delivery19l,
        paymentMethod: PaymentMethod.cash,
        orderAmount: 100000,
        createdAt: DateTime(2026, 9, 1),
        customerId: source.store.customers.first.id,
        customerName: source.store.customers.first.name,
      );

  void useLargeSurface(WidgetTester tester) {
    // В тестах вместо Inter подставляется шрифт тестового рендерера с более
    // широкими глифами — на узком экране подписи в него не влезают.
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Прокачивает кадры вместо `pumpAndSettle`: мигающий курсор в поле суммы
  /// не даёт экрану остановиться никогда.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpPayment(WidgetTester tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      RepositoryProvider<CrmRepository>.value(
        value: repo,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: OrderPaymentPage(order: order(repo)),
        ),
      ),
    );
    // Экран спрашивает заказчика ради баланса — даём моку ответить.
    await settle(tester);
  }

  Finder inputFor(String label) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Column))
            .first,
        matching: find.byType(TextField),
      );

  Future<void> enterAmount(WidgetTester tester, String amount) async {
    await tester.enterText(inputFor('Итоговая сумма заказа'), amount);
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text).first;
    await tester.ensureVisible(target);
    await settle(tester);
    await tester.tap(target);
    await settle(tester);
  }

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, 'Сохранить'))
          .enabled;

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(AppButton, 'Сохранить'));
    await settle(tester);
  }

  testWidgets('«Было → станет» появляется только при изменении суммы',
      (tester) async {
    await pumpPayment(tester);
    expect(find.textContaining('Было'), findsNothing);

    await enterAmount(tester, '150000');

    // Правка суммы должна читаться как правка, а не как ввод с нуля.
    expect(find.textContaining('Было'), findsOneWidget);
    // По стрелке, а не по слову «станет»: его содержит и подсказка под
    // комментарием («останется в истории платежей»).
    expect(find.textContaining('→'), findsOneWidget);

    await enterAmount(tester, '100000');
    expect(find.textContaining('Было'), findsNothing);
  });

  testWidgets('подсказка про «всю сумму» дочитывается до конца',
      (tester) async {
    await pumpPayment(tester);

    // На боевом стенде в одну строку фраза обрывалась на «разницу сервер …»
    // — ровно на том месте, ради которого написана: без неё экран читается
    // как «введите доплату», а сервер ждёт полную сумму заказа.
    final amount = tester.widget<TextField>(find.byType(TextField).first);
    expect(amount.decoration?.helperMaxLines, 2);
  });

  testWidgets('кнопка молчит, пока цифры те же', (tester) async {
    await pumpPayment(tester);
    expect(saveEnabled(tester), isFalse);

    await enterAmount(tester, '150000');
    expect(saveEnabled(tester), isTrue);

    // Возврат прежней суммы — снова нечего сохранять: сервер записал бы
    // нулевую дельту отдельной строкой в историю платежей.
    await enterAmount(tester, '100000');
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('смена способа оплаты — тоже изменение', (tester) async {
    await pumpPayment(tester);

    await tapText(tester, 'Перечисление');

    // Сумма та же, но способ другой: сервер перепишет способ платежа.
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('фото спрашивается только при оплате картой', (tester) async {
    await pumpPayment(tester);
    expect(find.byType(PhotoAttachTile), findsNothing);

    await tapText(tester, 'Карта');
    expect(find.byType(PhotoAttachTile), findsOneWidget);

    // Уход с карты убирает снимок вместе с полем: иначе он ушёл бы
    // приложенным к оплате, которая его не предполагает.
    await tapText(tester, 'Наличные');
    expect(find.byType(PhotoAttachTile), findsNothing);
  });

  testWidgets('на сервер уходит вся сумма заказа, а не доплата',
      (tester) async {
    await pumpPayment(tester);

    await enterAmount(tester, '150000');
    await tapSave(tester);

    // 150 000, а не 50 000: разницу с уже принятыми деньгами считает сервер.
    expect(repo.amounts, [150000]);
    expect(repo.methods, [PaymentMethod.cash]);
    expect(repo.photos, [null]);
  });

  testWidgets('отказ сервера показывается текстом, экран не закрывается',
      (tester) async {
    repo = _PaymentRepository(failure: failure('ORDER_NOT_COMPLETED'));
    await pumpPayment(tester);

    await enterAmount(tester, '150000');
    await tapSave(tester);

    expect(find.text('Заказ ещё не закрыт'), findsOneWidget);
    expect(find.text('Изменение оплаты'), findsOneWidget);
  });

  testWidgets('уход с тронутой формы переспрашивает', (tester) async {
    await pumpPayment(tester);
    await enterAmount(tester, '30000');

    // Свайп «назад» на iOS доходит до PopScope тем же путём, что и кнопка.
    final popped = await tester.binding.handlePopRoute();
    await settle(tester);

    expect(popped, isTrue);
    expect(find.text('Выйти без сохранения?'), findsOneWidget);
    // Экран не закрылся, пока не ответили.
    expect(find.text('Изменение оплаты'), findsOneWidget);
  });

  testWidgets('нетронутую форму отпускает без вопросов', (tester) async {
    await pumpPayment(tester);

    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.text('Выйти без сохранения?'), findsNothing);
  });
}

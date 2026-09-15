import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/orders/presentation/cancel_order_page.dart';
import 'package:crm_millwater/features/orders/presentation/order_detail_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Отмена заказа из админской карточки.
///
/// Кнопка живёт только у незакрытого заказа — у закрытого сервер ответит 409,
/// и упираться в него после написанной причины не дело. Сама форма общая с
/// водителем, поэтому проверяется здесь один раз: причина уходит обрезанной,
/// пустая — как отсутствие, отказ сервера показывается текстом и экран не
/// закрывается.
class _CancelRepository extends MockCrmRepository {
  _CancelRepository({this.failure});

  /// Чем ответить на отмену; `null` — принять.
  final Object? failure;

  /// Что ушло на сервер: id и причины, по порядку.
  final cancelled = <(String, String?)>[];

  @override
  Future<void> cancelOrder({required String orderId, String? reason}) async {
    if (failure != null) throw failure!;
    cancelled.add((orderId, reason));
  }
}

void main() {
  late _CancelRepository repo;

  setUp(() => repo = _CancelRepository());

  DioException failure(String code, {int status = 409}) {
    final options = RequestOptions(path: '/admin/orders/o-1/cancel');
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

  Order order({
    DeliveryStatus status = DeliveryStatus.pending,
    String? cancelReason,
    DateTime? cancelledAt,
    int? returnedFull,
  }) =>
      Order(
        id: 'o-1',
        number: 41,
        status: status,
        purpose: OrderPurpose.delivery19l,
        deliveredCapsules: status == DeliveryStatus.delivered ? 3 : null,
        returnedFullCapsules: returnedFull,
        cancelReason: cancelReason,
        cancelledAt: cancelledAt,
        createdAt: DateTime(2026, 9, 1),
        customerId: 'c-1',
        customerName: 'Кафе «Nasiba»',
      );

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Прокачивает кадры вместо `pumpAndSettle`: курсор в поле причины не даёт
  /// экрану остановиться никогда.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// [withCancel] — вызывающий экран передал карточке отмену. Без неё
  /// кнопки нет: карточка сама репозиториев не знает.
  Future<void> pumpDetail(
    WidgetTester tester,
    Order target, {
    bool canManage = true,
    bool withCancel = true,
  }) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      RepositoryProvider<CrmRepository>.value(
        value: repo,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocales.supported,
          locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: OrderDetailPage(
            order: target,
            canManage: canManage,
            onCancel: withCancel
                ? (reason) =>
                    repo.cancelOrder(orderId: target.id, reason: reason)
                : null,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> openCancel(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(AppButton, 'Отменить'));
    await settle(tester);
    expect(find.byType(CancelOrderPage), findsOneWidget);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(AppButton, 'Отменить заказ'));
    await settle(tester);
    await settle(tester);
    // Снек-бар успеха живёт 4 секунды — без этого тест падает на таймере.
    await tester.pump(const Duration(seconds: 5));
  }

  group('Кнопка отмены', () {
    testWidgets('есть у нового и у заказа в пути', (tester) async {
      await pumpDetail(tester, order());
      expect(find.widgetWithText(AppButton, 'Отменить'), findsOneWidget);

      await pumpDetail(tester, order(status: DeliveryStatus.onWay));
      expect(find.widgetWithText(AppButton, 'Отменить'), findsOneWidget);
    });

    testWidgets('нет у закрытого, не доставленного и уже отменённого',
        (tester) async {
      for (final status in [
        DeliveryStatus.delivered,
        DeliveryStatus.failed,
        DeliveryStatus.cancelled,
      ]) {
        await pumpDetail(tester, order(status: status));
        expect(find.widgetWithText(AppButton, 'Отменить'), findsNothing,
            reason: '$status');
      }
    });

    testWidgets('есть и без прав админа — водитель отменяет свой заказ',
        (tester) async {
      await pumpDetail(tester, order(), canManage: false);
      expect(find.widgetWithText(AppButton, 'Отменить'), findsOneWidget);
      // Админские действия при этом не появляются.
      expect(find.widgetWithText(AppButton, 'Перенести'), findsNothing);
    });

    testWidgets('нет, если вызывающий экран отмену не передал',
        (tester) async {
      await pumpDetail(tester, order(), withCancel: false);
      expect(find.widgetWithText(AppButton, 'Отменить'), findsNothing);
    });
  });

  group('Форма отмены', () {
    testWidgets('причина уходит обрезанной, экран закрывается',
        (tester) async {
      await pumpDetail(tester, order());
      await openCancel(tester);

      expect(find.text('Кафе «Nasiba»'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Не открыл дверь  ');
      await submit(tester);

      expect(repo.cancelled, [('o-1', 'Не открыл дверь')]);
      expect(find.byType(CancelOrderPage), findsNothing);
    });

    testWidgets('без причины отправляется как отсутствие причины',
        (tester) async {
      await pumpDetail(tester, order());
      await openCancel(tester);
      await submit(tester);

      expect(repo.cancelled, [('o-1', null)]);
    });

    testWidgets('отказ сервера показывается текстом, экран не закрывается',
        (tester) async {
      repo = _CancelRepository(failure: failure('ORDER_ALREADY_COMPLETED'));
      await pumpDetail(tester, order());
      await openCancel(tester);
      await submit(tester);

      expect(find.text('Заказ уже закрыт'), findsOneWidget);
      expect(find.byType(CancelOrderPage), findsOneWidget);
      // Кнопка ожила: серая кнопка без объяснения — тупик.
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Отменить заказ'))
            .enabled,
        isTrue,
      );
    });
  });

  group('Отменённый заказ в карточке', () {
    testWidgets('показывает причину и время', (tester) async {
      await pumpDetail(
        tester,
        order(
          status: DeliveryStatus.cancelled,
          cancelReason: 'Переехал',
          cancelledAt: DateTime(2026, 9, 14, 10, 15),
        ),
      );

      expect(find.text('ОТМЕНА'), findsOneWidget);
      expect(find.text('Переехал'), findsOneWidget);
      expect(find.text('14.09.2026 10:15'), findsOneWidget);
      // Статус — отдельный, не «Не доставлено».
      expect(find.text('Отменён'), findsWidgets);
      expect(find.text('Не доставлено'), findsNothing);
    });

    testWidgets('без причины так и говорит', (tester) async {
      await pumpDetail(tester, order(status: DeliveryStatus.cancelled));

      expect(find.text('ОТМЕНА'), findsOneWidget);
      expect(find.text('Причина не указана'), findsOneWidget);
    });

    testWidgets('у обычного заказа блока отмены нет', (tester) async {
      await pumpDetail(tester, order(status: DeliveryStatus.delivered));
      expect(find.text('ОТМЕНА'), findsNothing);
    });
  });

  group('Возврат с водой в составе', () {
    testWidgets('показывается строкой у доставки', (tester) async {
      await pumpDetail(
        tester,
        order(status: DeliveryStatus.delivered, returnedFull: 2),
      );
      expect(find.text('Возвращено с водой'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('без поля с сервера строки нет', (tester) async {
      await pumpDetail(tester, order(status: DeliveryStatus.delivered));
      expect(find.text('Возвращено с водой'), findsNothing);
    });
  });
}

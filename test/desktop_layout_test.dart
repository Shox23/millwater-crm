import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/app.dart';
import 'package:crm_millwater/app/settings/settings_storage.dart';
import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/app/theme/theme_cubit.dart';
import 'package:crm_millwater/core/export/file_sharer.dart';
import 'package:crm_millwater/core/utils/day.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/core/utils/money_formatter.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/models/user_role.dart';
import 'package:crm_millwater/data/network/session_storage.dart';
import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:crm_millwater/features/desktop/overlays/drawer_contents.dart';
import 'package:crm_millwater/features/desktop/overlays/entity_form_modal.dart';
import 'package:crm_millwater/features/desktop/presentation/desktop_header.dart';
import 'package:crm_millwater/features/desktop/presentation/desktop_section.dart';
import 'package:crm_millwater/features/desktop/presentation/desktop_shell.dart';
import 'package:crm_millwater/features/desktop/presentation/pages/cash_desktop_page.dart';
import 'package:crm_millwater/features/desktop/presentation/pages/orders_desktop_page.dart';
import 'package:crm_millwater/features/desktop/presentation/pages/prices_desktop_page.dart';
import 'package:crm_millwater/features/desktop/widgets/desktop_table.dart';
import 'package:crm_millwater/features/orders/presentation/cancel_order_page.dart';
import 'package:crm_millwater/features/reports/presentation/report_export_page.dart';
import 'package:crm_millwater/features/routes/presentation/route_form_page.dart';
import 'package:crm_millwater/features/settings/presentation/settings_page.dart';
import 'package:crm_millwater/features/auth/presentation/login_page.dart';
import 'package:crm_millwater/features/desktop/presentation/driver_desktop_stub.dart';
import 'package:crm_millwater/features/desktop/widgets/desktop_button.dart';
import 'package:crm_millwater/features/driver/presentation/driver_shell.dart';
import 'package:crm_millwater/features/home/presentation/admin_shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// Запоминает, что форма отправила в репозиторий.
class _RecordingRepository extends MockCrmRepository {
  int? addedCoolerCount;
  Customer? updatedCustomer;
  String? deletedRouteId;

  @override
  Future<void> deleteRoute(String id) {
    deletedRouteId = id;
    return super.deleteRoute(id);
  }

  @override
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    String? phoneSecondary,
    required String address,
    String? comment,
    int coolerCount = 0,
    int capsuleBalance = 0,
    int debt = 0,
    int prepayment = 0,
    int? customWaterPrice,
    DateTime? lastOrderDate,
    String? idempotencyKey,
  }) {
    addedCoolerCount = coolerCount;
    return super.addCustomer(
      name: name,
      phone: phone,
      phoneSecondary: phoneSecondary,
      address: address,
      comment: comment,
      coolerCount: coolerCount,
      capsuleBalance: capsuleBalance,
      debt: debt,
      prepayment: prepayment,
      customWaterPrice: customWaterPrice,
      lastOrderDate: lastOrderDate,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<Customer> updateCustomer(
    Customer customer, {
    bool balanceChanged = false,
    bool capsulesChanged = false,
    bool lastOrderDateChanged = false,
  }) {
    updatedCustomer = customer;
    return super.updateCustomer(
      customer,
      balanceChanged: balanceChanged,
      capsulesChanged: capsulesChanged,
      lastOrderDateChanged: lastOrderDateChanged,
    );
  }
}

/// Отвечает на любой запрос пустой страницей — экраны должны собраться.
///
/// Роль отдаёт та, что запросили: приложение доверяет ответу `/auth/me`
/// больше, чем записи на диске, и сервер, всегда отвечающий «админ»,
/// проверял бы совсем не то.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.role);

  final UserRole role;
  final List<String> requestedPaths = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    final body = switch (options.path) {
      '/auth/me' => {
          'id': 'u1',
          'phone': '+998901234567',
          'role': role.wire,
        },
      final p when p.startsWith('/driver/') => <Object>[],
      _ => const {'items': <Object>[], 'total': 0},
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  InMemorySessionStorage storedSession(UserRole role) =>
      InMemorySessionStorage({
        'access_token': 'stored-access',
        'refresh_token': 'stored-refresh',
        'role': role.wire,
      });

  /// Базовый размер макета: 16" ноутбук, 1728×1117 при масштабе 1.
  void useDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1728, 1117);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpApp(WidgetTester tester, UserRole role) async {
    await tester.pumpWidget(CrmApp(
      sessionStorage: storedSession(role),
      dio: Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _FakeAdapter(role),
    ));
    // Восстановление сессии, затем стартовые запросы разделов. Каждый запрос
    // оставляет свой таймер — их надо догнать, иначе тест падает на
    // «A Timer is still pending».
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  group('Выбор компоновки', () {
    testWidgets('широкое окно админа открывает десктопную оболочку',
        (tester) async {
      useDesktopSurface(tester);
      await pumpApp(tester, UserRole.admin);

      expect(find.byType(DesktopShell), findsOneWidget);
      expect(find.byType(AdminShell), findsNothing);
    });

    testWidgets('узкое окно оставляет мобильную оболочку', (tester) async {
      // То же приложение в сузившемся окне: таблицы в 360px не читаются,
      // поэтому работает мобильная компоновка.
      usePhoneSurface(tester);
      await pumpApp(tester, UserRole.admin);

      expect(find.byType(AdminShell), findsOneWidget);
      expect(find.byType(DesktopShell), findsNothing);
    });

    testWidgets('водителю на широком экране показывается заглушка',
        (tester) async {
      useDesktopSurface(tester);
      await pumpApp(tester, UserRole.driver);

      expect(find.byType(DriverDesktopStub), findsOneWidget);
      expect(find.byType(DriverShell), findsNothing);
    });

    testWidgets('водителю на телефоне десктоп не подсовывается',
        (tester) async {
      usePhoneSurface(tester);
      await pumpApp(tester, UserRole.driver);

      expect(find.byType(DriverShell), findsOneWidget);
      expect(find.byType(DriverDesktopStub), findsNothing);
    });
  });

  group('Десктопная оболочка', () {
    testWidgets('пункт меню переключает раздел', (tester) async {
      useDesktopSurface(tester);
      await pumpApp(tester, UserRole.admin);

      DesktopSection currentSection() =>
          tester.widget<DesktopHeader>(find.byType(DesktopHeader)).section;

      expect(currentSection(), DesktopSection.routes);

      // Пока раздел «Маршруты», подпись «Заказчики» есть только в меню.
      await tester.tap(find.text('Заказчики'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(currentSection(), DesktopSection.customers);
    });

    testWidgets('поиск виден в списках и скрыт в отчётах', (tester) async {
      useDesktopSurface(tester);
      await pumpApp(tester, UserRole.admin);

      expect(find.text('Поиск'), findsOneWidget);

      await tester.tap(find.text('Отчёты'));
      await tester.pump();
      // График недели поднимает семь запросов сводки разом — каждый оставляет
      // свой таймер, и их надо догнать, иначе тест падает на «A Timer is
      // still pending».
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      // В отчётах искать нечего — там сводные числа.
      expect(find.text('Поиск'), findsNothing);
    });

    testWidgets('карточка пользователя открывает настройки без пункта «Цены»',
        (tester) async {
      useDesktopSurface(tester);
      await pumpApp(tester, UserRole.admin);

      // Раньше карточка была декоративной, и выйти из аккаунта на десктопе
      // было негде.
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Выйти из аккаунта'), findsOneWidget);
      // Прайс — раздел в боковой панели, в шторке его нет.
      expect(find.text('ПРАЙС'), findsNothing);
    });

    testWidgets('выход из настроек возвращает на экран входа', (tester) async {
      useDesktopSurface(tester);
      await pumpApp(tester, UserRole.admin);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.tap(find.text('Выйти из аккаунта'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Выйти из аккаунта?'), findsOneWidget);

      await tester.tap(find.text('Выйти').last);
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(DesktopShell), findsNothing);
    });
  });

  group('Раздел «Маршруты»', () {
    late _RecordingRepository repo;

    setUp(() => repo = _RecordingRepository());

    /// Оболочка поверх мока — без сети и без разбора сессии.
    Future<void> pumpShell(WidgetTester tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CrmRepository>.value(value: repo),
            // Оболочка передаёт источник цены блоку дня — в дереве приложения
            // его кладёт `app.dart`. Здесь берём цену из сборки: сети нет.
            RepositoryProvider<CapsulePrice>.value(
              value: const BuildCapsulePrice(),
            ),
          ],
          child: BlocProvider(
            create: (_) => ThemeCubit(storage: InMemorySettingsStorage()),
            child: MaterialApp(
              // Без темы приложения нет ThemeExtension с токенами.
              theme: AppTheme.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocales.supported,
              home: const DesktopShell(),
            ),
          ),
        ),
      );
      // Блок дня ходит в сеть дважды подряд: список дня, потом точки каждого
      // маршрута. Один длинный pump эту цепочку не раскрутит.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    /// Строк в таблице: у каждой свой шеврон справа.
    int visibleRows() =>
        find.byIcon(Icons.chevron_right_rounded).evaluate().length;

    /// Точки сегодняшних маршрутов — фикстуру берём из стора синхронно.
    List<RouteStop> todayStops() {
      final today = dayOnly(DateTime.now());
      return repo.store.routes
          .where((r) => dayOnly(r.date) == today)
          .expand((r) => r.stops)
          .toList();
    }

    testWidgets('таблица показывает точки маршрутов, а не сами маршруты',
        (tester) async {
      await pumpShell(tester);

      final stops = todayStops();
      // Строк ровно столько, сколько доставок, — маршрутов меньше.
      expect(stops.length, greaterThan(repo.store.routes.length));
      expect(visibleRows(), stops.length);
    });

    testWidgets('фильтр оставляет только доставленные', (tester) async {
      await pumpShell(tester);

      final delivered =
          todayStops().where((s) => s.status == DeliveryStatus.delivered).length;
      expect(delivered, greaterThan(0));

      await tester.tap(find.text('Доставлены'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(visibleRows(), delivered);
    });

    testWidgets('поиск в шапке сужает таблицу до одного заказчика',
        (tester) async {
      await pumpShell(tester);
      final all = visibleRows();

      final name = todayStops().first.customerName;
      await tester.enterText(find.byType(TextField), name);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final found = visibleRows();
      expect(found, greaterThan(0));
      expect(found, lessThan(all));
    });

    testWidgets('клик по строке открывает карточку доставки', (tester) async {
      await pumpShell(tester);

      final name = todayStops().first.customerName;
      await tester.tap(find.text(name).first);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(find.byType(DeliveryDrawer), findsOneWidget);
      // Удаление маршрута доступно всегда — в отличие от завершения доставки,
      // которое остаётся за водителем и на этом экране не показывается кнопкой.
      expect(
        find.widgetWithText(DesktopButton, 'Удалить маршрут'),
        findsOneWidget,
      );
    });

    testWidgets('удаление маршрута спрашивает подтверждение и чистит день',
        (tester) async {
      await pumpShell(tester);
      final before = visibleRows();

      final name = todayStops().first.customerName;
      await tester.tap(find.text(name).first);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      await tester.tap(find.widgetWithText(DesktopButton, 'Удалить маршрут'));
      await tester.pump();

      // Подтверждение — без него уйти можно, отменив диалог.
      expect(find.text('Удалить маршрут?'), findsOneWidget);
      await tester.tap(find.widgetWithText(DesktopButton, 'Удалить'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      // Успех подтверждается тостом — он живёт несколько секунд, и его нужно
      // догнать, иначе тест падает на «A Timer is still pending».
      await tester.pump(const Duration(seconds: 3));

      expect(repo.deletedRouteId, isNotNull);
      expect(find.byType(DeliveryDrawer), findsNothing);
      expect(visibleRows(), lessThan(before));
    });

    testWidgets('отмена доставки из карточки — с причиной, точка гаснет',
        (tester) async {
      await pumpShell(tester);

      // Открытая точка: у закрытой кнопки отмены нет — сервер ответит 409.
      final stop = todayStops().firstWhere((s) => s.status.isOpen);
      await tester.tap(find.text(stop.customerName).first);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byType(DeliveryDrawer), findsOneWidget);

      await tester.tap(find.widgetWithText(DesktopButton, 'Отменить заказ'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byType(CancelOrderPage), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Просили перенести');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Отменить заказ'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pump(const Duration(seconds: 3));

      final cancelled = repo.store.routes
          .expand((r) => r.stops)
          .firstWhere((s) => s.id == stop.id);
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.cancelReason, 'Просили перенести');
      expect(find.byType(CancelOrderPage), findsNothing);
    });

    testWidgets('у закрытой доставки кнопки отмены нет', (tester) async {
      await pumpShell(tester);

      final stop = todayStops().firstWhere((s) => s.isCompleted);
      await tester.tap(find.text(stop.customerName).first);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(find.byType(DeliveryDrawer), findsOneWidget);
      expect(
        find.widgetWithText(DesktopButton, 'Отменить заказ'),
        findsNothing,
      );
    });

    testWidgets('переключение даты перестраивает день', (tester) async {
      await pumpShell(tester);
      expect(visibleRows(), greaterThan(0));

      // Послезавтра маршрутов в заготовке нет — день должен опустеть.
      final after = dayOnly(DateTime.now()).add(const Duration(days: 2));
      await tester.tap(find.text(DateFormat('dd.MM').format(after)));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(visibleRows(), 0);
      expect(find.text('На этот день доставок нет'), findsOneWidget);
    });

    testWidgets('карточка водителя открывается и предлагает правку',
        (tester) async {
      await pumpShell(tester);

      await tester.tap(find.text('Водители'));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      final driver = repo.store.drivers.first;
      await tester.tap(find.text(driver.fullName).first);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(find.byType(DriverDrawer), findsOneWidget);
    });

    testWidgets('отчёты показывают график недели и списки долгов',
        (tester) async {
      await pumpShell(tester);

      await tester.tap(find.text('Отчёты'));
      await tester.pump();
      // Семь запросов графика уходят параллельно, но мок отвечает не сразу.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.text('Выручка по дням'), findsOneWidget);
      expect(find.text('Долги заказчиков'), findsOneWidget);
      expect(find.text('Предоплаты'), findsOneWidget);
      // Период переключается — селектор не декоративный.
      expect(find.text('Неделя'), findsOneWidget);
    });

    /// Переходит в раздел и ждёт, пока он загрузится.
    Future<void> openSection(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    /// Дожидается, пока тост отживёт своё и снимет себя из оверлея.
    ///
    /// Он показывается 2.2 с и гаснет за 200 мс; не дождавшись, тест падает
    /// на «A Timer is still pending» уже после всех проверок.
    Future<void> settleToast(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// Поля формы заказчика по порядку: адрес, имя, телефон, комментарий.
    Finder customerField(int index) => find
        .descendant(
          of: find.byType(CustomerFormModal),
          matching: find.byType(TextField),
        )
        .at(index);

    testWidgets('новый заказчик уходит на сервер с выбранным кулером',
        (tester) async {
      await pumpShell(tester);
      await openSection(tester, 'Заказчики');

      await tester.tap(find.widgetWithText(DesktopButton, 'Заказчик'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byType(CustomerFormModal), findsOneWidget);

      await tester.enterText(customerField(0), 'Мирабад, 5');
      await tester.enterText(customerField(1), 'Кафе «Тест»');
      await tester.enterText(customerField(2), '+998 90 111 22 33');
      await tester.pump();

      // По умолчанию кулеров нет — добавляем один степпером. Переключатель
      // «есть/нет» заменён на количество: к кулеру ставят капсулу, и их у
      // заказчика может быть несколько.
      // Ищем внутри модалки: такой же плюс стоит в кнопке «+ Заказчик».
      // Степперов в форме два, кулеры — первый; второй считает капсулы на
      // руках у заказчика.
      final plus = find.descendant(
        of: find.byType(CustomerFormModal),
        matching: find.byIcon(Icons.add),
      );
      await tester.tap(plus.first);
      await tester.pump();

      // Заодно задаём тару, с которой заказчик приходит от прежнего
      // поставщика: без неё первая доставка разошлась бы со складом.
      await tester.tap(plus.at(1));
      await tester.pump();
      await tester.tap(plus.at(1));
      await tester.pump();

      await tester.tap(find.widgetWithText(DesktopButton, 'Сохранить'));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(repo.addedCoolerCount, 1);
      expect(repo.store.customers.last.hasCooler, isTrue);
      expect(repo.store.customers.last.capsuleBalance, 2);
      await settleToast(tester);
    });

    testWidgets('правка чужого поля не откатывает остаток капсул',
        (tester) async {
      // Остаток ведёт водитель: пока форма открыта, он может закрыть доставку
      // и изменить число. Правка имени не должна затирать его тем, что было
      // в форме при открытии.
      repo.store.customers[0] =
          repo.store.customers[0].copyWith(capsuleBalance: 5);

      await pumpShell(tester);
      await openSection(tester, 'Заказчики');

      await tester.tap(find.byTooltip('Редактировать').first);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      await tester.enterText(customerField(1), 'Кафе «Новое имя»');
      await tester.pump();

      // Водитель закрыл доставку, пока форма была открыта.
      repo.store.customers[0] =
          repo.store.customers[0].copyWith(capsuleBalance: 2);

      await tester.tap(find.widgetWithText(DesktopButton, 'Сохранить'));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(repo.store.customers[0].capsuleBalance, 2);
      await settleToast(tester);
    });

    testWidgets('правка заказчика снимает кулер и отправляет это на сервер',
        (tester) async {
      // Заготовка идёт без кулеров — ставим его первому заказчику, чтобы
      // проверять именно снятие. Стор правим синхронно, до pump.
      repo.store.customers[0] =
          repo.store.customers[0].copyWith(coolerCount: 1);

      await pumpShell(tester);
      await openSection(tester, 'Заказчики');

      final customer = repo.store.customers[0];
      await tester.tap(find.byTooltip('Редактировать').first);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byType(CustomerFormModal), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byType(CustomerFormModal),
        matching: find.byIcon(Icons.remove),
      ).first);
      await tester.pump();

      await tester.tap(find.widgetWithText(DesktopButton, 'Сохранить'));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(repo.updatedCustomer?.id, customer.id);
      expect(repo.updatedCustomer?.hasCooler, isFalse);
      expect(repo.store.customers[0].hasCooler, isFalse);
      await settleToast(tester);
    });

    testWidgets('форма водителя не сохраняет, пока не введено имя',
        (tester) async {
      await pumpShell(tester);

      await tester.tap(find.text('Водители'));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Кнопка «+ Водитель» в шапке.
      await tester.tap(find.widgetWithText(DesktopButton, 'Водитель'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byType(DriverFormModal), findsOneWidget);

      DesktopButton saveButton() => tester.widget<DesktopButton>(
            find.widgetWithText(DesktopButton, 'Сохранить'),
          );
      expect(saveButton().onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, 'Например, Азиз Каримов'),
        'Пётр Иванов',
      );
      await tester.pump();

      expect(saveButton().onPressed, isNotNull);
    });

    testWidgets('раздел «Заказы» показывает таблицу за всё время',
        (tester) async {
      await pumpShell(tester);
      await openSection(tester, 'Заказы');

      // Заказы приходят страницами — блок ходит в сеть после открытия.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(OrdersDesktopPage), findsOneWidget);
      // Таблица не пуста: в заготовке заказы есть, и за всё время, а не
      // только за сегодня — этим раздел и отличается от «Маршрутов».
      expect(find.byType(DesktopTable), findsOneWidget);
      expect(visibleRows(), greaterThan(0));
    });

    testWidgets('раздел «Касса» сводит расходы за период', (tester) async {
      await pumpShell(tester);
      await openSection(tester, 'Касса');

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(CashDesktopPage), findsOneWidget);
      // Категории показываются все четыре, включая нулевые: ноль по
      // «Ремонту» — тоже ответ на вопрос, на что ушли деньги.
      for (final label in ['Топливо', 'Обед', 'Ремонт', 'Прочее']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    testWidgets('раздел «Цены» показывает прайс и назначает новую цену',
        (tester) async {
      await pumpShell(tester);
      await openSection(tester, 'Цены');

      expect(find.byType(PricesDesktopPage), findsOneWidget);
      // Действующий прайс и история — на одном экране, без шторки.
      expect(find.text('ДЕЙСТВУЮЩИЙ ПРАЙС'), findsOneWidget);
      expect(find.text('ИСТОРИЯ ИЗМЕНЕНИЙ'), findsOneWidget);

      // Поля заполнены действующей ценой — сохранять нечего.
      final save = find.widgetWithText(DesktopButton, 'Сохранить');
      expect(tester.widget<DesktopButton>(save).onPressed, isNull);

      // Мок отвечает через `Future.delayed`, а часы в тесте фейковые: запрос
      // запускаем, прокручиваем время и только потом ждём.
      Future<int> capsulePrice() {
        final pending = repo.getPrices();
        return tester
            .pump(const Duration(milliseconds: 300))
            .then((_) => pending)
            .then((p) => p.capsulePrice);
      }

      final before = await capsulePrice();

      // Первое поле — цена капсулы.
      final capsule = find
          .descendant(
            of: find.byType(PricesDesktopPage),
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(capsule, '${before + 500}');
      await tester.pump();
      expect(tester.widget<DesktopButton>(save).onPressed, isNotNull);

      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Подтверждение — не красное: старый прайс остаётся в истории.
      expect(find.text('Назначить новую цену?'), findsOneWidget);
      await tester.tap(find.widgetWithText(DesktopButton, 'Назначить'));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.text('Цены обновлены'), findsOneWidget);
      await settleToast(tester);

      // Сервер принял, а прежняя цена ушла в историю без перечитывания.
      expect(await capsulePrice(), before + 500);
      expect(
        find.descendant(
          of: find.byType(DesktopTable),
          matching: find.text(
            MoneyFormatter.sum(lookupAppLocalizations(AppLocales.ru), before),
          ),
        ),
        findsWidgets,
      );
    });

    testWidgets('в разделе «Маршруты» кнопка заводит маршрут', (tester) async {
      await pumpShell(tester);

      // Раньше кнопки создания у маршрутов не было вовсе — маршрут заводился
      // только с телефона.
      await tester.tap(find.widgetWithText(DesktopButton, 'Маршрут'));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(RouteFormPage), findsOneWidget);
    });

    testWidgets('из карточки доставки открывается правка её маршрута',
        (tester) async {
      await pumpShell(tester);

      // На телефоне вход в маршрут — отдельный экран, а здесь список плоский,
      // из доставок: правка маршрута доступна из карточки его точки.
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(DeliveryDrawer), findsOneWidget);

      await tester.tap(find.text('Редактировать маршрут'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Форма та же, что на создании, но с маршрутом — то есть в режиме правки.
      final form = tester.widget<RouteFormPage>(find.byType(RouteFormPage));
      expect(form.isEdit, isTrue);
    });
  });

  group('Выгрузка отчётов', () {
    late RecordingFileSharer sharer;

    Future<void> pumpShell(WidgetTester tester) async {
      useDesktopSurface(tester);
      sharer = RecordingFileSharer();
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CrmRepository>.value(value: MockCrmRepository()),
            RepositoryProvider<CapsulePrice>.value(
              value: const BuildCapsulePrice(),
            ),
          ],
          child: BlocProvider(
            create: (_) => ThemeCubit(storage: InMemorySettingsStorage()),
            child: MaterialApp(
              theme: AppTheme.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocales.supported,
              home: DesktopShell(fileSharer: sharer),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    /// Переходит в отчёты. График недели поднимает семь запросов сводки разом,
    /// и каждый оставляет свой таймер — их надо догнать.
    Future<void> openReports(WidgetTester tester) async {
      await tester.tap(find.text('Отчёты'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets('кнопка выгрузки есть только в отчётах', (tester) async {
      await pumpShell(tester);

      // В маршрутах первичное действие своё — «Маршрут».
      expect(
        find.widgetWithText(DesktopButton, 'Выгрузить в Excel'),
        findsNothing,
      );

      await openReports(tester);

      expect(
        find.widgetWithText(DesktopButton, 'Выгрузить в Excel'),
        findsOneWidget,
      );
    });

    testWidgets('кнопка открывает выбор отчёта и отдаёт файл', (tester) async {
      await pumpShell(tester);
      await openReports(tester);

      await tester.tap(find.widgetWithText(DesktopButton, 'Выгрузить в Excel'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Экран выбора общий с телефоном — своей копии под десктоп нет.
      expect(find.byType(ReportExportPage), findsOneWidget);

      // Точное совпадение: подпись кнопки в шапке под ним — другая строка.
      await tester.tap(find.text('Выгрузить'));
      await tester.pump();
      // Успех подтверждается снек-баром, он живёт 4 секунды — если его не
      // дождаться, тест падает на «A Timer is still pending».
      await tester.pump(const Duration(seconds: 5));

      expect(sharer.shared, hasLength(1));
      expect(sharer.shared.single.filename, endsWith('.xlsx'));
    });
  });
}

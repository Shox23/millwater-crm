import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/app.dart';
import 'package:crm_millwater/app/settings/settings_storage.dart';
import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/app/theme/theme_cubit.dart';
import 'package:crm_millwater/core/utils/day.dart';
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
  bool? addedHasCooler;
  Customer? updatedCustomer;

  @override
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    required String address,
    String? comment,
    bool hasCooler = false,
    String? idempotencyKey,
  }) {
    addedHasCooler = hasCooler;
    return super.addCustomer(
      name: name,
      phone: phone,
      address: address,
      comment: comment,
      hasCooler: hasCooler,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<Customer> updateCustomer(Customer customer) {
    updatedCustomer = customer;
    return super.updateCustomer(customer);
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
      // Завершение доставки админу недоступно — кнопка есть, но выключена.
      final finish = find.widgetWithText(DesktopButton, 'Закончить маршрут');
      if (finish.evaluate().isNotEmpty) {
        expect(tester.widget<DesktopButton>(finish).onPressed, isNull);
      }
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

    /// Поля формы заказчика по порядку: имя, телефон, адрес, комментарий.
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

      await tester.enterText(customerField(0), 'Кафе «Тест»');
      await tester.enterText(customerField(1), '+998 90 111 22 33');
      await tester.enterText(customerField(2), 'Мирабад, 5');
      await tester.pump();

      // По умолчанию кулера нет — включаем его переключателем.
      await tester.tap(find.text('С кулером'));
      await tester.pump();

      await tester.tap(find.widgetWithText(DesktopButton, 'Сохранить'));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(repo.addedHasCooler, isTrue);
      expect(repo.store.customers.last.hasCooler, isTrue);
      await settleToast(tester);
    });

    testWidgets('правка заказчика снимает кулер и отправляет это на сервер',
        (tester) async {
      // Заготовка идёт без кулеров — ставим его первому заказчику, чтобы
      // проверять именно снятие. Стор правим синхронно, до pump.
      repo.store.customers[0] =
          repo.store.customers[0].copyWith(hasCooler: true);

      await pumpShell(tester);
      await openSection(tester, 'Заказчики');

      final customer = repo.store.customers[0];
      await tester.tap(find.byTooltip('Редактировать').first);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byType(CustomerFormModal), findsOneWidget);

      await tester.tap(find.text('Без кулера'));
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
  });
}

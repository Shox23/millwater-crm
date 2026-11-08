import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/driver_customer.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/presentation/customer_detail_page.dart';
import 'package:crm_millwater/features/customers/presentation/customer_form_page.dart';
import 'package:crm_millwater/features/routes/presentation/widgets/stop_card.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Имя заказчика (`customer_name`) — контактное лицо, появилось 07.11.26.
///
/// При создании обязательно (сервер без него отвечает 422). У заказчиков,
/// заведённых раньше, его нет: они должны открываться, показываться и
/// сохраняться без имени, а указанное имя стереть нельзя — пустую строку
/// сервер не примет.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'c-1',
        'full_name': 'Кафе',
        'customer_name': 'Алишер',
        'phone': '+998901112233',
        'address': 'ул. Тестовая, 1',
        'created_at': '2026-11-09T10:00:00',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Customer _customer({String? contactName}) => Customer(
      id: 'c1',
      name: 'Кафе',
      contactName: contactName,
      phone: '+998901112233',
      address: 'ул. Тестовая, 1',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('Разбор', () {
    test('заказчик: имя читается, «не указано» — null', () {
      expect(
        Customer.fromJson({'id': 'c', 'customer_name': 'Алишер'}).contactName,
        'Алишер',
      );
      // У старых заказчиков — null; пустая строка и пробелы значат то же.
      for (final empty in [null, '', '   ']) {
        expect(
          Customer.fromJson({'id': 'c', 'customer_name': empty}).contactName,
          isNull,
        );
      }
      expect(Customer.fromJson({'id': 'c'}).contactName, isNull);
      expect(
        Customer.fromJson({'id': 'c', 'customer_name': '  Алишер '})
            .contactName,
        'Алишер',
      );
    });

    test('заказчик водителя', () {
      expect(
        DriverCustomer.fromJson({'id': 'c', 'customer_name': 'Алишер'})
            .contactName,
        'Алишер',
      );
      expect(
        DriverCustomer.fromJson({'id': 'c', 'customer_name': null})
            .contactName,
        isNull,
      );
    });

    test('точка маршрута и заказ — из вложенного customer', () {
      final json = {
        'id': 'o1',
        'status': 'pending',
        'customer': {
          'customer_id': 'c1',
          'customer_full_name': 'Кафе',
          'customer_name': 'Алишер',
        },
      };
      expect(RouteStop.fromJson(json).customerContactName, 'Алишер');
      expect(Order.fromJson(json).customerContactName, 'Алишер');

      final old = {
        'id': 'o1',
        'status': 'pending',
        'customer': {'customer_id': 'c1', 'customer_name': null},
      };
      expect(RouteStop.fromJson(old).customerContactName, isNull);
      expect(Order.fromJson(old).customerContactName, isNull);
    });

    test('ключ customer_name в корне записи не принимается за имя', () {
      // В уведомлениях сервер кладёт туда название (`full_name`).
      final json = {
        'id': 'o1',
        'status': 'pending',
        'customer_name': 'Кафе',
      };
      expect(RouteStop.fromJson(json).customerContactName, isNull);
      expect(Order.fromJson(json).customerContactName, isNull);
    });
  });

  group('На провод', () {
    test('PATCH несёт имя, только когда оно есть', () {
      expect(
        _customer(contactName: 'Алишер').toUpdateJson()['customer_name'],
        'Алишер',
      );
      // `null` у старого заказчика — «так и не узнали», а не «стереть».
      expect(_customer().toUpdateJson().containsKey('customer_name'), isFalse);
    });

    test('copyWith без имени оставляет прежнее', () {
      expect(
        _customer(contactName: 'Алишер').copyWith(name: 'Другое').contactName,
        'Алишер',
      );
    });

    test('при создании уходит всегда', () async {
      final adapter = _RecordingAdapter();
      final repo = ApiCrmRepository(
        Dio(BaseOptions(baseUrl: 'https://crm.millwater.uz'))
          ..httpClientAdapter = adapter,
      );

      final created = await repo.addCustomer(
        name: 'Кафе',
        contactName: 'Алишер',
        phone: '+998901112233',
        address: 'ул. Тестовая, 1',
      );

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['customer_name'], 'Алишер');
      expect(body['full_name'], 'Кафе');
      expect(created.contactName, 'Алишер');
    });
  });

  group('Форма заказчика', () {
    late MockCrmRepository repo;

    setUp(() => repo = MockCrmRepository());

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> pumpForm(WidgetTester tester, {Customer? customer}) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            theme: AppTheme.light(),
            home: CustomerFormPage(customer: customer),
          ),
        ),
      );
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Finder inputFor(String label) => find.descendant(
          of: find
              .ancestor(of: find.text(label), matching: find.byType(Column))
              .first,
          matching: find.byType(TextField),
        );

    bool submitEnabled(WidgetTester tester, String label) =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, label)).enabled;

    Future<void> save(WidgetTester tester, String label) async {
      final submit = find.widgetWithText(AppButton, label);
      await tester.ensureVisible(submit);
      await settle(tester);
      await tester.tap(submit);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
    }

    /// Заказчик в сторе мока — правка уходит в него.
    Customer stored(String id) =>
        repo.store.customers.firstWhere((c) => c.id == id);

    testWidgets('новый заказчик без имени не сохраняется', (tester) async {
      await pumpForm(tester);
      await tester.enterText(inputFor('Адрес доставки'), 'Чиланзар, 12');
      await tester.enterText(inputFor('Название'), 'Кафе «Nasiba»');
      await tester.enterText(inputFor('Номер телефона'), '901234567');
      await settle(tester);

      expect(submitEnabled(tester, 'Добавить'), isFalse);

      await tester.enterText(inputFor('Имя заказчика'), '  Насиба Каримова ');
      await settle(tester);
      expect(submitEnabled(tester, 'Добавить'), isTrue);

      await save(tester, 'Добавить');
      expect(repo.store.customers.last.contactName, 'Насиба Каримова');
    });

    testWidgets('старого заказчика без имени можно сохранить и так',
        (tester) async {
      final old = repo.store.customers.firstWhere((c) => c.contactName == null);
      await pumpForm(tester, customer: old);

      // Поле пустое, а подсказка объясняет почему.
      expect(
        find.text('Раньше не указывали — заполните, когда узнаете'),
        findsOneWidget,
      );

      await tester.enterText(inputFor('Название'), 'Новое название');
      await settle(tester);
      expect(submitEnabled(tester, 'Сохранить'), isTrue);

      await save(tester, 'Сохранить');
      expect(stored(old.id).name, 'Новое название');
      expect(stored(old.id).contactName, isNull);
    });

    testWidgets('старому заказчику имя можно дописать', (tester) async {
      final old = repo.store.customers.firstWhere((c) => c.contactName == null);
      await pumpForm(tester, customer: old);

      await tester.enterText(inputFor('Имя заказчика'), 'Дилноза');
      await settle(tester);
      await save(tester, 'Сохранить');

      expect(stored(old.id).contactName, 'Дилноза');
    });

    testWidgets('указанное имя стереть нельзя', (tester) async {
      final named =
          repo.store.customers.firstWhere((c) => c.contactName != null);
      await pumpForm(tester, customer: named);

      expect(
        find.text('Раньше не указывали — заполните, когда узнаете'),
        findsNothing,
      );

      await tester.enterText(inputFor('Имя заказчика'), '');
      await settle(tester);

      expect(submitEnabled(tester, 'Сохранить'), isFalse);
    });
  });

  group('Показ', () {
    Future<void> pump(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: MockCrmRepository(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            theme: AppTheme.light(),
            home: home,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('карточка заказчика: имя или «Не указано»', (tester) async {
      await pump(tester,
          CustomerDetailPage(customer: _customer(contactName: 'Алишер')));
      expect(find.text('Имя заказчика'), findsOneWidget);
      expect(find.text('Алишер'), findsOneWidget);

      await pump(tester, CustomerDetailPage(customer: _customer()));
      expect(find.text('Имя заказчика'), findsOneWidget);
      expect(find.text('Не указано'), findsOneWidget);
    });

    testWidgets('карточка точки показывает имя, только когда оно есть',
        (tester) async {
      RouteStop stop({String? contact}) => RouteStop(
            id: 's1',
            customerId: 'c1',
            customerName: 'Кафе',
            customerContactName: contact,
            customerAddress: 'ул. Тестовая, 1',
            customerPhone: '+998901112233',
            status: DeliveryStatus.pending,
          );

      await pump(tester, Scaffold(body: StopCard(stop: stop(contact: 'Алишер'))));
      expect(find.text('Алишер'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);

      await pump(tester, Scaffold(body: StopCard(stop: stop())));
      expect(find.byIcon(Icons.person_outline), findsNothing);
      expect(find.text('Не указано'), findsNothing);
    });
  });
}

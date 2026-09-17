import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/validation/validators.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/presentation/customer_detail_page.dart';
import 'package:crm_millwater/features/customers/presentation/customer_form_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Дополнительный телефон заказчика (`phone_secondary`).
///
/// Необязательное поле с двумя ловушками: пустую строку сервер отвергает
/// (минимум пять символов), поэтому на провод уходит либо E.164, либо
/// `null`; и `null` в PATCH — это «стереть», а не «не менять», поэтому ключ
/// отправляется всегда, а `copyWith` не должен путать «нет» с «не трогали».
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
        'phone': '+998901112233',
        'phone_secondary': null,
        'address': 'ул. Тестовая, 1',
        'created_at': '2026-09-18T10:00:00',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Customer _customer({String? phoneSecondary}) => Customer(
      id: 'c1',
      name: 'Кафе',
      phone: '+998901112233',
      phoneSecondary: phoneSecondary,
      address: 'ул. Тестовая, 1',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('Разбор', () {
    test('читается из phone_secondary', () {
      final customer = Customer.fromJson({
        'id': 'c-1',
        'full_name': 'Кафе',
        'phone': '+998901112233',
        'phone_secondary': '+998901002030',
      });
      expect(customer.phoneSecondary, '+998901002030');
    });

    test('null, отсутствие и пустая строка — «нет»', () {
      expect(
        Customer.fromJson({'id': 'c-1', 'phone_secondary': null}).phoneSecondary,
        isNull,
      );
      expect(Customer.fromJson({'id': 'c-1'}).phoneSecondary, isNull);
      expect(
        Customer.fromJson({'id': 'c-1', 'phone_secondary': ''}).phoneSecondary,
        isNull,
      );
    });
  });

  group('На провод', () {
    test('PATCH несёт ключ всегда — null стирает номер', () {
      expect(
        _customer(phoneSecondary: '+998901002030').toUpdateJson()['phone_secondary'],
        '+998901002030',
      );

      final cleared = _customer().toUpdateJson();
      expect(cleared.containsKey('phone_secondary'), isTrue);
      expect(cleared['phone_secondary'], isNull);
    });

    test('copyWith различает «стереть» и «не трогали»', () {
      final withPhone = _customer(phoneSecondary: '+998901002030');

      expect(withPhone.copyWith(name: 'Другое').phoneSecondary,
          '+998901002030');
      expect(withPhone.copyWith(phoneSecondary: null).phoneSecondary, isNull);
    });

    late _RecordingAdapter adapter;
    late ApiCrmRepository repo;

    setUp(() {
      adapter = _RecordingAdapter();
      repo = ApiCrmRepository(
        Dio(BaseOptions(baseUrl: 'https://crm.millwater.uz'))
          ..httpClientAdapter = adapter,
      );
    });

    test('при создании уходит, только когда задан', () async {
      await repo.addCustomer(
        name: 'Кафе',
        phone: '+998901112233',
        phoneSecondary: '+998901002030',
        address: 'ул. Тестовая, 1',
      );
      await repo.addCustomer(
        name: 'Кафе',
        phone: '+998901112233',
        address: 'ул. Тестовая, 1',
      );

      final first = adapter.requests.first.data as Map<String, dynamic>;
      final second = adapter.requests.last.data as Map<String, dynamic>;
      expect(first['phone_secondary'], '+998901002030');
      // Пустой строки быть не может — сервер отверг бы её (минимум пять
      // символов), а `null` при создании и так значит «нет».
      expect(second.containsKey('phone_secondary'), isFalse);
    });
  });

  group('Правило проверки', () {
    final v = Validators(lookupAppLocalizations(const Locale('ru')));

    test('пустое поле и один префикс — не ошибка', () {
      expect(v.phoneOptional(''), isNull);
      expect(v.phoneOptional(null), isNull);
      expect(v.phoneOptional('+998 '), isNull);
    });

    test('начатый номер должен быть полным', () {
      expect(v.phoneOptional('+998 90 1'), contains('неполный'));
      expect(v.phoneOptional('+998 90 100 20 30'), isNull);
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

    Future<void> fillRequired(WidgetTester tester) async {
      await tester.enterText(inputFor('Название / имя'), 'Кафе «Nasiba»');
      await tester.enterText(inputFor('Номер телефона'), '901234567');
      await tester.enterText(inputFor('Адрес доставки'), 'Чиланзар, 12');
      await settle(tester);
    }

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

    testWidgets('поле есть, необязательное и пустым уходит как null',
        (tester) async {
      await pumpForm(tester);
      await fillRequired(tester);

      expect(find.text('Дополнительный телефон'), findsOneWidget);
      // Стартует пустым: «+998 » в необязательном поле просил бы номер.
      expect(
        tester.widget<TextField>(inputFor('Дополнительный телефон')).controller!.text,
        isEmpty,
      );
      expect(submitEnabled(tester, 'Добавить'), isTrue);

      await save(tester, 'Добавить');
      expect(repo.store.customers.last.phoneSecondary, isNull);
    });

    testWidgets('набранный номер уходит в E.164', (tester) async {
      await pumpForm(tester);
      await fillRequired(tester);

      await tester.enterText(inputFor('Дополнительный телефон'), '901002030');
      await settle(tester);

      await save(tester, 'Добавить');
      expect(repo.store.customers.last.phoneSecondary, '+998901002030');
    });

    testWidgets('неполный номер форму блокирует', (tester) async {
      await pumpForm(tester);
      await fillRequired(tester);

      await tester.enterText(inputFor('Дополнительный телефон'), '9010');
      await settle(tester);

      expect(submitEnabled(tester, 'Добавить'), isFalse);
    });

    testWidgets('правка открывается с номером, стирание уходит как null',
        (tester) async {
      final customer =
          repo.store.customers.first.copyWith(phoneSecondary: '+998901002030');
      repo.store.customers[0] = customer;
      await pumpForm(tester, customer: customer);

      expect(find.text('+998 90 100 20 30'), findsOneWidget);

      await tester.enterText(inputFor('Дополнительный телефон'), '');
      await settle(tester);

      await save(tester, 'Сохранить');
      expect(
        repo.store.customers.firstWhere((c) => c.id == customer.id).phoneSecondary,
        isNull,
      );
    });
  });

  group('Карточка заказчика', () {
    late MockCrmRepository repo;

    setUp(() => repo = MockCrmRepository());

    Future<void> pumpDetail(WidgetTester tester, Customer customer) async {
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
            home: CustomerDetailPage(customer: customer),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('второй номер — отдельной строкой, без него строки нет',
        (tester) async {
      await pumpDetail(tester, _customer(phoneSecondary: '+998901002030'));
      expect(find.text('Дополнительный телефон'), findsOneWidget);
      expect(find.text('+998 90 100 20 30'), findsOneWidget);

      await pumpDetail(tester, _customer());
      expect(find.text('Дополнительный телефон'), findsNothing);
    });
  });
}

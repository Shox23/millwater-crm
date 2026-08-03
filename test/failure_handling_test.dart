import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/driver.dart';
import 'package:crm_millwater/data/models/reports_summary.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/presentation/customer_form_page.dart';
import 'package:crm_millwater/features/customers/presentation/customers_page.dart';
import 'package:crm_millwater/features/drivers/presentation/driver_form_page.dart';
import 'package:crm_millwater/features/reports/presentation/reports_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Репозиторий, который валится на записи и/или на чтении.
class _FailingRepository extends MockCrmRepository {
  _FailingRepository({this.onWrite, this.onRead});

  /// Исключение для добавления/обновления/удаления.
  final Object? onWrite;

  /// Исключение для списочных запросов и отчёта.
  final Object? onRead;

  Never _throwWrite() => throw onWrite!;

  Future<T> _read<T>(Future<T> Function() original) {
    if (onRead != null) return Future.error(onRead!);
    return original();
  }

  static DioException serverError(String message) => DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 409,
          data: {
            'success': false,
            'error': {'code': 'CONFLICT', 'message': message},
          },
        ),
      );

  @override
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    required String address,
    String? comment,
  }) async {
    if (onWrite != null) _throwWrite();
    return super.addCustomer(
        name: name, phone: phone, address: address, comment: comment);
  }

  @override
  Future<Driver> addDriver({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (onWrite != null) _throwWrite();
    return super.addDriver(
        fullName: fullName, phone: phone, email: email, password: password);
  }

  @override
  Future<void> deleteCustomer(String id) async {
    if (onWrite != null) _throwWrite();
    return super.deleteCustomer(id);
  }

  @override
  Future<List<Customer>> getCustomers({String? search, bool? hasDebt}) =>
      _read(() => super.getCustomers(search: search, hasDebt: hasDebt));

  @override
  Future<ReportsSummary> getReportsSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) =>
      _read(() => super.getReportsSummary(dateFrom: dateFrom, dateTo: dateTo));
}

void main() {
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pump(
    WidgetTester tester,
    CrmRepository repo,
    Widget page,
  ) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      RepositoryProvider<CrmRepository>.value(
        value: repo,
        child: MaterialApp(theme: AppTheme.light(), home: page),
      ),
    );
    await settle(tester);
  }

  Finder inputFor(String label) => find.descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Column))
            .first,
        matching: find.byType(TextField),
      );

  group('Ошибка сохранения не убивает форму', () {
    testWidgets('заказчик: показана причина с сервера, кнопка снова активна',
        (tester) async {
      final repo = _FailingRepository(
        onWrite: _FailingRepository.serverError('Телефон уже занят'),
      );
      await pump(tester, repo, const CustomerFormPage());

      await tester.enterText(inputFor('Название / имя'), 'Чайхана «Тест»');
      await tester.enterText(inputFor('Номер телефона'), '901234567');
      await tester.enterText(inputFor('Адрес доставки'), 'Чиланзар, 5');
      await tester.tap(find.text('Добавить'));
      await settle(tester);

      expect(find.text('Телефон уже занят'), findsOneWidget);
      // Главное: форма не осталась в состоянии «Сохранение…» навсегда.
      expect(find.text('Добавить'), findsOneWidget);
      expect(find.text('Сохранение…'), findsNothing);

      // Повторное нажатие проходит — кнопка живая.
      await tester.tap(find.text('Добавить'));
      await settle(tester);
      expect(find.text('Телефон уже занят'), findsOneWidget);
    });

    testWidgets('водитель: сетевой сбой без ответа сервера', (tester) async {
      final repo = _FailingRepository(
        onWrite: DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        ),
      );
      await pump(tester, repo, const DriverFormPage());

      await tester.enterText(inputFor('Имя водителя'), 'Тимур Юсупов');
      await tester.enterText(inputFor('Номер телефона'), '911234567');
      await tester.enterText(inputFor('Пароль для входа'), 'secret1');
      await tester.tap(find.text('Добавить'));
      await settle(tester);

      expect(find.text('Нет связи с сервером.'), findsOneWidget);
      expect(find.text('Добавить'), findsOneWidget);
    });
  });

  group('Ошибка загрузки не притворяется пустотой', () {
    testWidgets('список заказчиков предлагает повторить', (tester) async {
      final repo = _FailingRepository(onRead: Exception('нет сети'));
      await pump(tester, repo, const CustomersPage());

      expect(find.text('Не удалось загрузить заказчиков'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      // Раньше на этом месте было «Ничего не найдено».
      expect(find.text('Ничего не найдено'), findsNothing);
    });

    testWidgets('отчёты не крутят спиннер вечно', (tester) async {
      final repo = _FailingRepository(onRead: Exception('нет сети'));
      await pump(tester, repo, const ReportsPage());

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Не удалось загрузить отчёты'), findsOneWidget);
    });

    testWidgets('«Повторить» перезапрашивает данные', (tester) async {
      // Читаем через мок, который падает только первый раз.
      final repo = _FlakyRepository();
      await pump(tester, repo, const CustomersPage());
      expect(find.text('Не удалось загрузить заказчиков'), findsOneWidget);

      await tester.tap(find.text('Повторить'));
      await settle(tester);

      expect(find.text('Не удалось загрузить заказчиков'), findsNothing);
      expect(find.text('Кафе «Nasiba»'), findsWidgets);
    });
  });

  group('Ошибка удаления', () {
    testWidgets('показана снек-баром, строка остаётся на месте',
        (tester) async {
      final repo = _FailingRepository(
        onWrite: _FailingRepository.serverError('У заказчика есть долг'),
      );
      await pump(tester, repo, const CustomersPage());

      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await settle(tester);
      await tester.tap(find.text('Удалить').last);
      await settle(tester);

      expect(find.text('У заказчика есть долг'), findsOneWidget);
      expect(find.text('Кафе «Nasiba»'), findsWidgets);
    });
  });
}

/// Падает на первом чтении заказчиков, дальше работает нормально.
class _FlakyRepository extends MockCrmRepository {
  bool _failed = false;

  @override
  Future<List<Customer>> getCustomers({String? search, bool? hasDebt}) {
    if (!_failed) {
      _failed = true;
      return Future.error(Exception('нет сети'));
    }
    return super.getCustomers(search: search, hasDebt: hasDebt);
  }
}

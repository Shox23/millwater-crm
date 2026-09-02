import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/export/file_sharer.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/report_export.dart';
import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/reports/presentation/reports_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Отдаёт «файл» и запоминает, с какими параметрами его просили.
class _ExportAdapter implements HttpClientAdapter {
  _ExportAdapter({this.disposition});

  /// Значение заголовка `Content-Disposition`; null — сервер его не прислал.
  final String? disposition;

  Map<String, dynamic>? query;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    query = options.queryParameters;
    return ResponseBody.fromBytes(
      // Сигнатура ZIP — с неё начинается любой xlsx.
      [0x50, 0x4B, 0x03, 0x04, ...List.filled(20, 0)],
      200,
      headers: {
        Headers.contentTypeHeader: [
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ],
        if (disposition != null) 'content-disposition': [disposition!],
      },
    );
  }
}

/// Экспорт всегда падает — проверяем, что экран об этом сообщает.
class _FailingExportRepository extends MockCrmRepository {
  @override
  Future<ReportExport> exportSummaryReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) async =>
      throw DioException(
        requestOptions: RequestOptions(path: '/admin/reports/export'),
        type: DioExceptionType.connectionError,
      );
}

void main() {
  group('Запрос выгрузки', () {
    ApiCrmRepository repoWith(_ExportAdapter adapter) =>
        ApiCrmRepository(Dio()..httpClientAdapter = adapter);

    test('границы периода уходят в query как даты', () async {
      final adapter = _ExportAdapter();

      await repoWith(adapter).exportSummaryReport(
        dateFrom: DateTime(2026, 8, 1),
        dateTo: DateTime(2026, 8, 17),
      );

      expect(adapter.query!['date_from'], '2026-08-01');
      expect(adapter.query!['date_to'], '2026-08-17');
      // Водителя не задавали — параметра быть не должно.
      expect(adapter.query!.containsKey('driver_id'), isFalse);
    });

    test('фильтр по водителю передаётся', () async {
      final adapter = _ExportAdapter();

      await repoWith(adapter).exportSummaryReport(
        dateFrom: DateTime(2026, 8, 1),
        dateTo: DateTime(2026, 8, 17),
        driverId: 'd1',
      );

      expect(adapter.query!['driver_id'], 'd1');
    });

    test('имя файла берётся из Content-Disposition', () async {
      final adapter = _ExportAdapter(
        disposition: 'attachment; filename="report-august.xlsx"',
      );

      final export = await repoWith(adapter).exportSummaryReport(
        dateFrom: DateTime(2026, 8, 1),
        dateTo: DateTime(2026, 8, 17),
      );

      expect(export.filename, 'report-august.xlsx');
      expect(export.sizeBytes, greaterThan(0));
    });

    test('процент-кодированное имя раскодируется', () async {
      final name = Uri.encodeComponent('отчёт.xlsx');
      final adapter = _ExportAdapter(
        disposition: "attachment; filename*=UTF-8''$name",
      );

      final export = await repoWith(adapter).exportSummaryReport(
        dateFrom: DateTime(2026, 8, 1),
        dateTo: DateTime(2026, 8, 17),
      );

      expect(export.filename, 'отчёт.xlsx');
    });

    test('без заголовка имя собирается из периода', () async {
      final export = await repoWith(_ExportAdapter()).exportSummaryReport(
        dateFrom: DateTime(2026, 8, 1),
        dateTo: DateTime(2026, 8, 17),
      );

      // Расширение обязательно: без него Excel файл не откроет.
      expect(export.filename, 'millwater-2026-08-01_2026-08-17.xlsx');
    });
  });

  group('Кнопка выгрузки на экране отчётов', () {
    Future<void> pumpReports(
      WidgetTester tester,
      CrmRepository repo,
      FileSharer sharer,
    ) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repo,
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            home: ReportsPage(fileSharer: sharer),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('файл уходит в «Поделиться» с именем от сервера',
        (tester) async {
      final sharer = RecordingFileSharer();
      await pumpReports(tester, MockCrmRepository(), sharer);

      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(sharer.shared, hasLength(1));
      expect(sharer.shared.single.filename, 'millwater-report.xlsx');
      expect(sharer.shared.single.size, greaterThan(0));
    });

    testWidgets('отказ сервера объясняется, а не проглатывается',
        (tester) async {
      final sharer = RecordingFileSharer();
      await pumpReports(tester, _FailingExportRepository(), sharer);

      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(sharer.shared, isEmpty);
      expect(find.text('Не удалось выгрузить отчёт.'), findsOneWidget);
      // Кнопка вернулась в рабочее состояние.
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    });
  });

  group('Кулеры заказчика', () {
    test('количество разбирается, а булев признак остаётся понятен', () {
      final withCoolers = {
        'id': 'c1',
        'full_name': 'Влад',
        'phone': '+998901234567',
        'address': 'Чиланзар, 5',
        'bottle_balance': 2,
        'prepayment': '0.00',
        'debt': '0.00',
        'last_order_date': null,
        'is_active': true,
        'cooler_count': 3,
        'custom_water_price': null,
        'comment': null,
        'created_at': '2026-01-01T00:00:00Z',
      };

      expect(customerFrom(withCoolers).coolerCount, 3);
      expect(customerFrom(withCoolers).hasCooler, isTrue);
      expect(customerFrom({...withCoolers, 'cooler_count': 0}).hasCooler, isFalse);

      // Старый стенд отдаёт булево поле — сборка с этим кодом смотрит и на
      // него, иначе у всех заказчиков разом «кулера нет».
      final legacy = {...withCoolers}..remove('cooler_count');
      expect(customerFrom({...legacy, 'has_cooler': true}).coolerCount, 1);
      expect(customerFrom(legacy).coolerCount, 0);
    });

    test('индивидуальная цена: ноль и мусор — это «цены нет»', () {
      final base = {
        'id': 'c1',
        'full_name': 'Влад',
        'phone': '+998901234567',
        'address': 'Чиланзар, 5',
        'bottle_balance': 0,
        'prepayment': '0.00',
        'debt': '0.00',
        'last_order_date': null,
        'is_active': true,
        'cooler_count': 0,
        'comment': null,
        'created_at': '2026-01-01T00:00:00Z',
      };

      expect(
        customerFrom({...base, 'custom_water_price': '15000.00'})
            .customWaterPrice,
        15000,
      );
      expect(
        customerFrom({...base, 'custom_water_price': null}).hasIndividualPrice,
        isFalse,
      );
      // Ноль сюда приходит только из неразобранного значения: считать по нему
      // значило бы выставить заказчику ноль сум за капсулу.
      expect(
        customerFrom({...base, 'custom_water_price': '0'}).customWaterPrice,
        isNull,
      );
    });

    test('количество кулеров уходит на сервер при создании и правке', () async {
      final repo = MockCrmRepository();

      final created = await repo.addCustomer(
        name: 'Влад',
        phone: '+998901234567',
        address: 'Чиланзар, 5',
        coolerCount: 2,
      );
      expect(created.coolerCount, 2);
      expect(created.toUpdateJson()['cooler_count'], 2);

      final off = await repo.updateCustomer(created.copyWith(coolerCount: 0));
      expect(off.hasCooler, isFalse);
    });

    test('кулеры и своя цена лежат в теле POST и PATCH', () async {
      // Мок проверяет модель, но не то, что поле дошло до сети: между
      // репозиторием и сервером есть сборка тела, и молча потерять его
      // может именно она.
      final adapter = _RecordingCustomerAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final repo = ApiCrmRepository(dio);

      final created = await repo.addCustomer(
        name: 'Влад',
        phone: '+998901234567',
        address: 'Чиланзар, 5',
        coolerCount: 2,
        customWaterPrice: 15000,
      );
      expect(adapter.bodies.last['cooler_count'], 2);
      expect(adapter.bodies.last['custom_water_price'], '15000');
      // Баланс отправляется всегда при создании: у нового заказчика он
      // осмыслен, и сервер сам проверит, что оба не заданы разом.
      expect(adapter.bodies.last['debt'], '0');

      await repo.updateCustomer(created.copyWith(coolerCount: 0));
      expect(adapter.bodies.last['cooler_count'], 0);
      // Долг и предоплата в PATCH не уходят, пока их не правили руками:
      // иначе форма откатила бы оплату, принятую водителем, пока была открыта.
      expect(adapter.bodies.last.containsKey('debt'), isFalse);
      expect(adapter.methods, ['POST', 'PATCH']);
    });

    test('правка баланса отправляет его явно', () async {
      final adapter = _RecordingCustomerAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final repo = ApiCrmRepository(dio);

      final created = await repo.addCustomer(
        name: 'Влад',
        phone: '+998901234567',
        address: 'Чиланзар, 5',
      );

      await repo.updateCustomer(
        created.copyWith(debt: 50000),
        balanceChanged: true,
      );
      expect(adapter.bodies.last['debt'], '50000');
      expect(adapter.bodies.last['prepayment'], '0');
    });
  });
}


class _RecordingCustomerAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> bodies = [];
  final List<String> methods = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    final body = (options.data as Map).cast<String, dynamic>();
    bodies.add(body);

    return ResponseBody.fromString(
      jsonEncode({
        'id': 'c1',
        'full_name': body['full_name'],
        'phone': body['phone'],
        'address': body['address'],
        'bottle_balance': 0,
        'prepayment': '0.00',
        'debt': '0.00',
        'last_order_date': null,
        'is_active': true,
        'cooler_count': body['cooler_count'],
        'custom_water_price': body['custom_water_price'],
        'comment': body['comment'],
        'created_at': '2026-01-01T00:00:00Z',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Разбирает заказчика из ответа сервера — обёртка ради читаемости тестов.
Customer customerFrom(Map<String, dynamic> json) => Customer.fromJson(json);

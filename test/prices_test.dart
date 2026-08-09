import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/mock/seed_data.dart';
import 'package:crm_millwater/data/models/price_settings.dart';
import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/prices/presentation/prices_page.dart';
import 'package:dio/dio.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Отдаёт заданный прайс и запоминает тела и заголовки запросов.
class _PricesAdapter implements HttpClientAdapter {
  _PricesAdapter({this.body = _defaultBody});

  final Object body;
  final List<RequestOptions> requests = [];

  static const _defaultBody = {
    'id': 'p1',
    'water_price': '25000.00',
    'deposit_price': '50000.00',
    'created_at': '2026-08-09T10:00:00',
  };

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
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Репозиторий, падающий на чтении прайса.
class _FailingPricesRepository extends MockCrmRepository {
  @override
  Future<PriceSettings> getPrices() async => throw Exception('нет связи');
}

/// История есть, но пустая — цену ещё ни разу не меняли.
class _SinglePriceRepository extends MockCrmRepository {
  @override
  Future<List<PriceSettings>> getPriceHistory() async => [await getPrices()];
}

/// Действующая цена читается, история — нет.
class _FailingHistoryRepository extends MockCrmRepository {
  @override
  Future<List<PriceSettings>> getPriceHistory() async =>
      throw Exception('нет связи');
}

void main() {
  group('Прайс в API-репозитории', () {
    ApiCrmRepository repositoryWith(_PricesAdapter adapter) {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      return ApiCrmRepository(dio);
    }

    test('текущий прайс разбирается из строк с копейками', () async {
      final adapter = _PricesAdapter();
      final prices = await repositoryWith(adapter).getPrices();

      expect(adapter.requests.single.path, '/admin/prices/current');
      expect(prices.capsulePrice, 25000);
      expect(prices.depositPrice, 50000);
      expect(prices.createdAt, DateTime(2026, 8, 9, 10));
    });

    test('история приходит списком и раскладывается новыми вперёд', () async {
      final adapter = _PricesAdapter(body: const [
        {
          'id': 'p-old',
          'water_price': '18000.00',
          'deposit_price': '45000.00',
          'created_at': '2026-01-01T09:00:00',
        },
        {
          'id': 'p-new',
          'water_price': '25000.00',
          'deposit_price': '50000.00',
          'created_at': '2026-08-09T10:00:00',
        },
      ]);

      final history = await repositoryWith(adapter).getPriceHistory();

      expect(adapter.requests.single.path, '/admin/prices/history');
      // Сервер порядок не обещает — раскладываем сами.
      expect(history.map((p) => p.id), ['p-new', 'p-old']);
    });

    test('запредельные значения из схемы не роняют разбор', () async {
      // Ровно тот ответ, что отдаёт пример в Swagger: числа длиной в сотню
      // знаков и с ведущим «+». Показывать такое бессмысленно, но падать
      // на разборе экран не должен.
      final adapter = _PricesAdapter(body: const [
        {
          'id': 'p-huge',
          'water_price':
              '00000000000000000000000000000000000000000000000000000000000000'
                  '07453980569682499178063466371692148060635560193550543094645'
                  '633176727620983.10616711045563062953566292341649231024789055126107',
          'deposit_price': '+00000000000000000753858722068601126425',
          'created_at': '2026-08-08T22:21:15.101Z',
        },
      ]);

      final history = await repositoryWith(adapter).getPriceHistory();

      expect(history, hasLength(1));
      // Значение упирается в потолок int64 — это не ошибка разбора.
      expect(history.single.capsulePrice, isPositive);
      expect(history.single.depositPrice, isPositive);
    });

    test('новая цена уходит обеими полями и с ключом идемпотентности',
        () async {
      final adapter = _PricesAdapter();
      await repositoryWith(adapter).setPrices(
        capsulePrice: 25000,
        depositPrice: 50000,
        idempotencyKey: 'price-1',
      );

      final request = adapter.requests.single;
      expect(request.path, '/admin/prices');
      expect(request.data, {
        'water_price': '25000',
        'deposit_price': '50000',
      });
      expect(request.headers['Idempotency-Key'], 'price-1');
    });
  });

  group('Прайс в моке', () {
    test('новая цена заменяет действующую', () async {
      final repo = MockCrmRepository();
      expect((await repo.getPrices()).capsulePrice, SeedData.capsulePrice);

      await repo.setPrices(capsulePrice: 30000, depositPrice: 60000);
      final current = await repo.getPrices();

      expect(current.capsulePrice, 30000);
      expect(current.depositPrice, 60000);
    });

    test('история пополняется новой ценой и держит порядок', () async {
      final repo = MockCrmRepository();
      final before = await repo.getPriceHistory();

      await repo.setPrices(capsulePrice: 30000, depositPrice: 60000);
      final after = await repo.getPriceHistory();

      expect(after, hasLength(before.length + 1));
      expect(after.first.capsulePrice, 30000);
      expect(after[1].capsulePrice, SeedData.capsulePrice);
    });

    test('повтор с тем же ключом не заводит вторую запись', () async {
      final repo = MockCrmRepository();

      final first = await repo.setPrices(
        capsulePrice: 30000,
        depositPrice: 60000,
        idempotencyKey: 'price-42',
      );
      final second = await repo.setPrices(
        capsulePrice: 30000,
        depositPrice: 60000,
        idempotencyKey: 'price-42',
      );

      expect(second.id, first.id);
    });
  });

  group('Экран «Цены»', () {
    late MockCrmRepository repo;

    setUp(() => repo = MockCrmRepository());

    Future<void> pumpPage(WidgetTester tester, CrmRepository repository) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RepositoryProvider<CrmRepository>.value(
          value: repository,
          child: MaterialApp(
            // Строки интерфейса берутся из локали: тесты идут на русской.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
            theme: AppTheme.light(),
            home: const PricesPage(),
          ),
        ),
      );
      // Мок отвечает через Future.delayed — прокручиваем фейковые часы.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Finder inputFor(String label) => find.descendant(
          of: find
              .ancestor(of: find.text(label), matching: find.byType(Column))
              .first,
          matching: find.byType(TextField),
        );

    /// Мок отвечает через `Future.delayed`, а внутри `testWidgets` время
    /// фейковое: запрос отправляем и прокручиваем часы, пока он не завершится.
    Future<PriceSettings> currentPrices(WidgetTester tester) {
      final pending = repo.getPrices();
      return tester
          .pump(const Duration(milliseconds: 300))
          .then((_) => pending);
    }

    bool saveEnabled(WidgetTester tester) =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Сохранить'))
            .enabled;

    testWidgets('показывает действующий прайс', (tester) async {
      await pumpPage(tester, repo);

      expect(find.text('20 000 сум'), findsOneWidget);
      expect(find.text('50 000 сум'), findsOneWidget);
      expect(find.textContaining('Действует с'), findsOneWidget);
    });

    testWidgets('история показывает прошлые цены без действующей',
        (tester) async {
      await pumpPage(tester, repo);

      expect(find.text('ИСТОРИЯ ИЗМЕНЕНИЙ'), findsOneWidget);
      // Прошлая цена из сида — 18 000, действующая 20 000 уже в карточке выше.
      expect(find.text('18 000 сум'), findsOneWidget);
      expect(find.text('20 000 сум'), findsOneWidget);
      expect(find.text('залог 45 000 сум'), findsOneWidget);
    });

    testWidgets('без прошлых записей история объясняет пустоту',
        (tester) async {
      await pumpPage(tester, _SinglePriceRepository());

      expect(find.text('Прайс ещё не меняли — это первая цена.'),
          findsOneWidget);
    });

    testWidgets('отказ истории не ломает экран', (tester) async {
      await pumpPage(tester, _FailingHistoryRepository());

      // Действующая цена на месте, изменить её по-прежнему можно.
      expect(find.text('20 000 сум'), findsOneWidget);
      expect(find.text('Историю загрузить не удалось.'), findsOneWidget);
      expect(find.text('Сохранить'), findsOneWidget);
    });

    testWidgets('без изменений сохранять нечего', (tester) async {
      await pumpPage(tester, repo);

      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('нулевая цена капсулы не сохраняется', (tester) async {
      await pumpPage(tester, repo);

      await tester.enterText(inputFor('Цена капсулы'), '0');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(saveEnabled(tester), isFalse);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump();
      expect(find.text('Цена капсулы должна быть больше нуля'), findsOneWidget);
    });

    testWidgets('новая цена сохраняется после подтверждения', (tester) async {
      await pumpPage(tester, repo);

      await tester.enterText(inputFor('Цена капсулы'), '25000');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(saveEnabled(tester), isTrue);

      await tester.tap(find.text('Сохранить'));
      await tester.pump();

      // Цена уходит всем водителям — спрашиваем подтверждение.
      expect(find.text('Назначить новую цену?'), findsOneWidget);
      expect(find.textContaining('Капсула — 25 000 сум'), findsOneWidget);

      await tester.tap(find.text('Назначить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect((await currentPrices(tester)).capsulePrice, 25000);
    });

    testWidgets('отказ от подтверждения ничего не меняет', (tester) async {
      await pumpPage(tester, repo);

      await tester.enterText(inputFor('Цена капсулы'), '25000');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      await tester.tap(find.text('Отмена'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect((await currentPrices(tester)).capsulePrice, SeedData.capsulePrice);
    });

    testWidgets('ошибка загрузки предлагает повторить', (tester) async {
      await pumpPage(tester, _FailingPricesRepository());

      expect(find.text('Не удалось загрузить цены'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });
  });
}

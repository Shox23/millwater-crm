import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/result_page.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_driver_repository.dart';
import 'package:crm_millwater/data/mock/mock_store.dart';
import 'package:crm_millwater/features/orders/bloc/orders_bloc.dart';
import 'package:crm_millwater/features/orders/bloc/orders_source.dart';
import 'package:crm_millwater/core/utils/stats_period.dart';
import 'package:flutter_test/flutter_test.dart';

/// Что именно ушло на сервер за одну загрузку списка.
typedef _Call = ({
  int page,
  DeliveryStatus? status,
  OrderPurpose? purpose,
  String? search,
  DateTime? dateFrom,
  DateTime? dateTo,
});

/// Запоминает параметры отбора и всегда обещает следующую страницу — иначе
/// догрузку не проверить.
class _RecordingSource implements OrdersSource {
  /// Столько заказов сервер насчитал во всей выдаче — это не длина страницы.
  static const int total = 99;

  final calls = <_Call>[];

  @override
  Future<void> cancel({required String orderId, String? reason}) async {}

  @override
  Future<ResultPage<Order>> load({
    required int page,
    DeliveryStatus? status,
    OrderPurpose? purpose,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    calls.add((
      page: page,
      status: status,
      purpose: purpose,
      search: search,
      dateFrom: dateFrom,
      dateTo: dateTo,
    ));
    return ResultPage(
      items: [
        for (var i = 0; i < 2; i++)
          Order(
            id: 'o-$page-$i',
            number: page * 10 + i,
            status: status ?? DeliveryStatus.delivered,
            purpose: purpose ?? OrderPurpose.delivery19l,
            createdAt: DateTime(2026, 8, 25),
            customerId: 'c-$i',
            customerName: 'Заказчик $i',
          ),
      ],
      page: page,
      hasMore: true,
      total: total,
    );
  }
}

void main() {
  group('Список заказов', () {
    late _RecordingSource source;
    late OrdersBloc bloc;

    setUp(() {
      source = _RecordingSource();
      bloc = OrdersBloc(source);
      addTearDown(bloc.close);
    });

    /// Ждёт следующую полную загрузку: смена чипа сперва меняет состояние и
    /// лишь потом уходит в запрос.
    Future<void> loaded() async {
      await bloc.stream.firstWhere((s) => s.status == OrdersStatus.loading);
      await bloc.stream.firstWhere((s) => s.status == OrdersStatus.ready);
    }

    test('первая загрузка идёт без отбора', () async {
      bloc.add(const OrdersRequested());
      await loaded();

      expect(source.calls.single.page, 1);
      expect(source.calls.single.status, isNull);
      expect(source.calls.single.purpose, isNull);
      // Дат тоже нет: список показывает всё время — этим он и отличается от
      // экрана маршрутов, привязанного ко дню.
      expect(source.calls.single.dateFrom, isNull);
      expect(source.calls.single.dateTo, isNull);
      expect(bloc.state.total, 99);
    });

    test('готовый период уходит границами, а не названием', () async {
      bloc.add(const OrdersRequested());
      await loaded();

      bloc.add(const OrdersDateChanged(OrdersPeriodDate(StatsPeriod.today)));
      await loaded();

      final today = DateTime.now();
      final call = source.calls.last;
      expect(call.dateFrom, isNotNull);
      expect(call.dateTo, isNotNull);
      expect(call.dateFrom!.day, today.day);
      expect(call.dateTo!.day, today.day);
      // Отбор меняет запрос, а не режет уже загруженное: страница берётся
      // заново с первой.
      expect(call.page, 1);
    });

    test('выбранный диапазон уходит как есть', () async {
      bloc.add(const OrdersRequested());
      await loaded();

      final from = DateTime(2026, 8, 15);
      final to = DateTime(2026, 8, 20);
      bloc.add(OrdersDateChanged(OrdersCustomDate(from, to)));
      await loaded();

      expect(source.calls.last.dateFrom, from);
      expect(source.calls.last.dateTo, to);
    });

    test('возврат к «за всё время» снимает границы', () async {
      bloc.add(const OrdersRequested());
      await loaded();

      bloc.add(const OrdersDateChanged(OrdersPeriodDate(StatsPeriod.month)));
      await loaded();
      expect(source.calls.last.dateFrom, isNotNull);

      bloc.add(const OrdersDateChanged(OrdersAnyDate()));
      await loaded();

      expect(source.calls.last.dateFrom, isNull);
      expect(source.calls.last.dateTo, isNull);
      expect(bloc.state.hasFilters, isFalse);
    });

    test('повторный выбор того же периода в сеть не ходит', () async {
      bloc.add(const OrdersRequested());
      await loaded();

      bloc.add(const OrdersDateChanged(OrdersPeriodDate(StatsPeriod.week)));
      await loaded();
      final count = source.calls.length;

      // Тот же период, но другой экземпляр — сравнение по значению, а не по
      // ссылке: иначе каждый тап по уже выбранному чипу дёргал бы сервер.
      bloc.add(const OrdersDateChanged(OrdersPeriodDate(StatsPeriod.week)));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(source.calls.length, count);
    });

    test('отбор уходит на сервер, а не режет загруженное', () async {
      bloc.add(const OrdersRequested());
      await loaded();

      bloc.add(const OrdersStatusChanged(DeliveryStatus.failed));
      await loaded();
      expect(source.calls.last.status, DeliveryStatus.failed);

      bloc.add(const OrdersPurposeChanged(OrderPurpose.pickup));
      await loaded();
      expect(source.calls.last.purpose, OrderPurpose.pickup);
      // Прежний отбор при этом не потерялся: фильтры складываются.
      expect(source.calls.last.status, DeliveryStatus.failed);
    });

    test('сброс в «Все» отправляет пустой отбор, а не прежний', () async {
      bloc.add(const OrdersStatusChanged(DeliveryStatus.delivered));
      await loaded();

      bloc.add(const OrdersStatusChanged(null));
      await loaded();

      expect(source.calls.last.status, isNull);
      expect(bloc.state.hasFilters, isFalse);
    });

    test('смена отбора начинает список с первой страницы', () async {
      bloc.add(const OrdersRequested());
      await loaded();
      bloc.add(const OrdersNextPageRequested());
      await bloc.stream.firstWhere((s) => !s.loadingMore && s.page == 2);
      expect(source.calls.last.page, 2);

      bloc.add(const OrdersPurposeChanged(OrderPurpose.bulkWater));
      await loaded();

      // Иначе первая страница отбора осталась бы за кадром.
      expect(source.calls.last.page, 1);
      expect(bloc.state.page, 1);
    });

    test('догрузка не теряет отбор и складывает страницы', () async {
      bloc.add(const OrdersStatusChanged(DeliveryStatus.delivered));
      await loaded();
      expect(bloc.state.orders, hasLength(2));

      bloc.add(const OrdersNextPageRequested());
      await bloc.stream.firstWhere((s) => !s.loadingMore && s.page == 2);

      expect(source.calls.last.status, DeliveryStatus.delivered);
      expect(bloc.state.orders, hasLength(4));
    });

    test('повторное нажатие того же чипа запрос не шлёт', () async {
      bloc.add(const OrdersRequested());
      await loaded();
      final before = source.calls.length;

      bloc.add(const OrdersStatusChanged(null));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(source.calls.length, before);
    });

    test('поиск уходит на сервер после паузы в наборе', () async {
      bloc.add(const OrdersSearchChanged('нас'));
      await loaded();

      expect(source.calls.last.search, 'нас');
      expect(source.calls.last.page, 1);
    });
  });

  group('Роли берут заказы из своих источников', () {
    test('админ видит все заказы, водитель — только свои', () async {
      // Один и тот же стор: демо разъезжается, если у ролей разные данные.
      final store = MockStore();
      final admin = AdminOrdersSource(MockCrmRepository(store: store));
      final driver =
          DriverOrdersSource(MockDriverRepository(store: store, driverId: 'd1'));

      final all = await admin.load(page: 1);
      final mine = await driver.load(page: 1);

      expect(all.total, greaterThan(0));
      expect(mine.total, greaterThan(0));
      // Водитель не задаёт `driver_id` — источник подставляет его сам, как
      // сервер подставляет водителя из токена.
      expect(mine.total, lessThan(all.total));
      expect(mine.items.every((o) => o.driverId == 'd1'), isTrue);
    });
  });
}

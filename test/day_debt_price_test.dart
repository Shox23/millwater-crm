import 'package:crm_millwater/core/pricing/capsule_price.dart';
import 'package:crm_millwater/core/product_config.dart';
import 'package:crm_millwater/core/utils/day.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/desktop/bloc/day_deliveries_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Цена, известная заранее, — без сети и без кэша.
class _FixedCapsulePrice implements CapsulePrice {
  const _FixedCapsulePrice(this.price);

  final int price;

  @override
  Future<int> value() async => price;
}

RouteStop _stop({
  required String id,
  required int capsules,
  required int? paid,
}) =>
    RouteStop(
      id: id,
      customerId: 'c-$id',
      customerName: 'Заказчик $id',
      customerAddress: 'Мирабад, ул. Нукус 1',
      customerPhone: '+998901234567',
      status: DeliveryStatus.delivered,
      deliveredCapsules: capsules,
      paymentAmount: paid,
    );

/// День с одной доставкой в долг: три капсулы привезли, денег не приняли.
class _OneDebtDayRepository extends MockCrmRepository {
  static final today = dayOnly(DateTime.now());

  static final route = RouteDetail(
    id: 'r-1',
    date: today,
    status: RouteStatus.completed,
    completedCount: 2,
    totalCustomers: 2,
    driverId: 'd-1',
    driverFullName: 'Водитель',
    stops: [
      _stop(id: 'debt', capsules: 3, paid: 0),
      // Оплаченная точка в долг не попадает — иначе цена влияла бы на неё же.
      _stop(id: 'paid', capsules: 2, paid: 40000),
    ],
  );

  @override
  Future<List<RouteListItem>> getRoutes({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? driverId,
    RouteStatus? status,
  }) async =>
      [
        RouteListItem(
          id: route.id,
          date: route.date,
          status: route.status,
          completedCount: route.completedCount,
          totalCustomers: route.totalCustomers,
          driverId: route.driverId,
          driverFullName: route.driverFullName,
        ),
      ];

  @override
  Future<RouteDetail?> getRoute(String id) async => route;
}

void main() {
  /// Ждёт, пока блок доложит о готовности дня.
  Future<DayDeliveriesState> loadDay(DayDeliveriesBloc bloc) {
    final ready = bloc.stream
        .firstWhere((s) => s.status == DayDeliveriesStatus.ready);
    bloc.add(const DayDeliveriesRequested());
    return ready;
  }

  test('долг за день считается по прайсу сервера, а не по сборке', () async {
    final bloc = DayDeliveriesBloc(
      _OneDebtDayRepository(),
      price: const _FixedCapsulePrice(25000),
    );
    addTearDown(bloc.close);

    final state = await loadDay(bloc);

    // Три капсулы по живой цене. По зашитой в сборку получилось бы другое
    // число — ровно та ложь, из-за которой показатель и переписывали.
    expect(state.capsulePrice, 25000);
    expect(state.debt, 3 * 25000);
    expect(state.debt, isNot(3 * ProductConfig.capsulePrice));
  });

  test('отказ прайса оставляет расчёт по значению сборки', () async {
    // Ровно то, что вернёт `ApiCapsulePrice`, когда сервер откажет.
    final bloc = DayDeliveriesBloc(
      _OneDebtDayRepository(),
      price: const BuildCapsulePrice(),
    );
    addTearDown(bloc.close);

    final state = await loadDay(bloc);

    expect(state.debt, 3 * ProductConfig.capsulePrice);
  });

  test('без источника цены блок ведёт себя как раньше', () async {
    final bloc = DayDeliveriesBloc(_OneDebtDayRepository());
    addTearDown(bloc.close);

    final state = await loadDay(bloc);

    expect(state.capsulePrice, ProductConfig.capsulePrice);
  });

  test('«в долг» читается из способа оплаты, а не из нулевой суммы', () {
    // Нулевая сумма сама по себе долга не означает: закрыть точку с нулём
    // можно и по другой причине, а способ оплаты сервер отдаёт прямо.
    final cash = DeliveryRow(
      route: _OneDebtDayRepository.route,
      stop: _stop(id: 'cash', capsules: 0, paid: 0)
          .copyWith(paymentMethod: PaymentMethod.cash),
    );
    final debt = DeliveryRow(
      route: _OneDebtDayRepository.route,
      stop: _stop(id: 'debt', capsules: 3, paid: 0)
          .copyWith(paymentMethod: PaymentMethod.debt),
    );

    expect(cash.isDebt, isFalse);
    expect(debt.isDebt, isTrue);
  });

  test('точка старого клиента без способа оплаты по-прежнему угадывается', () {
    // Такие точки закрыты сборкой, которая способа не присылала: без отката
    // они выпали бы из «в долг за день» задним числом.
    final legacy = DeliveryRow(
      route: _OneDebtDayRepository.route,
      stop: _stop(id: 'legacy', capsules: 3, paid: 0),
    );

    expect(legacy.stop.paymentMethod, isNull);
    expect(legacy.isDebt, isTrue);
  });
}

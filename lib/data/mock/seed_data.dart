import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/reports_summary.dart';
import '../models/route_models.dart';

/// Сид-данные, выверенные под цифры макета.
/// «Сегодня» зафиксировано на 05.07.26, как в шапке экрана «Маршруты».
abstract class SeedData {
  static final DateTime today = DateTime(2026, 7, 5);
  static final DateTime _created = DateTime(2026, 1, 1);

  /// Цена капсулы в моках (на сервере задаётся через /admin/prices).
  static const int capsulePrice = 20000;

  static List<Driver> drivers() => [
        Driver(
          id: 'd1',
          fullName: 'Азиз Каримов',
          phone: '+998 90 123 45 67',
          email: 'aziz.karimov@aqua.uz',
          tripCount: 128,
          todayTripCount: 4,
          createdAt: _created,
        ),
        Driver(
          id: 'd2',
          fullName: 'Бобур Рахимов',
          phone: '+998 93 245 67 89',
          email: 'bobur.rakhimov@aqua.uz',
          tripCount: 96,
          todayTripCount: 3,
          createdAt: _created,
        ),
        Driver(
          id: 'd3',
          fullName: 'Шерзод Юлдашев',
          phone: '+998 90 555 12 34',
          email: 'sherzod.yuldashev@aqua.uz',
          tripCount: 154,
          todayTripCount: 2,
          createdAt: _created,
        ),
        Driver(
          id: 'd4',
          fullName: 'Дилшод Нуриддинов',
          phone: '+998 94 321 00 11',
          email: 'dilshod.nuriddinov@aqua.uz',
          tripCount: 71,
          todayTripCount: 1,
          createdAt: _created,
        ),
        Driver(
          id: 'd5',
          fullName: 'Фаррух Тошматов',
          phone: '+998 97 888 77 66',
          email: 'farrukh.toshmatov@aqua.uz',
          tripCount: 43,
          todayTripCount: 0,
          createdAt: _created,
        ),
      ];

  static List<Customer> customers() => [
        Customer(
          id: 'c1',
          name: 'Кафе «Nasiba»',
          phone: '+998 71 200 11 22',
          address: 'ул. Амир Темур, 12',
          comment: 'Мирабад',
          capsuleBalance: 5,
          prepayment: 200000,
          lastOrderDate: DateTime(2026, 7, 3),
          createdAt: _created,
        ),
        Customer(
          id: 'c2',
          name: 'Офис «Baraka»',
          phone: '+998 71 244 55 66',
          address: 'Юнусабад, кв-л 4',
          comment: 'Юнусабад',
          capsuleBalance: 8,
          debt: 120000,
          lastOrderDate: DateTime(2026, 7, 4),
          createdAt: _created,
        ),
        Customer(
          id: 'c3',
          name: 'Дилноза Хамидова',
          phone: '+998 90 700 30 20',
          address: 'Чиланзар, 9-й кв-л',
          comment: 'Чиланзар',
          capsuleBalance: 2,
          lastOrderDate: DateTime(2026, 7, 2),
          createdAt: _created,
        ),
        Customer(
          id: 'c4',
          name: 'Салон «Zebo»',
          phone: '+998 71 233 44 55',
          address: 'Куйлюк, база 2',
          comment: 'Куйлюк',
          capsuleBalance: 3,
          lastOrderDate: DateTime(2026, 7, 1),
          createdAt: _created,
        ),
        Customer(
          id: 'c5',
          name: 'ООО «Tetra»',
          phone: '+998 71 202 90 90',
          address: 'М. Улугбек',
          comment: 'М. Улугбек',
          capsuleBalance: 5,
          debt: 300000,
          lastOrderDate: DateTime(2026, 6, 30),
          createdAt: _created,
        ),
        Customer(
          id: 'c6',
          name: 'Магазин «Osiyo»',
          phone: '+998 90 400 10 10',
          address: 'Сергели, 5-й кв-л',
          comment: 'Сергели',
          capsuleBalance: 3,
          lastOrderDate: DateTime(2026, 7, 4),
          createdAt: _created,
        ),
      ];

  /// Маршруты на сегодня: 10 остановок суммарно, 5 завершено, собрано 280 000.
  static List<RouteDetail> routes() {
    RouteStop stop(
      String id,
      Customer c,
      int capsules,
      DeliveryStatus status, {
      bool paid = false,
    }) {
      return RouteStop(
        id: id,
        customerId: c.id,
        customerName: c.name,
        customerAddress: c.address,
        customerPhone: c.phone,
        status: status,
        deliveredCapsules: capsules,
        paymentAmount: paid ? capsules * capsulePrice : null,
      );
    }

    final c = {for (final x in customers()) x.id: x};

    final r1 = RouteDetail(
      id: 'r1',
      date: today,
      status: RouteStatus.inProgress,
      driverId: 'd1',
      driverFullName: 'Азиз Каримов',
      completedCount: 1,
      totalCustomers: 3,
      stops: [
        stop('s1', c['c1']!, 5, DeliveryStatus.paid, paid: true),
        stop('s2', c['c4']!, 3, DeliveryStatus.onWay),
        stop('s3', c['c1']!, 2, DeliveryStatus.pending),
      ],
    );

    final r2 = RouteDetail(
      id: 'r2',
      date: today,
      status: RouteStatus.inProgress,
      driverId: 'd2',
      driverFullName: 'Бобур Рахимов',
      completedCount: 1,
      totalCustomers: 2,
      stops: [
        stop('s4', c['c2']!, 8, DeliveryStatus.onWay),
        stop('s5', c['c5']!, 5, DeliveryStatus.paid, paid: true),
      ],
    );

    final r3 = RouteDetail(
      id: 'r3',
      date: today,
      status: RouteStatus.completed,
      driverId: 'd3',
      driverFullName: 'Шерзод Юлдашев',
      completedCount: 2,
      totalCustomers: 2,
      stops: [
        stop('s6', c['c6']!, 4, DeliveryStatus.paid, paid: true),
        stop('s7', c['c4']!, 4, DeliveryStatus.delivered),
      ],
    );

    final r4 = RouteDetail(
      id: 'r4',
      date: today,
      status: RouteStatus.created,
      driverId: 'd4',
      driverFullName: 'Дилшод Нуриддинов',
      completedCount: 0,
      totalCustomers: 2,
      stops: [
        stop('s8', c['c3']!, 2, DeliveryStatus.pending),
        stop('s9', c['c6']!, 3, DeliveryStatus.pending),
      ],
    );

    final r5 = RouteDetail(
      id: 'r5',
      date: today,
      status: RouteStatus.completed,
      driverId: 'd5',
      driverFullName: 'Фаррух Тошматов',
      completedCount: 1,
      totalCustomers: 1,
      stops: [
        stop('s10', c['c2']!, 3, DeliveryStatus.delivered),
      ],
    );

    return [r1, r2, r3, r4, r5];
  }

  /// Недельный график (значения — суммы в сум).
  static const List<WeeklyBar> weekly = [
    WeeklyBar(label: 'Пн', value: 210000),
    WeeklyBar(label: 'Вт', value: 340000),
    WeeklyBar(label: 'Ср', value: 280000),
    WeeklyBar(label: 'Чт', value: 410000),
    WeeklyBar(label: 'Пт', value: 280000),
  ];

  /// Ёмкость по капсулам (для «26 из 47»).
  static const int capsulesTotal = 47;
}

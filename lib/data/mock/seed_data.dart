import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/route_models.dart';

/// Сид-данные, выверенные под цифры макета.
///
/// «Сегодня» — настоящий текущий день, а не фиксированная дата: экран
/// маршрутов запрашивает список за выбранный в ленте день, и сид с прибитым
/// прошлым числом отдавал бы пустоту на всех табах. Остальные даты считаются
/// от него, чтобы фикстура оставалась связной.
abstract class SeedData {
  static final DateTime today = _dayOnly(DateTime.now());
  static final DateTime _created = DateTime(2026, 1, 1);

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// День на [days] раньше «сегодня».
  static DateTime _daysAgo(int days) =>
      today.subtract(Duration(days: days));

  /// Цена капсулы в моках (на сервере задаётся через /admin/prices).
  static const int capsulePrice = 20000;

  /// Залог за тару в моках.
  static const int depositPrice = 50000;

  static List<Driver> drivers() => [
        Driver(
          id: 'd1',
          fullName: 'Азиз Каримов',
          phone: '+998 90 123 45 67',
          tripCount: 128,
          todayTripCount: 4,
          createdAt: _created,
        ),
        Driver(
          id: 'd2',
          fullName: 'Бобур Рахимов',
          phone: '+998 93 245 67 89',
          tripCount: 96,
          todayTripCount: 3,
          createdAt: _created,
        ),
        Driver(
          id: 'd3',
          fullName: 'Шерзод Юлдашев',
          phone: '+998 90 555 12 34',
          tripCount: 154,
          todayTripCount: 2,
          createdAt: _created,
        ),
        Driver(
          id: 'd4',
          fullName: 'Дилшод Нуриддинов',
          phone: '+998 94 321 00 11',
          tripCount: 71,
          todayTripCount: 1,
          createdAt: _created,
        ),
        Driver(
          id: 'd5',
          fullName: 'Фаррух Тошматов',
          phone: '+998 97 888 77 66',
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
          lastOrderDate: _daysAgo(2),
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
          lastOrderDate: _daysAgo(1),
          createdAt: _created,
        ),
        Customer(
          id: 'c3',
          name: 'Дилноза Хамидова',
          phone: '+998 90 700 30 20',
          address: 'Чиланзар, 9-й кв-л',
          comment: 'Чиланзар',
          capsuleBalance: 2,
          lastOrderDate: _daysAgo(3),
          createdAt: _created,
        ),
        Customer(
          id: 'c4',
          name: 'Салон «Zebo»',
          phone: '+998 71 233 44 55',
          address: 'Куйлюк, база 2',
          comment: 'Куйлюк',
          capsuleBalance: 3,
          lastOrderDate: _daysAgo(4),
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
          lastOrderDate: _daysAgo(5),
          createdAt: _created,
        ),
        Customer(
          id: 'c6',
          name: 'Магазин «Osiyo»',
          phone: '+998 90 400 10 10',
          address: 'Сергели, 5-й кв-л',
          comment: 'Сергели',
          capsuleBalance: 3,
          lastOrderDate: _daysAgo(1),
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
        stop('s1', c['c1']!, 5, DeliveryStatus.delivered, paid: true),
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
        stop('s5', c['c5']!, 5, DeliveryStatus.delivered, paid: true),
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
        stop('s6', c['c6']!, 4, DeliveryStatus.delivered, paid: true),
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
}

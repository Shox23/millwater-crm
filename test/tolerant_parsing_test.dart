import 'package:crm_millwater/core/utils/money_parser.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/driver.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/json.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ответ сервера не обязан совпадать со схемой — он с ней уже расходился.
/// Цена ошибки была несоразмерной: одно поле не того типа роняло разбор всей
/// страницы, и вместо девяноста девяти нормальных записей пользователь видел
/// общую ошибку загрузки.
void main() {
  /// Заказчик ровно так, как его описывает схема.
  Map<String, dynamic> customerJson([Map<String, dynamic> overrides = const {}]) => {
        'id': 'c1',
        'full_name': 'Кафе «Nasiba»',
        'phone': '+998901234567',
        'address': 'ул. Амир Темур, 12',
        'comment': null,
        'bottle_balance': 5,
        'prepayment': '0',
        'debt': '120000.00',
        'last_order_date': '2026-08-10T09:30:00Z',
        'is_active': true,
        'has_cooler': true,
        'created_at': '2026-01-05T10:00:00Z',
        ...overrides,
      };

  group('Заказчик переживает неожиданные типы', () {
    test('число вместо строки в идентификаторе', () {
      final customer = Customer.fromJson(customerJson({'id': 42}));
      expect(customer.id, '42');
    });

    test('строка вместо числа в остатке капсул', () {
      expect(Customer.fromJson(customerJson({'bottle_balance': '7'}))
          .capsuleBalance, 7);
      // Совсем мусор — ноль, а не падение.
      expect(Customer.fromJson(customerJson({'bottle_balance': 'много'}))
          .capsuleBalance, 0);
    });

    test('дробное количество округляется, а не роняет разбор', () {
      expect(Customer.fromJson(customerJson({'bottle_balance': 5.6}))
          .capsuleBalance, 6);
    });

    test('строка вместо булева в признаке кулера', () {
      expect(Customer.fromJson(customerJson({'has_cooler': 'true'})).hasCooler,
          isTrue);
      expect(Customer.fromJson(customerJson({'has_cooler': 1})).hasCooler,
          isTrue);
    });

    test('битая дата не роняет запись', () {
      final customer = Customer.fromJson(
        customerJson({'last_order_date': 'позавчера', 'created_at': ''}),
      );
      expect(customer.lastOrderDate, isNull);
      // Дата создания обязательна для модели, но подставлять «сейчас» нельзя —
      // запись выглядела бы только что заведённой.
      expect(customer.createdAt, epoch);
    });

    test('пропущенные необязательные поля — значения по умолчанию', () {
      final customer = Customer.fromJson({'id': 'c9'});
      expect(customer.name, '');
      expect(customer.debt, 0);
      expect(customer.isActive, isTrue);
    });

    test('без идентификатора запись отвергается', () {
      // Открыть, изменить и удалить её всё равно нечем.
      expect(() => Customer.fromJson(customerJson({'id': null})),
          throwsFormatException);
    });
  });

  group('Список пропускает битые записи, а не рушится', () {
    test('одна плохая запись стоит одной строки', () {
      var skipped = 0;
      final customers = parseList(
        [
          customerJson({'id': 'c1'}),
          customerJson({'id': null}), // без идентификатора
          customerJson({'id': 'c3'}),
          'вообще не объект',
        ],
        Customer.fromJson,
        onSkipped: (count) => skipped = count,
      );

      expect(customers.map((c) => c.id), ['c1', 'c3']);
      // Молча терять данные нельзя — пропуск попадает в отчёт.
      expect(skipped, 1);
    });

    test('не список — пустой результат, а не исключение', () {
      expect(parseList(null, Customer.fromJson), isEmpty);
      expect(parseList('строка', Customer.fromJson), isEmpty);
    });
  });

  group('Маршрут и его точки', () {
    test('точка без идентификатора не уносит с собой весь маршрут', () {
      final route = RouteDetail.fromJson({
        'id': 'r1',
        'date': '2026-08-19',
        'status': 'in_progress',
        'completed_count': 1,
        'total_customers': 3,
        'route_customers': [
          {'id': 's1', 'customer_id': 'c1', 'status': 'delivered'},
          {'customer_id': 'c2', 'status': 'pending'}, // без id
          {'id': 's3', 'customer_id': 'c3', 'status': 'pending'},
        ],
      });

      expect(route.id, 'r1');
      expect(route.stops.map((s) => s.id), ['s1', 's3']);
    });

    test('незнакомый статус не роняет разбор', () {
      final route = RouteDetail.fromJson({
        'id': 'r2',
        'date': '2026-08-19',
        'status': 'какой-то_новый_статус',
        'route_customers': const [],
      });
      // Сервер вправе добавить статус, о котором клиент не знает.
      expect(route.status, RouteStatus.created);
    });

    test('отсутствующий список точек — пустой маршрут', () {
      final route = RouteDetail.fromJson({'id': 'r3', 'date': '2026-08-19'});
      expect(route.stops, isEmpty);
    });
  });

  group('Деньги', () {
    test('строка с копейками округляется', () {
      expect(MoneyParser.toSum('20000.00'), 20000);
      expect(MoneyParser.toSum('1500.5'), 1501);
    });

    test('бесконечность и NaN больше не роняют разбор', () {
      // `num.round()` на них бросает UnsupportedError, а бесконечность
      // получается из строки вроде "1e400" — то есть из ответа сервера.
      expect(MoneyParser.toSum(double.infinity), MoneyParser.maxSum);
      expect(MoneyParser.toSum(double.nan), 0);
      expect(MoneyParser.toSum('1e400'), MoneyParser.maxSum);
    });

    test('запредельная сумма обрезается, а не превращается в мусор', () {
      // Пример из схемы: 120-значное число. Раньше оно давало
      // 9223372036854775807 — в графе «Долг» это выглядит как настоящая сумма.
      const huge = '+00000000000000000000000001179247087414872991630349936772'
          '1643652827006715678922766522987845605795764281172232908012342';
      expect(MoneyParser.toSum(huge), MoneyParser.maxSum);
    });

    test('мусор и пустота — ноль', () {
      expect(MoneyParser.toSum(null), 0);
      expect(MoneyParser.toSum('не число'), 0);
      expect(MoneyParser.toSum(''), 0);
    });
  });

  group('Водитель', () {
    test('счётчики строками', () {
      final driver = Driver.fromJson({
        'id': 'd1',
        'full_name': 'Азиз Каримов',
        'phone': '+998901112233',
        'trip_count': '12',
        'today_trip_count': null,
        'created_at': '2026-01-05T10:00:00Z',
      });
      expect(driver.tripCount, 12);
      expect(driver.todayTripCount, 0);
    });
  });
}

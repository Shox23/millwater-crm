import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/order.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Разбор заказа и точки маршрута.
///
/// Релиз переименовал `route_customers` в `orders`, а `order` — в `sequence`,
/// причём старые имена наружу отдавать перестали. Приложение обязано
/// понимать оба: сборка живёт в сторах месяцами и смотрит то на обновлённый
/// стенд, то на прежний.
void main() {
  Map<String, dynamic> orderJson([Map<String, dynamic> extra = const {}]) => {
        'id': 'o-1',
        'number': 10432,
        'sequence': 3,
        'status': 'delivered',
        'purpose': 'delivery_19l',
        'payment_method': 'cash',
        'delivered_bottles': 5,
        'returned_bottles': 4,
        'damaged_bottles': 1,
        'bottle_balance_after': 6,
        'order_amount': '115000.00',
        'water_price_applied': '15000.00',
        'damaged_fine_applied': '40000.00',
        'completed_at': '2026-08-25T10:00:00Z',
        'created_at': '2026-08-25T08:00:00Z',
        'customer': {
          'id': 'c-1',
          'full_name': 'Кафе «Nasiba»',
          'phone': '+998712001122',
          'address': 'ул. Амир Темур, 12',
        },
        'route': {
          'id': 'r-1',
          'date': '2026-08-25',
          'driver_id': 'd-1',
        },
        ...extra,
      };

  /// Форма, которую сервер отдаёт сейчас: тот же вложенный объект, но ключи
  /// внутри него с префиксом объекта.
  Map<String, dynamic> prefixedOrderJson() => {
        ...orderJson(),
        'customer': {
          'customer_id': 'c-1',
          'customer_full_name': 'Кафе «Nasiba»',
          'customer_phone': '+998712001122',
          'customer_address': 'ул. Амир Темур, 12',
          'customer_cooler_count': 2,
          'customer_debt': '60000.00',
          'customer_prepayment': '0.00',
        },
        'route': {
          'route_id': 'r-1',
          'route_date': '2026-08-25',
          'driver_id': 'd-1',
          'driver_full_name': 'Алишер Каримов',
        },
      };

  group('Префиксные ключи во вложенных объектах', () {
    test('заказчик и маршрут читаются так же, как из коротких ключей', () {
      final order = Order.fromJson(prefixedOrderJson());

      // На этой форме карточка оставалась без имени, телефона и адреса:
      // заказ есть, а чей он — непонятно.
      expect(order.customerId, 'c-1');
      expect(order.customerName, 'Кафе «Nasiba»');
      expect(order.customerPhone, '+998712001122');
      expect(order.customerAddress, 'ул. Амир Темур, 12');
      expect(order.routeId, 'r-1');
      expect(order.routeDate, DateTime(2026, 8, 25));
      expect(order.driverId, 'd-1');
    });

    test('имя водителя берётся из маршрута, а не только из корня', () {
      // Плоского `driver_full_name` в новой форме нет вовсе.
      expect(Order.fromJson(prefixedOrderJson()).driverFullName,
          'Алишер Каримов');
    });

    test('короткие ключи по-прежнему понимаются', () {
      // Сборка живёт в сторах месяцами и смотрит то на новый стенд, то на
      // прежний — обе формы обязаны читаться одинаково.
      final short = Order.fromJson(orderJson());
      final prefixed = Order.fromJson(prefixedOrderJson());

      expect(short.customerName, prefixed.customerName);
      expect(short.routeId, prefixed.routeId);
      expect(short.routeDate, prefixed.routeDate);
    });
  });

  group('Заказ из списка', () {
    test('вложенные заказчик и маршрут разбираются', () {
      final order = Order.fromJson(orderJson());

      expect(order.number, 10432);
      expect(order.purpose, OrderPurpose.delivery19l);
      expect(order.customerName, 'Кафе «Nasiba»');
      expect(order.customerAddress, 'ул. Амир Темур, 12');
      expect(order.routeId, 'r-1');
      // Дата маршрута приходит без времени и разбирается как локальная —
      // это день, а не момент.
      expect(order.routeDate, DateTime(2026, 8, 25));
      expect(order.driverId, 'd-1');
      expect(order.hasNoDriver, isFalse);
    });

    test('деньги и количества доходят до модели', () {
      final order = Order.fromJson(orderJson());

      expect(order.deliveredCapsules, 5);
      expect(order.returnedCapsules, 4);
      expect(order.damagedCapsules, 1);
      expect(order.capsuleBalanceAfter, 6);
      expect(order.orderAmount, 115000);
      expect(order.waterPriceApplied, 15000);
      expect(order.damagedFineApplied, 40000);
      expect(order.isCompleted, isTrue);
    });

    test('плоский ответ понимается наравне с вложенным', () {
      // Контракт в docs/tz описывает эти поля плоскими, а сервер отдаёт их
      // объектами. Расхождение живое, и переезд контракта не должен
      // опустошить карточку.
      final flat = orderJson()
        ..remove('customer')
        ..remove('route');
      final order = Order.fromJson({
        ...flat,
        'customer_id': 'c-1',
        'customer_full_name': 'Кафе «Nasiba»',
        'customer_address': 'ул. Амир Темур, 12',
        'route_id': 'r-1',
        'route_date': '2026-08-25',
        'driver_id': 'd-1',
      });

      expect(order.customerName, 'Кафе «Nasiba»');
      expect(order.routeId, 'r-1');
      expect(order.driverId, 'd-1');
    });

    test('незнакомая цель не роняет заказ, а читается как доставка', () {
      final order = Order.fromJson(orderJson({'purpose': 'ice_cream'}));
      expect(order.purpose, OrderPurpose.delivery19l);
    });

    test('нет денег — это не ноль, а «ещё не считали»', () {
      final pending = orderJson({
        'status': 'pending',
        'order_amount': null,
        'water_price_applied': null,
        'payment_method': null,
        'completed_at': null,
      });
      final order = Order.fromJson(pending);

      // Ноль здесь читался бы как «привезли бесплатно».
      expect(order.orderAmount, isNull);
      expect(order.waterPriceApplied, isNull);
      expect(order.paymentMethod, isNull);
      expect(order.isCompleted, isFalse);
    });

    test('старый ответ без новых полей разбирается целиком', () {
      final legacy = {
        'id': 'o-2',
        'status': 'delivered',
        'customer_id': 'c-1',
        'customer_full_name': 'Кафе',
        'created_at': '2026-08-25T08:00:00Z',
      };
      final order = Order.fromJson(legacy);

      expect(order.id, 'o-2');
      expect(order.number, 0);
      expect(order.purpose, OrderPurpose.delivery19l);
      expect(order.returnedCapsules, isNull);
      expect(order.hasNoDriver, isTrue);
    });

    test('заказ без id пропускается, а не роняет страницу', () {
      expect(() => Order.fromJson({'status': 'pending'}), throwsFormatException);
    });
  });

  group('Точка внутри маршрута', () {
    Map<String, dynamic> stopJson([Map<String, dynamic> extra = const {}]) => {
          'id': 's-1',
          'customer_id': 'c-1',
          'customer_full_name': 'Кафе',
          'customer_address': 'Чиланзар',
          'customer_phone': '+998901234567',
          'status': 'delivered',
          'delivered_bottles': 3,
          'payment_amount': '0.00',
          'payment_method': 'debt',
          'payment_photo': null,
          'completed_at': '2026-08-25T10:00:00Z',
          'sequence': 2,
          'customer_cooler_count': 2,
          ...extra,
        };

    test('способ оплаты и кулеры разбираются', () {
      final stop = RouteStop.fromJson(stopJson());

      // «В долг» спрашиваем у поля, а не угадываем по нулевой сумме: нулевая
      // сумма сама по себе долга не означает.
      expect(stop.paymentMethod, PaymentMethod.debt);
      expect(stop.isDebt, isTrue);
      expect(stop.customerCoolerCount, 2);
      expect(stop.customerHasCooler, isTrue);
      expect(stop.sequence, 2);
    });

    test('старые имена полей понимаются наравне с новыми', () {
      final legacy = stopJson()
        ..remove('sequence')
        ..remove('customer_cooler_count');
      final stop = RouteStop.fromJson({
        ...legacy,
        'order': 7,
        'customer_has_cooler': true,
      });

      expect(stop.sequence, 7);
      expect(stop.customerCoolerCount, 1);
    });

    test('заказчик приходит вложенным объектом', () {
      // Так точку отдаёт нынешний сервер: плоских `customer_*` в записи нет
      // вовсе, и раньше водитель получал список карточек без имени и адреса.
      final stop = RouteStop.fromJson({
        'id': 's-1',
        'status': 'pending',
        'sequence': 1,
        'order_amount': '60000.00',
        'customer': {
          'customer_id': 'c-1',
          'customer_full_name': 'Кафе Тест',
          'customer_phone': '+998900000002',
          'customer_address': 'ул. Тестовая, 1',
          'customer_cooler_count': 3,
        },
      });

      expect(stop.customerId, 'c-1');
      expect(stop.customerName, 'Кафе Тест');
      expect(stop.customerPhone, '+998900000002');
      expect(stop.customerAddress, 'ул. Тестовая, 1');
      expect(stop.customerCoolerCount, 3);
      // `payment_amount` переименован в `order_amount`; без этого сумма
      // показывалась пустой у каждой точки.
      expect(stop.paymentAmount, 60000);
    });

    test('плоская и вложенная формы дают одинаковую точку', () {
      final flat = RouteStop.fromJson(stopJson());
      final nested = RouteStop.fromJson({
        'id': 's-1',
        'status': 'delivered',
        'delivered_bottles': 3,
        'payment_amount': '0.00',
        'payment_method': 'debt',
        'completed_at': '2026-08-25T10:00:00Z',
        'sequence': 2,
        'customer': {
          'customer_id': 'c-1',
          'customer_full_name': 'Кафе',
          'customer_address': 'Чиланзар',
          'customer_phone': '+998901234567',
          'customer_cooler_count': 2,
        },
      });

      expect(nested.customerName, flat.customerName);
      expect(nested.customerAddress, flat.customerAddress);
      expect(nested.customerPhone, flat.customerPhone);
      expect(nested.customerCoolerCount, flat.customerCoolerCount);
      expect(nested.paymentMethod, flat.paymentMethod);
    });

    test('незнакомый способ оплаты точку не теряет', () {
      final stop = RouteStop.fromJson(stopJson({'payment_method': 'crypto'}));

      expect(stop.paymentMethod, isNull);
      expect(stop.deliveredCapsules, 3);
    });
  });

  group('Маршрут: точки лежат под двумя разными ключами', () {
    Map<String, dynamic> routeJson(String key) => {
          'id': 'r-1',
          'date': '2026-08-25',
          'status': 'in_progress',
          'completed_count': 1,
          'total_customers': 2,
          key: [
            {
              'id': 's-1',
              'customer_full_name': 'Кафе',
              'status': 'delivered',
            },
            {
              'id': 's-2',
              'customer_full_name': 'Офис',
              'status': 'pending',
            },
          ],
        };

    test('новый ключ `orders` разбирается', () {
      expect(RouteDetail.fromJson(routeJson('orders')).stops, hasLength(2));
    });

    test('старый `route_customers` — тоже', () {
      // Именно на этом расхождении маршрут однажды открылся пустым: сервер
      // переименовал ключ, а клиент читал только прежний.
      final route = RouteDetail.fromJson(routeJson('route_customers'));
      expect(route.stops, hasLength(2));
      expect(route.stops.first.customerName, 'Кафе');
    });
  });
}

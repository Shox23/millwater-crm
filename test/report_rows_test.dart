import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/report_rows.dart';
import 'package:crm_millwater/data/models/reports_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Строки трёх новых отчётов.
///
/// Сервер удалил `GET /admin/reports/summary` и заменил его тремя разрезами.
/// Форма ответа у них непривычная для этого API — голый массив, — а поля
/// частью денежные строками, частью необязательные.
void main() {
  group('Общий отчёт', () {
    test('разбирает строку доставки', () {
      final row = GeneralReportRow.fromJson({
        'date': '2026-09-04',
        'driver_full_name': 'Смоук Водителев',
        'customer_name_or_address': 'Кафе Тест',
        'delivered_bottles': 3,
        'returned_bottles': 2,
        'damaged_bottles': 1,
        'cooler_count': 2,
        'order_amount': '60000.00',
      });

      expect(row.date, DateTime(2026, 9, 4));
      expect(row.driverName, 'Смоук Водителев');
      expect(row.customer, 'Кафе Тест');
      expect(row.deliveredCapsules, 3);
      expect(row.damagedCapsules, 1);
      // Деньги приходят строкой, наружу отдаются суммами.
      expect(row.orderAmount, 60000);
    });

    test('пустая строка не роняет разбор', () {
      // Пропущенное поле у отчёта дороже, чем у списка: строка отчёта — это
      // деньги за период, и потерять её целиком из-за одного поля нельзя.
      final row = GeneralReportRow.fromJson(const {});

      expect(row.driverName, '');
      expect(row.deliveredCapsules, 0);
      expect(row.orderAmount, 0);
    });
  });

  group('Отчёт по заказчикам', () {
    test('разбирает итог заказчика', () {
      final row = CustomerReportRow.fromJson({
        'customer_id': 'c-1',
        'full_name': 'Кафе Тест',
        'address': 'ул. Тестовая, 1',
        'phone': '+998900000002',
        'bulk_liters_purchased': 15,
        'damaged_bottles_count': 1,
        'bottles_purchased_in_period': 4,
        'current_bottle_balance': 6,
        'current_cooler_count': 2,
        'prepayment': '0.00',
        'debt': '45000.00',
        'total_realization': '115000.00',
      });

      expect(row.customerId, 'c-1');
      expect(row.capsulesPurchased, 4);
      // Опт сервер сводит к литрам, а не к бутылям, — на экране это разные
      // вещи, и путать их нельзя.
      expect(row.bulkLiters, 15);
      expect(row.debt, 45000);
      expect(row.total, 115000);
    });
  });

  group('Отчёт по водителям', () {
    test('разбирает строку заказа', () {
      final row = DriverReportRow.fromJson({
        'route_id': 'r-1',
        'route_date': '2026-09-04',
        'driver_id': 'd-1',
        'driver_full_name': 'Тест Флоу',
        'customer_name_or_address': 'Hoty doggy',
        'delivered_bottles': 0,
        'returned_bottles': 0,
        'bottle_balance_after': null,
        'order_amount': '0.00',
        'payment_method': 'cash',
        'purpose': 'pickup',
        'bulk_liters_sold_count': 0,
        'bulk_sale_amount': '0.00',
        'route_expenses_total': '42000.00',
      });

      expect(row.purpose, OrderPurpose.pickup);
      expect(row.paymentMethod, PaymentMethod.cash);
      // `null` в остатке — не ноль: у вывоза остатка просто нет.
      expect(row.capsuleBalanceAfter, isNull);
      expect(row.routeExpenses, 42000);
    });

    test('незнакомая цель и способ оплаты не роняют строку', () {
      final row = DriverReportRow.fromJson({
        'purpose': 'space_delivery',
        'payment_method': 'bitcoin',
      });

      expect(row.purpose, OrderPurpose.delivery19l);
      expect(row.paymentMethod, isNull);
    });
  });

  group('Сводка экрана отчётов', () {
    test('выручка и доставки складываются из строк общего отчёта', () {
      final summary = ReportsSummary.from(
        [
          GeneralReportRow.fromJson(
              {'order_amount': '60000.00', 'delivered_bottles': 3}),
          GeneralReportRow.fromJson(
              {'order_amount': '40000.00', 'delivered_bottles': 2}),
        ],
        const [],
      );

      expect(summary.revenue, 100000);
      expect(summary.deliveries, 2);
      expect(summary.capsulesDelivered, 5);
    });
  });
}

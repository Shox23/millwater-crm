import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/route_expense.dart';
import 'package:crm_millwater/data/models/route_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Касса маршрута и расходы водителя.
///
/// Деньги за маршрут раньше считались на клиенте — сложением сумм по точкам.
/// Теперь их считает сервер, и он видит больше: правки оплаты админом,
/// возвраты, расходы водителя. Локальный подсчёт остаётся запасным
/// вариантом, потому что сборка живёт в сторах месяцами и смотрит в том
/// числе на стенды без новых полей.
void main() {
  Map<String, dynamic> routeJson([Map<String, dynamic> extra = const {}]) => {
        'id': 'r-1',
        'date': '2026-09-02',
        'status': 'in_progress',
        'completed_count': 1,
        'total_customers': 2,
        'driver_id': 'd-1',
        'orders': [
          {
            'id': 's-1',
            'status': 'delivered',
            'order_amount': '40000.00',
            'payment_method': 'cash',
          },
          {
            'id': 's-2',
            'status': 'pending',
          },
        ],
        ...extra,
      };

  group('Касса маршрута', () {
    test('серверный подсчёт вытесняет локальный', () {
      final route = RouteDetail.fromJson(routeJson({
        'cash_collected': '95000.00',
        'cashless_collected': '20000.00',
        'debt_amount': '15000.00',
        'expenses_total': '35000.00',
        'cash_balance': '60000.00',
      }));

      expect(route.cashCollected, 95000);
      expect(route.cashlessCollected, 20000);
      expect(route.debtAmount, 15000);
      expect(route.expensesTotal, 35000);
      expect(route.cashBalance, 60000);
      // Сервер видит правки оплаты и возвраты, которых в точках не видно.
      expect(route.collected, 95000);
    });

    test('без серверных полей сумма считается по точкам', () {
      final route = RouteDetail.fromJson(routeJson());

      expect(route.cashCollected, isNull);
      expect(route.cashBalance, isNull);
      // Запасной вариант: иначе на старом стенде касса показала бы ноль.
      expect(route.collected, 40000);
    });

    test('касса приходит и в списке маршрутов', () {
      final item = RouteListItem.fromJson({
        'id': 'r-1',
        'date': '2026-09-02',
        'status': 'in_progress',
        'completed_count': 1,
        'total_customers': 2,
        'cash_collected': '95000.00',
        'expenses_total': '35000.00',
        'cash_balance': '60000.00',
      });

      expect(item.cashCollected, 95000);
      expect(item.expensesTotal, 35000);
      expect(item.cashBalance, 60000);
    });

    test('отрицательный остаток кассы — рабочее состояние', () {
      // Расход больше собранного разрешён: водитель заправился на свои.
      final route = RouteDetail.fromJson(routeJson({
        'cash_collected': '10000.00',
        'expenses_total': '35000.00',
        'cash_balance': '-25000.00',
      }));

      expect(route.cashBalance, -25000);
    });
  });

  group('Расход водителя', () {
    Map<String, dynamic> expenseJson([Map<String, dynamic> extra = const {}]) =>
        {
          'id': 'e-1',
          'route_id': 'r-1',
          'driver_id': 'd-1',
          'amount': '35000.00',
          'category': 'fuel',
          'comment': 'АЗС на Чиланзаре',
          'photo_url': 'https://crm.millwater.uz/media/expenses/e-1.jpg',
          'created_at': '2026-09-02T09:30:00Z',
          ...extra,
        };

    test('разбирается целиком', () {
      final expense = RouteExpense.fromJson(expenseJson());

      expect(expense.amount, 35000);
      expect(expense.category, ExpenseCategory.fuel);
      expect(expense.comment, 'АЗС на Чиланзаре');
      expect(expense.hasPhoto, isTrue);
    });

    test('незнакомая категория уходит в «Прочее», а не теряет расход', () {
      // Деньги потрачены независимо от того, знает ли клиент такую подпись.
      final expense =
          RouteExpense.fromJson(expenseJson({'category': 'parking'}));

      expect(expense.category, ExpenseCategory.other);
      expect(expense.amount, 35000);
    });

    test('без чека и комментария — обычный расход', () {
      final expense = RouteExpense.fromJson(expenseJson({
        'comment': null,
        'photo_url': null,
      }));

      expect(expense.hasPhoto, isFalse);
      expect(expense.comment, isNull);
    });
  });

  group('Выручка маршрута', () {
    RouteDetail route({int? cash, int? cashless, List<RouteStop> stops = const []}) =>
        RouteDetail(
          id: 'r-1',
          date: DateTime(2026, 9, 4),
          status: RouteStatus.completed,
          completedCount: stops.length,
          totalCustomers: stops.length,
          stops: stops,
          cashCollected: cash,
          cashlessCollected: cashless,
        );

    test('складывает наличные с безналом', () {
      // Шапка маршрута подписана «Собрано»: одними наличными она занижала
      // день на весь безнал — карта и перевод тоже выручка, просто ушли
      // на счёт компании.
      final r = route(cash: 15000, cashless: 96000);

      expect(r.revenue, 111000);
      // Сдать водителю при этом надо только наличные.
      expect(r.collected, 15000);
    });

    test('без кассы с сервера считает по точкам', () {
      // Старый стенд блока кассы не отдаёт: способа оплаты там не разобрать,
      // а принятые деньги и есть вся выручка.
      final r = route(stops: [
        RouteStop(
          id: 's-1',
          customerId: 'c-1',
          customerName: 'Кафе',
          customerAddress: 'Адрес',
          customerPhone: '+998901234567',
          status: DeliveryStatus.delivered,
          paymentAmount: 60000,
        ),
      ]);

      expect(r.revenue, 60000);
    });

    test('нулевая касса — это ноль, а не подсчёт по точкам', () {
      // Сервер сказал «наличных ноль, безнала ноль» — верим ему, а не
      // складываем точки заново.
      final r = route(cash: 0, cashless: 0, stops: [
        RouteStop(
          id: 's-1',
          customerId: 'c-1',
          customerName: 'Кафе',
          customerAddress: 'Адрес',
          customerPhone: '+998901234567',
          status: DeliveryStatus.delivered,
          paymentAmount: 60000,
        ),
      ]);

      expect(r.revenue, 0);
    });
  });
}

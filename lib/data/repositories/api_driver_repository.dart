import 'package:dio/dio.dart';

import '../../core/utils/money_parser.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/order.dart';
import '../models/result_page.dart';
import '../models/route_expense.dart';
import '../models/route_from_orders.dart';
import '../models/route_models.dart';
import '../network/api_envelope.dart';
import 'driver_repository.dart';

/// Реализация водительской части поверх Water CRM API (Dio).
///
/// Отличия от админских эндпоинтов: списки приходят голым массивом (без
/// пагинации), в маршрутах нет полей водителя (он и так «свой»), а завершение
/// доставки принимает `multipart/form-data`, а не JSON.
class ApiDriverRepository implements DriverRepository {
  ApiDriverRepository(this._dio);

  final Dio _dio;

  /// Размер страницы у списка заказов — единственного пагинированного ответа
  /// водительской части. Потолок сервера — сотня.
  static const int _pageSize = 100;

  @override
  Future<List<RouteListItem>> getMyRoutes() async {
    final res = await _dio.get('/driver/routes');
    // Маршрут, который не разобрался, пропускается — остальные водитель
    // должен увидеть. См. `parseList`.
    final live = parseList(unwrapData(res.data), RouteListItem.fromJson);

    // `/driver/routes` отдаёт только `in_progress`: закрыв последнюю точку,
    // водитель терял весь день вместе с кассой. Историю достраиваем из его
    // заказов — они видны за всё время. См. `route_from_orders.dart`.
    final known = live.map((r) => r.id).toSet();
    final history = <RouteListItem>[];
    try {
      for (final group in groupByRoute(await _allMyOrders())) {
        final item = routeListItemFromOrders(group);
        if (known.add(item.id)) history.add(item);
      }
    } catch (_) {
      // История — дополнение, а не замена: её провал не должен стоить
      // водителю сегодняшнего маршрута, ради которого он и открыл экран.
    }

    return [...live, ...history];
  }

  @override
  Future<RouteDetail?> getMyRoute(String id) async {
    try {
      final res = await _dio.get('/driver/routes/$id');
      return RouteDetail.fromJson(asMap(res.data));
    } on DioException catch (e) {
      // 404 у своего же маршрута означает не «нет такого», а «уже не
      // `in_progress`». Собираем карточку из заказов и расходов: расходы
      // сервер по завершённому маршруту отдаёт, в отличие от него самого.
      if (e.response?.statusCode != 404) rethrow;

      final orders = await _allMyOrders(routeId: id);
      if (orders.isEmpty) return null;

      final expenses = await getRouteExpenses(id)
          .catchError((_) => const <RouteExpense>[]);
      return routeDetailFromOrders(orders, expenses: expenses);
    }
  }

  /// Все заказы водителя, обходя страницы.
  Future<List<Order>> _allMyOrders({String? routeId}) async {
    final all = <Order>[];
    for (var page = 1; page <= 20; page++) {
      final chunk = await getMyOrders(page: page, routeId: routeId);
      all.addAll(chunk.items);
      if (!chunk.hasMore) break;
    }
    return all;
  }

  @override
  Future<ResultPage<Order>> getMyOrders({
    int page = 1,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? customerId,
    String? routeId,
    DeliveryStatus? status,
    OrderPurpose? purpose,
    PaymentMethod? paymentMethod,
    String? search,
  }) async {
    final res = await _dio.get('/driver/orders', queryParameters: {
      ...orderFilterQuery(
        dateFrom: dateFrom,
        dateTo: dateTo,
        customerId: customerId,
        routeId: routeId,
        status: status,
        purpose: purpose,
        paymentMethod: paymentMethod,
        search: search,
      ),
      'page': page,
      'page_size': _pageSize,
    });

    final data = unwrapData(res.data);
    final paginated = data is Map<String, dynamic>;
    final items = parseList(
      paginated ? data['items'] : data,
      Order.fromJson,
    );
    final pages = paginated ? intOr(data['pages'], 1) : 1;

    return ResultPage(
      items: items,
      page: page,
      // Пустая страница обрывает обход даже там, где сервер обещает ещё, —
      // иначе список догружал бы пустоту до упора.
      hasMore: items.isNotEmpty && page < pages,
      total: paginated ? intOr(data['total'], items.length) : items.length,
    );
  }

  @override
  Future<Order?> getMyOrder(String id) async {
    final res = await _dio.get('/driver/orders/$id');
    return Order.fromJson(asMap(res.data));
  }

  @override
  Future<void> updateDeliveryStatus({
    required String stopId,
    required DeliveryStatus status,
  }) async {
    await _dio.patch(
      '/driver/routes/customers/$stopId/status',
      data: {'status': status.toJson()},
    );
  }

  @override
  Future<void> cancelOrder({required String orderId, String? reason}) =>
      // Идентификатор тот же, что у точки маршрута: заказ и точка — одна
      // запись (см. `completeDelivery`).
      _dio.post(
        '/driver/orders/$orderId/cancel',
        data: cancelOrderBody(reason),
      );

  @override
  Future<void> completeRoute(String routeId, {String? idempotencyKey}) =>
      _dio.post(
        '/driver/routes/$routeId/complete',
        options: Options(headers: {'Idempotency-Key': ?idempotencyKey}),
      );

  @override
  Future<void> completeDelivery({
    required String stopId,
    required OrderPurpose purpose,
    required int amount,
    required PaymentMethod method,
    int capsules = 0,
    int returnedCapsules = 0,
    int returnedFullCapsules = 0,
    int damagedCapsules = 0,
    int? bottleBalance,
    int bulk5lCount = 0,
    int? bulk5lPrice,
    int bulk10lCount = 0,
    int? bulk10lPrice,
    int pickedCoolers = 0,
    int pickedBottles = 0,
    String? photoPath,
    String? idempotencyKey,
    double? latitude,
    double? longitude,
  }) async {
    final form = FormData.fromMap({
      'purpose': purpose.toJson(),
      'payment_amount': MoneyParser.toApi(amount),
      'payment_method': method.toJson(),
      'delivered_bottles': capsules,
      'returned_bottles': returnedCapsules,
      // Полные капсулы — только когда вернули: старый стенд поля не знает,
      // а лишний ноль в multipart ему ни к чему.
      if (returnedFullCapsules > 0) 'returned_full_bottles': returnedFullCapsules,
      'damaged_bottles': damagedCapsules,
      // Без этого поля сервер отвечает 500, хотя в схеме оно необязательное;
      // у вывоза и опта остаток не меняется, и слать его незачем.
      'bottle_balance': ?bottleBalance,
      // Опт: количество без цены сервер отвергает (422), поэтому цена уходит
      // только вместе с ненулевым количеством.
      if (bulk5lCount > 0) ...{
        'bulk_5l_count': bulk5lCount,
        'bulk_5l_price': MoneyParser.toApi(bulk5lPrice ?? 0),
      },
      if (bulk10lCount > 0) ...{
        'bulk_10l_count': bulk10lCount,
        'bulk_10l_price': MoneyParser.toApi(bulk10lPrice ?? 0),
      },
      if (pickedCoolers > 0) 'picked_coolers': pickedCoolers,
      if (pickedBottles > 0) 'picked_bottles': pickedBottles,
      if (photoPath != null)
        'payment_photo': await MultipartFile.fromFile(photoPath),
      // Только парой: одна координата без второй точку не задаёт, а поле
      // с половиной данных сервер будет вынужден отбрасывать сам.
      if (latitude != null && longitude != null) ...{
        'latitude': latitude,
        'longitude': longitude,
      },
    });

    // Путь сменился вместе с переименованием точек в заказы: прежний
    // `/driver/routes/customers/{id}/complete` сервер больше не знает и
    // отвечает 404. Идентификатор тот же — таблицу переименовали, не
    // пересоздали.
    await _dio.post(
      '/driver/routes/orders/$stopId/complete',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        headers: {'Idempotency-Key': ?idempotencyKey},
      ),
    );
  }

  @override
  Future<List<RouteExpense>> getRouteExpenses(String routeId) async {
    final res = await _dio.get('/driver/routes/$routeId/expenses');
    return parseList(unwrapData(res.data), RouteExpense.fromJson);
  }

  @override
  Future<RouteExpense> addExpense({
    required String routeId,
    required int amount,
    required ExpenseCategory category,
    String? comment,
    String? photoPath,
    String? idempotencyKey,
  }) async {
    final form = FormData.fromMap({
      'amount': MoneyParser.toApi(amount),
      'category': category.toJson(),
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
      if (photoPath != null) 'photo': await MultipartFile.fromFile(photoPath),
    });

    final res = await _dio.post(
      '/driver/routes/$routeId/expenses',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        headers: {'Idempotency-Key': ?idempotencyKey},
      ),
    );
    return RouteExpense.fromJson(asMap(res.data));
  }

  @override
  Future<void> deleteExpense(String expenseId) =>
      _dio.delete('/driver/expenses/$expenseId');
}

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/observability/observability.dart';
import '../../core/utils/money_parser.dart';
import '../models/customer.dart';
import '../models/driver.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/order.dart';
import '../models/price_settings.dart';
import '../models/report_export.dart';
import '../models/report_rows.dart';
import '../models/result_page.dart';
import '../models/route_expense.dart';
import '../models/route_models.dart';
import '../network/api_envelope.dart';
import 'crm_repository.dart';

/// Реализация репозитория поверх Water CRM API (Dio).
///
/// Контракт сверен с боевым сервером: успешные ответы приходят «голыми»
/// (без конверта), списки — с пагинацией `{items,total,page,page_size,pages}`,
/// денежные значения — строками вида "20000.00".
class ApiCrmRepository implements CrmRepository {
  ApiCrmRepository(this._dio);

  final Dio _dio;

  /// Размер страницы для списочных запросов.
  static const int _pageSize = 100;

  /// Дата в формате `YYYY-MM-DD`, как ожидают query-параметры API.
  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Заголовок `Idempotency-Key`, если ключ задан.
  ///
  /// Отдельный хелпер, а не литерал в каждом методе: пропущенный заголовок
  /// молча превращает повтор в дубль записи, и заметить это негде.
  static Options? _idempotent(String? key) =>
      key == null ? null : Options(headers: {'Idempotency-Key': key});

  /// Разбирает ответ списка: элементы и сколько всего страниц.
  ///
  /// Терпит оба вида ответа — пагинированный `{items,total,page,...}` и голый
  /// массив (`/admin/prices/history` отдаёт именно его). У массива страница
  /// всегда одна.
  ({List<T> items, int pages}) _page<T>(
    Response res,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final data = unwrapData(res.data);
    final paginated = data is Map<String, dynamic>;
    final list = paginated ? data['items'] : data;
    return (
      // Запись, которую не удалось разобрать, пропускается. Раньше одно поле
      // неожиданного типа роняло разбор всей страницы, и вместо девяноста
      // девяти нормальных заказчиков пользователь видел общую ошибку.
      items: parseList(
        list,
        fromJson,
        onSkipped: (count) => _reportSkipped(count, res.requestOptions.path),
      ),
      pages: paginated ? intOr(data['pages'], 1) : 1,
    );
  }

  /// Молча терять записи нельзя: пропуск виден только по жалобе, а причина —
  /// расхождение ответа со схемой — сама не всплывёт.
  static void _reportSkipped(int count, String path) {
    Observability.breadcrumb(
      category: 'parse',
      message: 'пропущено записей при разборе: $count',
      data: {'path': path, 'skipped': count},
    );
  }

  /// Разбирает непагинированный список.
  List<T> _items<T>(Response res, T Function(Map<String, dynamic>) fromJson) =>
      _page(res, fromJson).items;

  /// Забирает одну страницу списка.
  ///
  /// На этом же запросе стоит и полная выборка [_all] — разбор ответа у них
  /// общий, различается только то, останавливаться ли после первой страницы.
  Future<ResultPage<T>> _pageOf<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    required int page,
    Map<String, dynamic> query = const {},
  }) async {
    final res = await _dio.get(path, queryParameters: {
      ...query,
      'page': page,
      'page_size': _pageSize,
    });
    final data = unwrapData(res.data);
    final (items: items, pages: pages) = _page(res, fromJson);

    return ResultPage(
      items: items,
      page: page,
      // Пустая страница обрывает обход даже там, где сервер обещает ещё:
      // иначе список догружал бы пустоту до упора.
      hasMore: items.isNotEmpty && page < pages,
      total: data is Map<String, dynamic> ? data['total'] as int? ?? items.length : items.length,
    );
  }

  /// Забирает список целиком, обходя страницы.
  ///
  /// Одним запросом «всё» не получить: `page_size` у сервера ограничен сотней
  /// (в схеме `maximum: 100`). Раньше бралась только первая страница, и на
  /// 101-м заказчике список молча обрывался — без ошибки, без признака в
  /// интерфейсе, заметить можно было только по жалобе.
  ///
  /// [maxPages] — предохранитель от бесконечного цикла, если сервер вдруг
  /// начнёт отдавать `pages` больше, чем страниц на самом деле.
  Future<List<T>> _all<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic> query = const {},
    int maxPages = 50,
  }) async {
    final all = <T>[];

    for (var page = 1; page <= maxPages; page++) {
      final res = await _dio.get(path, queryParameters: {
        ...query,
        'page': page,
        'page_size': _pageSize,
      });
      final (items: items, pages: pages) = _page(res, fromJson);
      all.addAll(items);
      if (items.isEmpty || page >= pages) break;
    }

    return all;
  }

  // ---- Цены ----
  @override
  Future<PriceSettings> getPrices() async {
    final res = await _dio.get('/admin/prices/current');
    return PriceSettings.fromJson(asMap(res.data));
  }

  @override
  Future<List<PriceSettings>> getPriceHistory() async {
    final res = await _dio.get('/admin/prices/history');
    final items = _items(res, PriceSettings.fromJson);
    // Порядок сервер не обещает — раскладываем сами, новые сверху.
    return items..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<PriceSettings> setPrices({
    required int capsulePrice,
    required int damagedBottleFine,
    String? idempotencyKey,
  }) async {
    final res = await _dio.post(
      '/admin/prices',
      data: {
        'water_price': MoneyParser.toApi(capsulePrice),
        'damaged_bottle_fine': MoneyParser.toApi(damagedBottleFine),
      },
      options: _idempotent(idempotencyKey),
    );
    return PriceSettings.fromJson(asMap(res.data));
  }

  // ---- Водители ----
  @override
  Future<List<Driver>> getDrivers({String? search}) => _all(
        '/admin/drivers',
        Driver.fromJson,
        query: {
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );

  @override
  Future<ResultPage<Driver>> getDriversPage({int page = 1, String? search}) =>
      _pageOf(
        '/admin/drivers',
        Driver.fromJson,
        page: page,
        query: {
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );

  @override
  Future<Driver?> getDriver(String id) async {
    final res = await _dio.get('/admin/drivers/$id');
    return Driver.fromJson(asMap(res.data));
  }

  @override
  Future<Driver> addDriver({
    required String fullName,
    required String phone,
    required String password,
    String? idempotencyKey,
  }) async {
    // Пароль уходит прямо в `CreateDriver` — учётка сразу рабочая. Раньше это
    // делалось вторым запросом в `/auth/set-password`, и создание водителя
    // было неатомарным: упавший второй шаг оставлял учётку без пароля.
    final res = await _dio.post(
      '/admin/drivers',
      data: {
        'full_name': fullName,
        'phone': phone,
        'password': password,
      },
      options: _idempotent(idempotencyKey),
    );
    return Driver.fromJson(asMap(res.data));
  }

  @override
  Future<Driver> updateDriver(Driver driver) async {
    final res = await _dio.patch(
      '/admin/drivers/${driver.id}',
      data: driver.toUpdateJson(),
    );
    return Driver.fromJson(asMap(res.data));
  }

  @override
  Future<void> deleteDriver(String id) => _dio.delete('/admin/drivers/$id');

  // ---- Заказчики ----
  @override
  Future<List<Customer>> getCustomers({
    String? search,
    bool? hasDebt,
    bool? isActive,
  }) =>
      _all(
        '/admin/customers',
        Customer.fromJson,
        query: _customerQuery(
          search: search,
          hasDebt: hasDebt,
          isActive: isActive,
        ),
      );

  /// Параметры отбора заказчиков — одни и те же у полной выборки и страницы.
  ///
  /// Незаданный фильтр не отправляется вовсе: `has_debt=false` и «неважно» —
  /// разные вопросы, и пустое значение сервер разобрал бы как первый.
  ///
  /// Отбора по кулеру здесь нет: параметр `has_cooler` сервер убрал, а
  /// неизвестный query-параметр он молча игнорирует — то есть отправлять его
  /// было бы хуже, чем не отправлять, фильтр «работал» бы наощупь.
  Map<String, dynamic> _customerQuery({
    String? search,
    bool? hasDebt,
    bool? isActive,
  }) =>
      {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'has_debt': ?hasDebt,
        'is_active': ?isActive,
      };

  @override
  Future<ResultPage<Customer>> getCustomersPage({
    int page = 1,
    String? search,
    bool? hasDebt,
    bool? isActive,
  }) =>
      _pageOf(
        '/admin/customers',
        Customer.fromJson,
        page: page,
        query: _customerQuery(
          search: search,
          hasDebt: hasDebt,
          isActive: isActive,
        ),
      );

  @override
  Future<Customer?> getCustomer(String id) async {
    final res = await _dio.get('/admin/customers/$id');
    return Customer.fromJson(asMap(res.data));
  }

  @override
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    String? phoneSecondary,
    required String address,
    String? comment,
    int coolerCount = 0,
    int capsuleBalance = 0,
    int debt = 0,
    int prepayment = 0,
    int? customWaterPrice,
    DateTime? lastOrderDate,
    String? idempotencyKey,
  }) async {
    final res = await _dio.post(
      '/admin/customers',
      data: {
        'full_name': name,
        'phone': phone,
        'phone_secondary': ?phoneSecondary,
        'address': address,
        'comment': ?comment,
        'cooler_count': coolerCount,
        // Сколько капсул уже на руках у нового заказчика: тара, которую он
        // держит с прошлого поставщика, иначе всплыла бы недостачей.
        'bottle_balance': capsuleBalance,
        'debt': MoneyParser.toApi(debt),
        'prepayment': MoneyParser.toApi(prepayment),
        // Ключ отправляем всегда: `null` — это «по общему прайсу», и пропуск
        // поля значил бы то же самое, но сервер о намерении не узнал бы.
        'custom_water_price':
            customWaterPrice == null ? null : MoneyParser.toApi(customWaterPrice),
        // Одним днём, без зоны — см. `Customer.lastOrderDateWire`.
        if (lastOrderDate != null)
          'last_order_date': Customer.lastOrderDateWire(lastOrderDate),
      },
      options: _idempotent(idempotencyKey),
    );
    return Customer.fromJson(asMap(res.data));
  }

  @override
  Future<Customer> updateCustomer(
    Customer customer, {
    bool balanceChanged = false,
    bool capsulesChanged = false,
    bool lastOrderDateChanged = false,
  }) async {
    final res = await _dio.patch(
      '/admin/customers/${customer.id}',
      data: customer.toUpdateJson(
        includeBalance: balanceChanged,
        includeCapsules: capsulesChanged,
        includeLastOrderDate: lastOrderDateChanged,
      ),
    );
    return Customer.fromJson(asMap(res.data));
  }

  @override
  Future<void> deleteCustomer(String id) => _dio.delete('/admin/customers/$id');

  // ---- Маршруты ----
  @override
  Future<List<RouteListItem>> getRoutes({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? driverId,
    RouteStatus? status,
  }) =>
      _all(
        '/admin/routes',
        RouteListItem.fromJson,
        query: {
          if (dateFrom != null) 'date_from': _formatDate(dateFrom),
          if (dateTo != null) 'date_to': _formatDate(dateTo),
          'driver_id': ?driverId,
          'status': ?status?.wire,
        },
      );

  @override
  Future<RouteDetail?> getRoute(String id) async {
    final res = await _dio.get('/admin/routes/$id');
    return RouteDetail.fromJson(asMap(res.data));
  }

  @override
  Future<RouteDetail> createRoute({
    required DateTime date,
    required List<RouteOrderInput> orders,
    String? driverId,
    OrderPurpose purpose = OrderPurpose.delivery19l,
    String? idempotencyKey,
  }) async {
    final res = await _dio.post(
      '/admin/routes',
      data: {
        // Ключа нет вовсе, когда водителя не назначили: сервер ждёт
        // отсутствия поля, а не `null`.
        'driver_id': ?driverId,
        'date': _formatDate(date),
        // Прежний `customer_ids` сервер не отвергает, а тихо отбрасывает
        // (`extra: ignore`), и маршрут создавался пустым — без ошибки, без
        // признака в интерфейсе, заметно только по жалобе водителя.
        'customer_orders': [
          for (final order in orders)
            {
              'customer_id': order.customerId,
              // Своя цель точки перебивает цель маршрута.
              'order_purpose': (order.purpose ?? purpose).toJson(),
              'sequence': ?order.sequence,
              // Задание водителю: сколько капсул везти. Только у доставки —
              // см. `RouteOrderInput.bottleSellCount`.
              'bottle_sell_count': ?order.bottleSellCount,
              // Договорная сумма за весь заказ; без неё считают по прайсу.
              if (order.customPrice != null)
                'order_custom_price': MoneyParser.toApi(order.customPrice!),
            },
        ],
      },
      options: _idempotent(idempotencyKey),
    );
    return RouteDetail.fromJson(asMap(res.data));
  }

  @override
  Future<void> deleteRoute(String id) => _dio.delete('/admin/routes/$id');

  @override
  Future<void> cancelRoute(String id) => _dio.post('/admin/routes/$id/cancel');

  @override
  Future<RouteDetail> updateRouteDate({
    required String routeId,
    required DateTime date,
  }) async {
    final res = await _dio.patch(
      '/admin/routes/$routeId',
      data: {'date': _formatDate(date)},
    );
    return RouteDetail.fromJson(asMap(res.data));
  }

  @override
  Future<void> assignDriver({
    required String routeId,
    required String driverId,
  }) =>
      _dio.patch('/admin/routes/$routeId/driver/$driverId');

  @override
  Future<void> addRouteCustomer({
    required String routeId,
    required String customerId,
    OrderPurpose purpose = OrderPurpose.delivery19l,
    int? bottleSellCount,
    int? customPrice,
  }) =>
      // Заказчик остаётся и в пути — ради старых сборок, — но сервер читает
      // его из тела вместе с целью заказа.
      _dio.post(
        '/admin/routes/$routeId/customers/$customerId',
        data: {
          'customer_id': customerId,
          'order_purpose': purpose.toJson(),
          // Ключа нет вовсе, когда задания не ставили: у вывоза и опта везти
          // нечего, и ноль там значил бы «привезти ноль капсул».
          'bottle_sell_count': ?bottleSellCount,
          if (customPrice != null)
            'order_custom_price': MoneyParser.toApi(customPrice),
        },
      );

  @override
  Future<void> removeRouteCustomer({
    required String routeId,
    required String customerId,
  }) =>
      _dio.delete('/admin/routes/$routeId/customers/$customerId');

  // ---- Заказы ----
  @override
  Future<ResultPage<Order>> getOrdersPage({
    int page = 1,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? customerId,
    String? driverId,
    String? routeId,
    DeliveryStatus? status,
    OrderPurpose? purpose,
    PaymentMethod? paymentMethod,
    String? search,
  }) =>
      _pageOf(
        '/admin/orders',
        Order.fromJson,
        page: page,
        query: orderFilterQuery(
          dateFrom: dateFrom,
          dateTo: dateTo,
          customerId: customerId,
          driverId: driverId,
          routeId: routeId,
          status: status,
          purpose: purpose,
          paymentMethod: paymentMethod,
          search: search,
        ),
      );

  @override
  Future<Order?> getOrder(String id) async {
    final res = await _dio.get('/admin/orders/$id');
    return Order.fromJson(asMap(res.data));
  }

  @override
  Future<void> moveOrderToRoute({
    required String orderId,
    required String targetRouteId,
  }) =>
      // Ровно один из вариантов: сервер отвергает тело, где заданы и маршрут,
      // и дата, — и тело, где не задано ничего.
      _dio.post(
        '/admin/orders/$orderId/move',
        data: {'target_route_id': targetRouteId},
      );

  @override
  Future<void> moveOrderToDate({
    required String orderId,
    required DateTime date,
    String? driverId,
  }) =>
      _dio.post(
        '/admin/orders/$orderId/move',
        data: {
          'order_date': _formatDate(date),
          // Водитель осмыслен только в этом варианте: с ним сервер ищет
          // маршрут этого водителя, без него — маршрут вообще без водителя.
          'driver_id': ?driverId,
        },
      );

  @override
  Future<void> updateOrderPayment({
    required String orderId,
    required int amount,
    required PaymentMethod method,
    String? note,
    String? photoPath,
  }) async {
    final form = FormData.fromMap({
      'amount': MoneyParser.toApi(amount),
      'payment_method': method.toJson(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (photoPath != null)
        'payment_photo': await MultipartFile.fromFile(photoPath),
    });

    await _dio.patch(
      '/admin/orders/$orderId/payment',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  @override
  Future<void> cancelOrder({required String orderId, String? reason}) =>
      _dio.post(
        '/admin/orders/$orderId/cancel',
        data: cancelOrderBody(reason),
      );

  // ---- Расходы ----
  @override
  Future<List<RouteExpense>> getRouteExpenses(String routeId) async {
    final res = await _dio.get('/admin/routes/$routeId/expenses');
    return parseList(unwrapData(res.data), RouteExpense.fromJson);
  }

  @override
  Future<ResultPage<RouteExpense>> getExpensesPage({
    int page = 1,
    String? driverId,
    DateTime? dateFrom,
    DateTime? dateTo,
    ExpenseCategory? category,
  }) =>
      _pageOf(
        '/admin/expenses',
        RouteExpense.fromJson,
        page: page,
        query: {
          'driver_id': ?driverId,
          if (dateFrom != null) 'date_from': formatApiDate(dateFrom),
          if (dateTo != null) 'date_to': formatApiDate(dateTo),
          if (category != null) 'category': category.toJson(),
        },
      );

  @override
  Future<void> deleteExpense(String expenseId) =>
      _dio.delete('/admin/expenses/$expenseId');

  // ---- Отчёты ----
  //
  // Три разреза одного периода. Пути и параметры отличаются только сегментом,
  // а разбор — типом строки, поэтому оба запроса собраны общими хелперами:
  // добавлять четвёртый отчёт иначе значило бы копировать всё целиком.

  @override
  Future<List<GeneralReportRow>> getGeneralReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) =>
      _report('general', GeneralReportRow.fromJson,
          dateFrom: dateFrom, dateTo: dateTo, driverId: driverId);

  @override
  Future<List<CustomerReportRow>> getCustomersReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) =>
      _report('customers', CustomerReportRow.fromJson,
          dateFrom: dateFrom, dateTo: dateTo, driverId: driverId);

  @override
  Future<List<DriverReportRow>> getDriversReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) =>
      _report('drivers', DriverReportRow.fromJson,
          dateFrom: dateFrom, dateTo: dateTo, driverId: driverId);

  @override
  Future<ReportExport> exportGeneralReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) =>
      _reportExport('general',
          dateFrom: dateFrom, dateTo: dateTo, driverId: driverId);

  @override
  Future<ReportExport> exportCustomersReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) =>
      _reportExport('customers',
          dateFrom: dateFrom, dateTo: dateTo, driverId: driverId);

  @override
  Future<ReportExport> exportDriversReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) =>
      _reportExport('drivers',
          dateFrom: dateFrom, dateTo: dateTo, driverId: driverId);

  /// Отчёт как список строк.
  ///
  /// Ответ — голый массив, без конверта `{items, total}`, в отличие от всех
  /// остальных списков этого API. `parseList` терпим: строка без обязательного
  /// поля пропускается, а не роняет весь отчёт.
  Future<List<T>> _report<T>(
    String kind,
    T Function(Map<String, dynamic>) fromJson, {
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) async {
    final res = await _dio.get(
      '/admin/reports/$kind',
      queryParameters: _reportQuery(dateFrom, dateTo, driverId),
    );
    return parseList(unwrapData(res.data), fromJson);
  }

  Future<ReportExport> _reportExport(
    String kind, {
    required DateTime dateFrom,
    required DateTime dateTo,
    String? driverId,
  }) async {
    final res = await _dio.get<List<int>>(
      '/admin/reports/$kind/export',
      queryParameters: _reportQuery(dateFrom, dateTo, driverId),
      // Тело — файл, а не JSON: разбирать его нечем и незачем.
      options: Options(responseType: ResponseType.bytes),
    );

    return ReportExport(
      bytes: Uint8List.fromList(res.data ?? const []),
      filename: _filenameFrom(res.headers) ??
          'millwater-$kind-${_formatDate(dateFrom)}_${_formatDate(dateTo)}.xlsx',
    );
  }

  /// Границы обязательны у всех трёх отчётов — без них сервер отвечает 422.
  Map<String, dynamic> _reportQuery(
    DateTime dateFrom,
    DateTime dateTo,
    String? driverId,
  ) =>
      {
        'date_from': _formatDate(dateFrom),
        'date_to': _formatDate(dateTo),
        'driver_id': ?driverId,
      };

  /// Имя файла из `Content-Disposition`, если сервер его прислал.
  ///
  /// Разбираем и `filename*=UTF-8''...` (RFC 5987, там имя процент-кодировано),
  /// и обычный `filename="..."`. Пропущенное расширение файлу не добавляем:
  /// заголовок либо есть и полон, либо мы собираем имя сами.
  static String? _filenameFrom(Headers headers) {
    final header = headers.value('content-disposition');
    if (header == null) return null;

    final extended =
        RegExp("filename\\*=UTF-8''([^;]+)", caseSensitive: false)
            .firstMatch(header);
    if (extended != null) {
      return Uri.decodeComponent(extended.group(1)!.trim());
    }

    final plain = RegExp('filename="?([^";]+)"?', caseSensitive: false)
        .firstMatch(header);
    return plain?.group(1)?.trim();
  }
}

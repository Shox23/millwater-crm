part of 'day_deliveries_bloc.dart';

enum DayDeliveriesStatus { initial, loading, ready, error }

/// Счётчики дня для ленты дат: столько-то из стольких, столько маршрутов.
class DayMeta extends Equatable {
  const DayMeta({this.done = 0, this.total = 0, this.routes = 0});

  final int done;
  final int total;
  final int routes;

  @override
  List<Object?> get props => [done, total, routes];
}

/// Строка таблицы: точка доставки вместе с маршрутом, из которого она взята.
///
/// Маршрут нужен целиком, а не одним идентификатором: в строке показывается
/// водитель, а по клику открывается карточка.
class DeliveryRow extends Equatable {
  const DeliveryRow({required this.route, required this.stop});

  final RouteDetail route;
  final RouteStop stop;

  /// Ожидаемая оплата за точку — капсулы × [capsulePrice].
  ///
  /// Нужна для «В долг за день»: сервер хранит принятую сумму, но не ту,
  /// которую должны были принять. Цена приходит параметром, а не берётся из
  /// сборки: этот экран открыт админом, а ему прайс доступен — считать по
  /// зашитому числу значило бы врать ровно с того дня, как цену поменяли.
  int expectedAmount(int capsulePrice) =>
      (stop.deliveredCapsules ?? 0) * capsulePrice;

  /// Доставлено, но денег не принято, — значит ушло в долг.
  ///
  /// Способа оплаты в ответе точки нет (`RouteStop` знает только сумму), так
  /// что «в долг» выводим из нулевой суммы. Если сервер начнёт отдавать
  /// `payment_method` — читать его напрямую и удалить этот вывод.
  bool get isDebt => stop.isCompleted && (stop.paymentAmount ?? 0) == 0;

  /// Район из адреса: всё до первой запятой.
  ///
  /// Отдельного поля у заказчика нет, а в адресах Ташкента район почти всегда
  /// стоит первым («Мирабад, ул. …»). Если запятой нет — район не показываем,
  /// вместо того чтобы выдавать за него начало улицы.
  String? get district {
    final comma = stop.customerAddress.indexOf(',');
    if (comma <= 0) return null;
    return stop.customerAddress.substring(0, comma).trim();
  }

  @override
  List<Object?> get props => [route.id, stop];
}

class DayDeliveriesState extends Equatable {
  const DayDeliveriesState({
    required this.date,
    this.status = DayDeliveriesStatus.initial,
    this.rows = const [],
    this.routesCount = 0,
    this.filter = DeliveryFilter.all,
    this.query = '',
    this.dayMeta = const {},
    this.capsulePrice = ProductConfig.capsulePrice,
  });

  /// Пять дней ленты: два назад, сегодня, два вперёд.
  ///
  /// Считается от сегодняшнего дня, а не от выбранного: лента неподвижна,
  /// иначе выбор соседнего дня уводил бы её вбок при каждом нажатии.
  static List<DateTime> dateWindow() {
    final today = dayOnly(DateTime.now());
    return [for (var i = -2; i <= 2; i++) today.add(Duration(days: i))];
  }

  /// Выбранный день: за него загружены [rows].
  final DateTime date;

  final DayDeliveriesStatus status;
  final List<DeliveryRow> rows;

  /// Сколько маршрутов в этом дне (строк в таблице обычно больше).
  final int routesCount;

  final DeliveryFilter filter;
  final String query;

  /// Счётчики по дням ленты — подписи на табах соседних дат.
  final Map<DateTime, DayMeta> dayMeta;

  /// Цена капсулы, по которой оценивается долг за день.
  ///
  /// До первого ответа прайса — значение сборки: показатель должен быть на
  /// экране сразу, а не после сетевого запроса.
  final int capsulePrice;

  /// День ещё не наступил: доставок не было и быть не могло.
  bool get isFuture => date.isAfter(dayOnly(DateTime.now()));

  /// Строки после фильтра и поиска.
  List<DeliveryRow> get visible {
    final wanted = filter.status;
    final needle = query.trim().toLowerCase();

    return rows.where((row) {
      if (wanted != null && row.stop.status != wanted) return false;
      if (needle.isEmpty) return true;
      // Ищем и по заказчику, и по водителю: оператор помнит то одного, то
      // другого, а раздельных полей поиска в шапке нет.
      return row.stop.customerName.toLowerCase().contains(needle) ||
          (row.route.driverFullName ?? '').toLowerCase().contains(needle);
    }).toList();
  }

  /// Сколько строк попадёт в каждый фильтр — числа на чипах.
  int countFor(DeliveryFilter value) {
    final wanted = value.status;
    if (wanted == null) return rows.length;
    return rows.where((r) => r.stop.status == wanted).length;
  }

  // ---- Показатели дня ----

  int get done => rows.where((r) => r.stop.isCompleted).length;

  int get total => rows.length;

  /// Незавершённые точки — бейдж у пункта меню.
  int get pending => total - done;

  double get progress => total == 0 ? 0 : done / total;

  int get collected =>
      rows.fold<int>(0, (sum, r) => sum + (r.stop.paymentAmount ?? 0));

  /// Ушло в долг за день. Оценка: см. [DeliveryRow.expectedAmount].
  int get debt => rows
      .where((r) => r.isDebt)
      .fold<int>(0, (sum, r) => sum + r.expectedAmount(capsulePrice));

  int get capsules =>
      rows.fold<int>(0, (sum, r) => sum + (r.stop.deliveredCapsules ?? 0));

  /// Сколько водителей задействовано в этом дне.
  int get driversInvolved =>
      rows.map((r) => r.route.driverId).whereType<String>().toSet().length;

  /// Сколько разных заказчиков в маршрутах дня.
  int get customersInvolved =>
      rows.map((r) => r.stop.customerId).toSet().length;

  DayDeliveriesState copyWith({
    DateTime? date,
    DayDeliveriesStatus? status,
    List<DeliveryRow>? rows,
    int? routesCount,
    DeliveryFilter? filter,
    String? query,
    Map<DateTime, DayMeta>? dayMeta,
    int? capsulePrice,
  }) {
    return DayDeliveriesState(
      date: date ?? this.date,
      status: status ?? this.status,
      rows: rows ?? this.rows,
      routesCount: routesCount ?? this.routesCount,
      filter: filter ?? this.filter,
      query: query ?? this.query,
      dayMeta: dayMeta ?? this.dayMeta,
      capsulePrice: capsulePrice ?? this.capsulePrice,
    );
  }

  @override
  List<Object?> get props =>
      [date, status, rows, routesCount, filter, query, dayMeta, capsulePrice];
}

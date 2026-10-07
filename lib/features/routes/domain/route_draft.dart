import 'package:equatable/equatable.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/route_models.dart';

/// Маркер «значение не передавали».
///
/// У [RouteDraftStop.price] `null` — осмысленный вход: «считать по прайсу».
/// Обычный `??` его от «не меняем» не отличает, и сброс договорной цены молча
/// терялся бы — оператор нажал «По прайсу», а сумма осталась своей.
const Object _unchanged = Object();

/// Точка черновика маршрута: заказчик, цель, количество и цена.
///
/// Всё состояние точки живёт здесь, одним объектом: итоги маршрута —
/// производные (см. [RouteDraft.totals]) и рядом с точками не хранятся,
/// иначе однажды разойдутся с ними.
class RouteDraftStop extends Equatable {
  const RouteDraftStop({
    required this.customerId,
    this.purpose = OrderPurpose.delivery19l,
    required this.qty,
    this.price,
    this.comment,
  });

  final String customerId;
  final OrderPurpose purpose;

  /// Сколько капсул везти — а у вывоза сколько забрать.
  ///
  /// На сервер уходит у доставки и вывоза (`bottle_sell_count`), у опта
  /// отправлять нечего. Хранится при любой цели: смена цели и возврат обратно
  /// не должны терять набранное число.
  final int qty;

  /// Договорная сумма за **весь** заказ, сум; `null` — считать по прайсу.
  ///
  /// У вывоза и опта прайса нет вовсе: пусто значит «без оплаты» у вывоза и
  /// «цену ставит водитель на месте» у опта.
  final int? price;

  /// Комментарий водителю к этой точке; `null` — комментария нет.
  ///
  /// Необязателен и на расчёты не влияет: это записка «позвонить с парковки»,
  /// которую водитель увидит в своей карточке точки. Задать его можно только
  /// при добавлении точки — правки комментария у сервера нет.
  final String? comment;

  /// Цену задали руками — значит рядом с полем появляется «По прайсу».
  bool get hasCustomPrice => price != null;

  /// Количество у точки вообще спрашивают: у доставки — сколько везти, у
  /// вывоза — сколько забрать. У опта бутыли 5/10 л считает водитель на
  /// месте, и передать их при создании нечем.
  bool get hasQty => purpose != OrderPurpose.bulkWater;

  /// Капсулы 19 л в итогах считает только доставка: вывоз машину не занимает
  /// (наоборот, освобождает), а бутыли 5/10 л — не капсулы.
  bool get countsCapsules => purpose == OrderPurpose.delivery19l;

  /// Сумма по прайсу: капсулы × цена капсулы. У вывоза и опта — ноль:
  /// прайса для них нет, и считать «бутыли по цене капсулы» значило бы
  /// показать оператору цифру, которой не будет ни в одном документе.
  int listPrice(int unitPrice) => countsCapsules ? qty * unitPrice : 0;

  /// Деньги этой точки: договорная сумма, иначе расчёт по прайсу.
  int money(int unitPrice) => price ?? listPrice(unitPrice);

  RouteDraftStop copyWith({
    OrderPurpose? purpose,
    int? qty,
    Object? price = _unchanged,
    Object? comment = _unchanged,
  }) =>
      RouteDraftStop(
        customerId: customerId,
        purpose: purpose ?? this.purpose,
        qty: qty ?? this.qty,
        price: identical(price, _unchanged) ? this.price : price as int?,
        comment:
            identical(comment, _unchanged) ? this.comment : comment as String?,
      );

  @override
  List<Object?> get props => [customerId, purpose, qty, price, comment];
}

/// Цена капсулы для расчёта точки.
///
/// Индивидуальная цена заказчика перебивает общий прайс — так же, как это
/// делает сервер в `effective_water_price`.
class DraftPricing extends Equatable {
  const DraftPricing({
    required this.capsulePrice,
    this.customerPrices = const {},
  });

  /// Общий прайс, сум за капсулу.
  final int capsulePrice;

  /// Индивидуальные цены заказчиков (`custom_water_price`), сум за капсулу.
  final Map<String, int> customerPrices;

  int unitPriceFor(String customerId) =>
      customerPrices[customerId] ?? capsulePrice;

  @override
  List<Object?> get props => [capsulePrice, customerPrices];
}

/// Итоги маршрута: точки, капсулы 19 л и деньги.
class RouteDraftTotals extends Equatable {
  const RouteDraftTotals({
    required this.stops,
    required this.capsules,
    required this.money,
  });

  final int stops;

  /// Капсул 19 л к погрузке — только доставки.
  final int capsules;

  /// Сумма маршрута, сум.
  final int money;

  /// Капсулы не влезают в машину: предупреждение, а не запрет — маршрут с
  /// перегрузом бывает осмысленным (две ездки), решает всё равно человек.
  bool exceedsCapacity(int capacity) => capsules > capacity;

  @override
  List<Object?> get props => [stops, capsules, money];
}

/// Черновик маршрута — упорядоченный список точек.
///
/// Порядок списка и есть порядок объезда: он уходит на сервер номерами
/// `sequence` (см. [toOrders]), а сами точки создаются в этом же порядке.
class RouteDraft extends Equatable {
  const RouteDraft([this.stops = const []]);

  final List<RouteDraftStop> stops;

  bool get isEmpty => stops.isEmpty;
  bool get isNotEmpty => stops.isNotEmpty;
  int get length => stops.length;

  bool contains(String customerId) =>
      stops.any((s) => s.customerId == customerId);

  RouteDraftStop? stopOf(String customerId) =>
      stops.where((s) => s.customerId == customerId).firstOrNull;

  /// Номер точки в объезде, считая с единицы; `0` — точки в маршруте нет.
  int numberOf(String customerId) =>
      stops.indexWhere((s) => s.customerId == customerId) + 1;

  /// Добавляет точку в конец объезда. Повторное добавление того же
  /// заказчика ничего не меняет: две доставки одному адресу в одном
  /// маршруте сервер и не примет.
  RouteDraft add(RouteDraftStop stop) => contains(stop.customerId)
      ? this
      : RouteDraft([...stops, stop]);

  RouteDraft remove(String customerId) =>
      RouteDraft([...stops.where((s) => s.customerId != customerId)]);

  RouteDraft patch(
    String customerId, {
    OrderPurpose? purpose,
    int? qty,
    Object? price = _unchanged,
    Object? comment = _unchanged,
  }) =>
      RouteDraft([
        for (final stop in stops)
          if (stop.customerId == customerId)
            stop.copyWith(
              purpose: purpose,
              qty: qty,
              price: price,
              comment: comment,
            )
          else
            stop,
      ]);

  /// Переставляет точку с места [fromIndex] на место [toIndex].
  ///
  /// Индексы — по правилам `onReorderItem` у `ReorderableListView`: тот сам
  /// учитывает, что вынутая точка укорачивает список, и отдаёт уже конечное
  /// место (в отличие от устаревшего `onReorder`, где его считал вызывающий).
  RouteDraft reorder(int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= stops.length) return this;
    if (toIndex < 0 || toIndex >= stops.length || toIndex == fromIndex) {
      return this;
    }
    final next = [...stops];
    next.insert(toIndex, next.removeAt(fromIndex));
    return RouteDraft(next);
  }

  /// Сдвигает точку на шаг вверх или вниз — фолбэк к перетаскиванию и
  /// единственный способ поменять порядок с клавиатуры.
  RouteDraft shift(String customerId, int direction) {
    final from = stops.indexWhere((s) => s.customerId == customerId);
    final to = from + direction;
    if (from < 0 || to < 0 || to >= stops.length) return this;
    final next = [...stops];
    next.insert(to, next.removeAt(from));
    return RouteDraft(next);
  }

  RouteDraftTotals totals(DraftPricing pricing) {
    var capsules = 0;
    var money = 0;
    for (final stop in stops) {
      if (stop.countsCapsules) capsules += stop.qty;
      money += stop.money(pricing.unitPriceFor(stop.customerId));
    }
    return RouteDraftTotals(
      stops: stops.length,
      capsules: capsules,
      money: money,
    );
  }

  /// Точки для `POST /admin/routes`.
  ///
  /// `sequence` ставим сами, хотя сервер и проставил бы его сам следующим
  /// номером: порядок объезда — решение оператора, и отдавать его на
  /// усмотрение сервера нельзя. Задание в капсулах уходит у доставки и
  /// вывоза — поле `bottle_sell_count` на сервере одно на обе цели и ни в
  /// один расчёт не входит, это справка водителю. Договорная сумма уходит
  /// при любой цели:
  /// валидаторов по цели у `order_custom_price` нет, а при закрытии сервер
  /// берёт `custom_price or order_cost` для всех целей одинаково.
  List<RouteOrderInput> toOrders() => [
        for (var i = 0; i < stops.length; i++)
          RouteOrderInput(
            customerId: stops[i].customerId,
            purpose: stops[i].purpose,
            sequence: i + 1,
            bottleSellCount: stops[i].hasQty ? stops[i].qty : null,
            customPrice: stops[i].price,
            comment: stops[i].comment,
          ),
      ];

  @override
  List<Object?> get props => [stops];
}

import '../../l10n/l10n.dart';
import 'json.dart';

/// Статус доставки (остановки маршрута). Значения совпадают с API.
///
/// `failed` — «не доставлено» без объяснения, как было до появления отмены;
/// `cancelled` — осознанная отмена с причиной (см. `Order.cancelReason`).
/// Оба закрывают заказ, но смешивать их нельзя: у старых заказов `failed`
/// стоит без причины, и показывать их «отменёнными» значило бы приписывать
/// решение, которого никто не принимал.
enum DeliveryStatus {
  pending('pending'),
  onWay('on_way'),
  delivered('delivered'),
  failed('failed'),
  cancelled('cancelled');

  const DeliveryStatus(this.wire);

  /// Значение, которым статус называется в API.
  final String wire;

  /// Подпись статуса на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        DeliveryStatus.pending => l10n.deliveryPending,
        DeliveryStatus.onWay => l10n.deliveryOnWay,
        DeliveryStatus.delivered => l10n.deliveryDelivered,
        DeliveryStatus.failed => l10n.deliveryFailed,
        DeliveryStatus.cancelled => l10n.deliveryCancelled,
      };

  /// Заказ ещё не закрыт: его можно завершить, перенести или отменить.
  bool get isOpen => this == DeliveryStatus.pending || this == DeliveryStatus.onWay;

  /// Заказ закрыт без доставки — отменён или не доставлен.
  bool get isClosedWithoutDelivery =>
      this == DeliveryStatus.failed || this == DeliveryStatus.cancelled;

  static DeliveryStatus fromJson(String value) =>
      DeliveryStatus.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => DeliveryStatus.pending,
      );

  String toJson() => wire;
}

/// Статус маршрута. Значения совпадают с API.
enum RouteStatus {
  created('created'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const RouteStatus(this.wire);

  final String wire;

  /// Подпись статуса на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        RouteStatus.created => l10n.routeCreated,
        RouteStatus.inProgress => l10n.routeInProgress,
        RouteStatus.completed => l10n.routeCompleted,
        RouteStatus.cancelled => l10n.routeCancelled,
      };

  static RouteStatus fromJson(String value) => RouteStatus.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => RouteStatus.created,
      );

  String toJson() => wire;
}

/// Что админ может менять в маршруте с этим статусом.
///
/// Правило живёт одним местом: форма, детальный экран и тесты спрашивают
/// здесь, а не сравнивают статусы каждый у себя — иначе «можно» и «нельзя»
/// однажды разъедутся, и разойдутся они молча.
extension RouteEditRules on RouteStatus {
  /// Дату меняем только до выхода в рейс: начатый маршрут водитель уже
  /// везёт, и смена дня под ним означает, что он приедет не тогда.
  bool get canReschedule => this == RouteStatus.created;

  /// Водителя переназначаем, пока маршрут не закрыт и не отменён.
  ///
  /// Отдельно от [canReschedule]: сервер снял ограничение «только created» —
  /// маршрут-заготовку собирают заранее и без исполнителя, а назначают его
  /// уже сегодняшнему маршруту, который к тому времени `in_progress`.
  /// У завершённого и отменённого менять некого: доставки состоялись.
  bool get canAssignDriver =>
      this == RouteStatus.created || this == RouteStatus.inProgress;

  /// Точку можно досыпать и в начатый маршрут — обычный случай, когда заказ
  /// поступил, пока водитель в пути.
  bool get canAddCustomers =>
      this == RouteStatus.created || this == RouteStatus.inProgress;

  /// Убирать точки — только до выезда: в рейсе доставка может быть уже
  /// выполнена, и удаление стёрло бы её вместе с принятой оплатой.
  bool get canRemoveCustomers => this == RouteStatus.created;

  /// Есть ли вообще что менять — этим включается кнопка «Изменить».
  bool get isEditable => canReschedule || canAddCustomers || canAssignDriver;

  /// Отменяем только то, что ещё не доехало. У завершённого маршрута отменять
  /// нечего: доставки выполнены, оплаты приняты — кнопка предлагала бы стереть
  /// уже случившееся.
  bool get canCancel =>
      this == RouteStatus.created || this == RouteStatus.inProgress;
}

/// Фильтр списка маршрутов (чипы на экране).
///
/// Общий для админского и водительского списков.
enum RouteFilter {
  all,
  inProgress,
  completed,
  created,
  cancelled;

  /// Подпись чипа на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        RouteFilter.all => l10n.filterAll,
        RouteFilter.inProgress => l10n.filterInProgress,
        RouteFilter.completed => l10n.filterCompleted,
        RouteFilter.created => l10n.filterNew,
        RouteFilter.cancelled => l10n.filterCancelled,
      };

  /// Статус, которому соответствует фильтр. `null` у «Все».
  RouteStatus? get status => switch (this) {
        RouteFilter.all => null,
        RouteFilter.inProgress => RouteStatus.inProgress,
        RouteFilter.completed => RouteStatus.completed,
        RouteFilter.created => RouteStatus.created,
        RouteFilter.cancelled => RouteStatus.cancelled,
      };
}

/// Фильтр списка заказчиков (чипы на экране).
///
/// Взаимоисключающий, как и у маршрутов: чипы в приложении — переключатель,
/// а не набор галочек. Соответствие параметрам API держится здесь, чтобы
/// блок не собирал их у себя и однажды не разошёлся с подписью чипа.
enum CustomerFilter {
  all,
  withDebt,
  withCooler,
  inactive;

  /// Подпись чипа на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        CustomerFilter.all => l10n.filterAll,
        CustomerFilter.withDebt => l10n.filterWithDebt,
        CustomerFilter.withCooler => l10n.filterWithCooler,
        CustomerFilter.inactive => l10n.filterInactive,
      };

  /// `null` — параметр не отправляем вовсе, сервер отдаёт и тех, и других.
  bool? get hasDebt => this == CustomerFilter.withDebt ? true : null;

  /// Страница заказчиков — про тех, с кем работают: под любым чипом, кроме
  /// «Неактивные», сервер спрашивают только про `is_active = true`.
  /// Раньше параметр не уходил вовсе, и отключённые стояли в общем списке
  /// вперемешку с рабочими. Чип «Неактивные» — единственный путь к ним:
  /// отключённого надо иметь возможность найти и включить обратно.
  bool get isActive => this != CustomerFilter.inactive;

  /// Отбор по кулеру считается на клиенте, а не сервером.
  ///
  /// Параметр `has_cooler` из `GET /admin/customers` убрали вместе с самим
  /// полем (теперь `cooler_count`), а нового фильтра не завели. Неизвестный
  /// query-параметр сервер молча игнорирует — то есть чип «С кулером»
  /// показывал бы всех подряд и врал бы, ничем этого не выдавая.
  ///
  /// Поэтому отбор идёт по уже загруженным страницам (см. `CustomersBloc`).
  /// Цена решения: счётчик в шапке считает найденное, а не всю базу, и
  /// страница может прийти почти пустой. Убрать, когда сервер вернёт фильтр.
  bool get filtersCoolerLocally => this == CustomerFilter.withCooler;
}

/// Цель заказа (`OrderPurpose` в API).
///
/// Появилась вместе с переименованием точек маршрута в заказы: один и тот же
/// выезд может быть доставкой, вывозом кулера или оптовой продажей, и деньги
/// у них считаются по-разному.
enum OrderPurpose {
  /// Доставка капсул 19 л — поведение по умолчанию и подавляющее большинство.
  delivery19l('delivery_19l'),

  /// Вывоз кулера и/или капсул заказчика.
  pickup('pickup'),

  /// Опт: бутыли 5 л и 10 л, цена договорная.
  bulkWater('bulk_water');

  const OrderPurpose(this.wire);

  /// Значение, которым цель называется в API.
  final String wire;

  /// Подпись цели на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        OrderPurpose.delivery19l => l10n.orderPurposeDelivery,
        OrderPurpose.pickup => l10n.orderPurposePickup,
        OrderPurpose.bulkWater => l10n.orderPurposeBulk,
      };

  /// Короткая подпись — для плотных мест: колонка таблицы, бейдж в строке.
  ///
  /// «Доставка 19 л» в ячейку не помещается и обрезается многоточием, а
  /// обрезанная цель перестаёт отличать доставку от вывоза — то есть ровно
  /// то, ради чего колонка и заведена.
  String shortLabel(AppLocalizations l10n) => switch (this) {
        OrderPurpose.delivery19l => l10n.orderPurposeDeliveryShort,
        OrderPurpose.pickup => l10n.orderPurposePickupShort,
        OrderPurpose.bulkWater => l10n.orderPurposeBulkShort,
      };

  /// Незнакомая цель с сервера не должна ронять список: показываем заказ как
  /// обычную доставку — это верно для всех заказов, заведённых до релиза.
  static OrderPurpose fromJson(String value) => OrderPurpose.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => OrderPurpose.delivery19l,
      );

  String toJson() => wire;
}

/// Категория расхода водителя (`ExpenseCategory`).
///
/// Расходы водитель заносит по дороге, и список намеренно короткий: чем
/// длиннее перечень, тем чаще всё уходит в «Прочее».
enum ExpenseCategory {
  fuel('fuel'),
  lunch('lunch'),
  repair('repair'),
  other('other');

  const ExpenseCategory(this.wire);

  /// Значение, которым категория называется в API.
  final String wire;

  /// Подпись категории на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        ExpenseCategory.fuel => l10n.expenseCategoryFuel,
        ExpenseCategory.lunch => l10n.expenseCategoryLunch,
        ExpenseCategory.repair => l10n.expenseCategoryRepair,
        ExpenseCategory.other => l10n.expenseCategoryOther,
      };

  /// Незнакомая категория с сервера — «Прочее»: расход всё равно случился,
  /// и терять его из-за подписи нельзя.
  static ExpenseCategory fromJson(String value) =>
      ExpenseCategory.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => ExpenseCategory.other,
      );

  String toJson() => wire;
}

/// Способ оплаты. Значения совпадают с API (`PaymentMethod`), поле
/// обязательное при завершении доставки.
enum PaymentMethod {
  cash('cash'),
  card('card'),
  transfer('transfer'),
  debt('debt');

  const PaymentMethod(this.wire);

  /// Значение, которым способ называется в API.
  final String wire;

  /// Подпись способа оплаты на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        PaymentMethod.cash => l10n.paymentCash,
        PaymentMethod.card => l10n.paymentCard,
        PaymentMethod.transfer => l10n.paymentTransfer,
        PaymentMethod.debt => l10n.paymentDebt,
      };

  /// Нужно ли фото подтверждения.
  ///
  /// Только у карты: перевод подтверждается чеком из банковского приложения,
  /// а наличные, безнал по счёту и долг фотографировать нечего.
  bool get needsPhoto => this == PaymentMethod.card;

  String toJson() => wire;

  /// Способ оплаты из ответа сервера; `null` — поля нет или оно незнакомое.
  ///
  /// Незнакомый способ не повод терять запись: сумму и статус показать
  /// всё ещё можно, а подпись способа просто не появится. Живёт у самого
  /// перечисления, потому что разбирают его четыре модели — заказ, платёж,
  /// точка маршрута и строка отчёта.
  static PaymentMethod? tryFromJson(Object? value) {
    final wire = optionalString(value);
    if (wire == null) return null;
    return PaymentMethod.values.where((e) => e.wire == wire).firstOrNull;
  }
}

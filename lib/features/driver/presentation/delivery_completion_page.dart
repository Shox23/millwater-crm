import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/location/device_location.dart';
import '../../../core/pricing/capsule_price.dart';
import '../../../core/product_config.dart';
import '../../../core/utils/idempotency.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/labeled_card.dart';
import '../../../core/widgets/photo_attach_tile.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../../../core/widgets/segmented_toggle.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/route_models.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/driver_repository.dart';

/// Экран «Завершение доставки»: капсулы, сумма и фото оплаты.
class DeliveryCompletionPage extends StatefulWidget {
  const DeliveryCompletionPage({
    super.key,
    required this.stop,
    this.location = ProductConfig.captureDeliveryCoordinates
        ? const DeviceLocationService()
        : null,
    this.price = const BuildCapsulePrice(),
  });

  final RouteStop stop;

  /// Откуда берётся цена капсулы. По умолчанию — значение сборки: экран
  /// открывается и без сети, а `my_route_detail_page` передаёт сюда источник,
  /// который сперва спрашивает прайс у сервера.
  final CapsulePrice price;

  /// null — координаты не снимаются и разрешение не запрашивается.
  /// В тестах сюда передаётся подменённый сервис.
  final DeviceLocationService? location;

  @override
  State<DeliveryCompletionPage> createState() => _DeliveryCompletionPageState();
}

class _DeliveryCompletionPageState extends State<DeliveryCompletionPage> with SubmitState {
  /// Цель заказа задана заранее и на экране не меняется: её выбрали при
  /// сборке маршрута, а водитель отчитывается по тому, зачем приехал.
  OrderPurpose get _purpose => widget.stop.purpose;

  /// Договорная сумма за весь заказ, если админ её задал при сборке
  /// маршрута. Тогда деньги не зависят от счётчиков: сервер запишет её в
  /// стоимость как есть, без штрафа и возврата, — и расчёт здесь такой же.
  int? get _customPrice => widget.stop.customPrice;

  late int _capsules;

  /// Доставка 19 л: сколько пустых забрали и сколько из них с браком.
  int _returned = 0;
  int _damaged = 0;

  /// Сколько **полных** капсул заказчик вернул. Они уходят из его остатка и
  /// из денег; итог считает сервер, здесь — только число и ориентир суммы.
  int _returnedFull = 0;

  /// Вывоз: сколько кулеров и капсул увезли с точки.
  int _pickedCoolers = 0;
  int _pickedBottles = 0;

  /// Опт: количество и договорная цена за бутыль. Цену вводит водитель —
  /// прайса на пятилитровки у сервера нет.
  int _bulk5Count = 0;
  int _bulk10Count = 0;
  late final TextEditingController _bulk5Price;
  late final TextEditingController _bulk10Price;

  /// Сколько капсул числится за заказчиком до этой доставки (серверное
  /// `bottle_balance` заказчика).
  int get _balanceBefore => widget.stop.customerBottleBalance ?? 0;

  /// Сколько капсул останется у заказчика: прежний остаток плюс привезённое
  /// минус возвращённое с водой. Сервер этим числом **перезаписывает** склад
  /// клиента, поэтому считаем его сами и руками не даём править —
  /// расхождение уходило бы прямо в учёт.
  int get _bottleBalance => _balanceBefore + _capsules - _returnedFull;

  /// Больше, чем есть у заказчика, вернуть нельзя: остаток ушёл бы в минус.
  /// Когда остаток не пришёл (старый стенд), ограничивать нечем.
  int get _returnedFullMax => widget.stop.customerBottleBalance ?? 999;

  /// Только возврат или только брак — тоже результат визита: везти было
  /// незачем, а забрать пришлось. Иначе «Доставлено» не опускается ниже
  /// единицы — ноль там означал бы «не доставлено».
  int get _capsulesMin => (_returnedFull > 0 || _damaged > 0) ? 0 : 1;

  /// Сумму правили вручную — расчёт за водителем её больше не перебивает.
  /// Так закрываются частичная оплата и долг: цифра остаётся его.
  bool _amountLocked = false;

  /// Способ оплаты. У вывоза по умолчанию «в долг»: денег за него обычно не
  /// берут, а нулевую сумму сервер принимает только с этим способом — при
  /// наличных он отвечает 422 «payment_amount must be greater than 0». Так
  /// и при договорной сумме: она в долг уйдёт заказчику, а водитель, приняв
  /// деньги, сам переключит способ — и сумма подставится.
  late PaymentMethod _method = widget.stop.purpose == OrderPurpose.pickup
      ? PaymentMethod.debt
      : PaymentMethod.cash;
  late final TextEditingController _amountController;
  XFile? _photo;

  /// Один ключ на весь экран: повтор после обрыва связи не должен провести
  /// доставку второй раз.
  final String _idempotencyKey = newIdempotencyKey('complete');

  /// Результат снятия координат; null — ещё не снимали.
  LocationFix? _fix;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    // Снимаем сразу на открытии: водитель стоит у двери именно сейчас, а к
    // моменту нажатия «Завершить» координаты уже готовы и не тормозят отправку.
    if (widget.location != null) _captureLocation();
    _capsules = widget.stop.deliveredCapsules ?? 1;
    _returned = widget.stop.returnedCapsules ?? 0;
    _returnedFull = widget.stop.returnedFullCapsules ?? 0;
    _damaged = widget.stop.damagedCapsules ?? 0;
    _bulk5Price = TextEditingController();
    _bulk10Price = TextEditingController();
    // Ранее введённая сумма важнее расчёта: значит, доставку уже проводили.
    // В долг стартуем с нуля даже при договорной сумме: сервер с этим
    // способом принимает только ноль, а сумма подставится при переходе на
    // наличные (см. [_onMethodChanged]).
    final amount =
        widget.stop.paymentAmount ?? (_isDebt ? 0 : _calculatedAmount);
    _amountLocked = widget.stop.paymentAmount != null;
    _amountController = TextEditingController(text: '$amount');
    _loadPrice();
  }

  /// Цена капсулы, по которой считается сумма.
  ///
  /// Первым делом — цена **этого заказа** (`effective_water_price`): сервер
  /// уже учёл в ней индивидуальную цену заказчика, и считать по общему
  /// прайсу значило бы разойтись с ним на каждой доставке такому клиенту.
  /// Если поля нет (старый стенд), берётся значение сборки и затем живой
  /// прайс — см. [_loadPrice]. Ждать ответа экран не может: водитель стоит
  /// у двери, и пустое поле суммы ему дороже точной цены.
  late int _capsulePrice =
      widget.stop.effectiveWaterPrice ?? ProductConfig.capsulePrice;

  /// Штраф за повреждённую капсулу — тоже снимок с заказа. Своего источника
  /// у водителя нет: общий прайс отдаёт только цену воды.
  int get _damagedFine => widget.stop.damagedBottleFine ?? 0;

  /// Спрашивает живую цену и пересчитывает сумму под неё.
  ///
  /// Пересчёт только пока сумму не назначили вручную: [_amountLocked] стоит и
  /// у доставки, которую уже проводили, — затирать введённое число ответом
  /// сервера значило бы менять принятую оплату за спиной водителя.
  Future<void> _loadPrice() async {
    // При договорной сумме цена капсулы в расчёте не участвует — незачем и
    // спрашивать. Цена заказа старше прайса: она уже содержит индивидуальную
    // цену заказчика, а общий прайс её не знает.
    if (_customPrice != null || widget.stop.effectiveWaterPrice != null) {
      return;
    }
    final price = await widget.price.value();
    if (!mounted || price == _capsulePrice) return;
    setState(() {
      _capsulePrice = price;
      _recalculate();
    });
  }

  /// Сколько должно получиться по расчёту — у каждой цели он свой.
  ///
  /// Доставка: привезённые капсулы по цене заказа плюс штраф за брак минус
  /// возвращённые с водой по той же цене — ниже нуля не опускается, деньги
  /// водитель не выдаёт, остаток сервер запишет заказчику сам. Это ориентир:
  /// итог по возврату считает сервер, а водитель может переписать сумму.
  /// Вывоз денег не приносит, если админ не назначил ему сумму. Опт
  /// считается по договорным ценам, которые водитель вводит сам.
  int get _calculatedAmount => switch (_purpose) {
        // Договорная сумма перекрывает формулу целиком — как на сервере.
        OrderPurpose.delivery19l || OrderPurpose.pickup
            when _customPrice != null =>
          _customPrice!,
        OrderPurpose.delivery19l => _atLeastZero(
            (_capsules - _returnedFull) * _capsulePrice + _damaged * _damagedFine),
        OrderPurpose.pickup => 0,
        OrderPurpose.bulkWater =>
          _bulk5Count * _bulkPrice(_bulk5Price) +
              _bulk10Count * _bulkPrice(_bulk10Price),
      };

  int _bulkPrice(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  static int _atLeastZero(int value) => value < 0 ? 0 : value;

  /// Доставка, на которой ничего не произошло: ни привезли, ни забрали брак,
  /// ни приняли возврат. Серверное правило — хотя бы одно из трёх > 0.
  bool get _deliveryEmpty =>
      _purpose == OrderPurpose.delivery19l &&
      _capsules == 0 &&
      _damaged == 0 &&
      _returnedFull == 0;

  /// Вывоз, на котором ничего не забрали.
  ///
  /// Серверное правило: у `pickup` хотя бы одно из «кулеры / капсулы / брак»
  /// обязано быть больше нуля (422 `PICKUP_QUANTITY_REQUIRED`). Пустой вывоз
  /// и по смыслу нечего закрывать — водитель приехал и ничего не увёз.
  bool get _pickupEmpty =>
      _purpose == OrderPurpose.pickup &&
      _pickedCoolers == 0 &&
      _pickedBottles == 0 &&
      _damaged == 0;

  /// Ноль принимается только как «в долг».
  ///
  /// Серверное правило: при любом способе, кроме `debt`, сумма обязана быть
  /// больше нуля, иначе 422 с английским текстом, который до водителя не
  /// доходит. Ловим до отправки — на вывозе в это упирается каждый заказ.
  bool get _zeroAmountConflict => _amountOrNull == 0 && !_isDebt;

  /// Количество указано, а цена — нет: сервер такой заказ отвергает (422),
  /// и упереться в отказ на глазах у заказчика незачем.
  bool get _bulkPriceMissing =>
      _purpose == OrderPurpose.bulkWater &&
      ((_bulk5Count > 0 && _bulkPrice(_bulk5Price) <= 0) ||
          (_bulk10Count > 0 && _bulkPrice(_bulk10Price) <= 0));

  /// Всё, что мешает отправить, — одним списком для кнопки: пустая сумма
  /// (на сервер ушёл бы ноль, неотличимый от долга), опт без цены, ноль не
  /// в долг, пустой вывоз и пустая доставка — всё это сервер отвергнет сам,
  /// а упираться в отказ у заказчика незачем.
  bool get _canSubmit =>
      !submitting &&
      _amountOrNull != null &&
      !_bulkPriceMissing &&
      !_zeroAmountConflict &&
      !_pickupEmpty &&
      !_deliveryEmpty;

  /// Нижняя граница «Доставлено» плавает (см. [_capsulesMin]): когда возврат
  /// и брак сняли до нуля, ноль капсул снова означает «не доставлено», и
  /// счётчик возвращается к единице сам — а не остаётся на недопустимом
  /// значении с потухшим минусом.
  void _keepCapsulesAboveMin() {
    if (_capsules < _capsulesMin) _capsules = _capsulesMin;
  }

  /// Пересчитывает сумму, пока водитель не назначил свою.
  ///
  /// В долг поле держится на нуле: сервер при `debt` принимает только ноль,
  /// а поле в этом режиме `readOnly` — переписанную расчётом сумму водителю
  /// нечем было бы вернуть, и каждая смена счётчика после выбора долга
  /// заканчивалась 422. Сам расчёт при этом жив: его показывает подсказка
  /// «уйдёт в долг» через [_debtAmount].
  void _recalculate() {
    if (_amountLocked) return;
    _amountController.text = _isDebt ? '0' : '$_calculatedAmount';
  }

  void _onCapsulesChanged(int value) {
    setState(() {
      _capsules = value;
      // Сумма идёт за количеством, пока водитель не назначил свою.
      _recalculate();
    });
  }

  /// Оплата в долг: денег не приняли, вся стоимость уходит заказчику.
  bool get _isDebt => _method == PaymentMethod.debt;

  /// Сколько начислится заказчику в долг.
  ///
  /// Это стоимость заказа целиком: при способе «в долг» принято ноль.
  int get _debtAmount => _calculatedAmount;

  /// Сумма, введённая до перехода в долг, — чтобы вернуть её при возврате.
  int? _amountBeforeDebt;

  /// Смена способа оплаты.
  ///
  /// Уход с карты стирает уже прикреплённый снимок: тайл исчезает с экрана, и
  /// оставшееся фото ушло бы на сервер незаметно для водителя — приложенным к
  /// оплате, которая его не предполагает.
  ///
  /// Долг обнуляет сумму принудительно. Правило серверное: при
  /// `payment_method = debt` он требует ровно ноль и иначе отвечает 422 с
  /// английским текстом, который до водителя не доходит — тот видел общее
  /// «Не удалось». Раньше клиент подставлял «капсулы × цена» при любом
  /// способе и упирался в этот отказ на каждой доставке в долг.
  void _onMethodChanged(PaymentMethod method) {
    setState(() {
      final wasDebt = _isDebt;
      _method = method;
      if (!method.needsPhoto) _photo = null;

      if (method == PaymentMethod.debt) {
        _amountBeforeDebt = _amountOrNull;
        _amountController.text = '0';
      } else if (wasDebt) {
        // Возвращаем то, что было до долга: правленную водителем сумму —
        // как есть, иначе расчёт по прайсу.
        _amountController.text = '${_amountBeforeDebt ?? _calculatedAmount}';
        _amountBeforeDebt = null;
      }
    });
  }

  /// Возвращает сумму к расчёту по прайсу после ручной правки.
  void _restoreCalculatedAmount() {
    setState(() {
      _amountLocked = false;
      _amountController.text = '$_calculatedAmount';
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bulk5Price.dispose();
    _bulk10Price.dispose();
    super.dispose();
  }

  /// Введённая сумма; `null` — поле пустое или не число.
  ///
  /// Отличать пустоту от нуля обязательно: ноль — рабочий вход (оплата в
  /// долг), а стёртое поле раньше уходило на сервер как «оплачено 0».
  int? get _amountOrNull => int.tryParse(_amountController.text.trim());

  int get _amount => _amountOrNull ?? 0;

  /// Снимает координаты в фоне. Неудача ничего не блокирует: доставку можно
  /// завершить и без точки, адрес заказчика никуда не делся.
  Future<void> _captureLocation() async {
    setState(() => _locating = true);
    final fix = await widget.location!.currentFix();
    if (!mounted) return;
    setState(() {
      _fix = fix;
      _locating = false;
    });
  }

  Future<void> _submit() async {
    final repo = context.read<DriverRepository>();
    // Строки берём до запроса: после await контекст уже мог уйти.
    final l10n = context.l10n;

    final completed = await submit(
      () => repo.completeDelivery(
        stopId: widget.stop.id,
        purpose: _purpose,
        amount: _amount,
        method: _method,
        capsules: _purpose == OrderPurpose.delivery19l ? _capsules : 0,
        returnedCapsules: _returned,
        returnedFullCapsules:
            _purpose == OrderPurpose.delivery19l ? _returnedFull : 0,
        damagedCapsules: _damaged,
        // Остаток заказчика правит только доставка: вывоз и опт капсульный
        // склад не трогают, и слать туда число незачем — сервер им
        // **перезаписывает** остаток.
        bottleBalance:
            _purpose == OrderPurpose.delivery19l ? _bottleBalance : null,
        bulk5lCount: _bulk5Count,
        bulk5lPrice: _bulkPrice(_bulk5Price),
        bulk10lCount: _bulk10Count,
        bulk10lPrice: _bulkPrice(_bulk10Price),
        pickedCoolers: _pickedCoolers,
        pickedBottles: _pickedBottles,
        photoPath: _photo?.path,
        idempotencyKey: _idempotencyKey,
        latitude: _fix?.latitude,
        longitude: _fix?.longitude,
      ),
      // 403 здесь значит ровно одно: маршрут отдали другому водителю.
      message: (e) => switch (e) {
        DioException(response: Response(statusCode: 403)) =>
          l10n.completionForbidden,
        DioException() => apiErrorMessage(l10n, e, fallback: l10n.completionFailed),
        _ => l10n.completionFailed,
      },
    );

    if (completed && mounted) Navigator.of(context).pop(true);
  }

  /// Договорная сумма от админа — только показ: водитель должен видеть, что
  /// считать здесь нечего. [caption] у каждой цели свой: что именно сумму
  /// не двигает.
  Widget _customPriceCard(BuildContext context, int customPrice,
          {required String caption}) =>
      LabeledCard(
        label: context.l10n.completionCustomPrice,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Text(
              MoneyFormatter.sum(context.l10n, customPrice),
              style:
                  AppTypography.statNumber.copyWith(color: context.tokens.text),
            ),
            Text(
              caption,
              style:
                  AppTypography.secondary.copyWith(color: context.tokens.text2),
            ),
          ],
        ),
      );

  /// Поля, которые спрашиваются под конкретную цель заказа.
  ///
  /// Три лика одного экрана: доставке нужны капсулы, возврат, брак и остаток
  /// у заказчика; вывозу — сколько кулеров и капсул увезли; опту —
  /// количество и договорная цена бутылей. Общее (способ оплаты, сумма,
  /// фото) остаётся снаружи.
  List<Widget> _purposeSections(BuildContext context) => switch (_purpose) {
        OrderPurpose.delivery19l => [
            // Задание админа — над счётчиками: водитель сперва видит, сколько
            // должен привезти, и лишь потом отмечает, сколько привёз. Это
            // только показ: менять задание с его стороны нечем.
            if ((widget.stop.bottleSellCount ?? 0) > 0)
              _BottleSellCard(count: widget.stop.bottleSellCount!),
            // Договорная сумма — тоже от админа и тоже только показ: водитель
            // должен видеть, что считать по прайсу здесь не надо.
            if (_customPrice case final int customPrice)
              _customPriceCard(context, customPrice,
                  caption: context.l10n.completionCustomPriceCaption),
            LabeledCard(
              label: context.l10n.completionCapsules,
              child: QuantityStepper(
                value: _capsules,
                // Завершать доставку с нулём капсул нечего: это «не
                // доставлено» — если только не забрали брак или возврат.
                min: _capsulesMin,
                onChanged: _onCapsulesChanged,
                caption: context.l10n.completionCapsulesCaption(
                    ProductConfig.capsuleVolumeLiters),
              ),
            ),
            LabeledCard(
              label: context.l10n.completionReturned,
              child: QuantityStepper(
                value: _returned,
                min: 0,
                onChanged: (value) => setState(() => _returned = value),
                caption: context.l10n.completionReturnedCaption,
              ),
            ),
            LabeledCard(
              label: context.l10n.completionReturnedFull,
              child: QuantityStepper(
                value: _returnedFull,
                min: 0,
                max: _returnedFullMax,
                // Возврат уменьшает и остаток, и ориентир суммы.
                onChanged: (value) => setState(() {
                  _returnedFull = value;
                  _keepCapsulesAboveMin();
                  _recalculate();
                }),
                caption: context.l10n.completionReturnedFullCaption,
              ),
            ),
            LabeledCard(
              label: context.l10n.completionDamaged,
              child: QuantityStepper(
                value: _damaged,
                min: 0,
                // Брак оплачивается штрафом, поэтому сумма идёт за ним.
                onChanged: (value) => setState(() {
                  _damaged = value;
                  _keepCapsulesAboveMin();
                  _recalculate();
                }),
                caption: context.l10n.completionDamagedCaption,
              ),
            ),
            LabeledCard(
              label: context.l10n.completionBalance,
              child: _BalanceSummary(
                before: _balanceBefore,
                delivered: _capsules,
                returned: _returnedFull,
              ),
            ),
          ],
        OrderPurpose.pickup => [
            // У вывоза своей цены нет, и сумма от админа — единственный
            // источник денег. Показ, как у доставки: в поле оплаты она
            // встанет сама, когда водитель уйдёт с «в долг».
            if (_customPrice case final int customPrice)
              _customPriceCard(context, customPrice,
                  caption: context.l10n.completionPickupCustomPriceCaption),
            LabeledCard(
              label: context.l10n.completionPickedCoolers,
              child: QuantityStepper(
                value: _pickedCoolers,
                min: 0,
                onChanged: (value) => setState(() => _pickedCoolers = value),
                caption: context.l10n.completionPickedCoolersCaption,
              ),
            ),
            LabeledCard(
              label: context.l10n.completionPickedBottles,
              child: QuantityStepper(
                value: _pickedBottles,
                min: 0,
                onChanged: (value) => setState(() => _pickedBottles = value),
                caption: context.l10n.completionPickedBottlesCaption,
              ),
            ),
            LabeledCard(
              label: context.l10n.completionDamaged,
              child: QuantityStepper(
                value: _damaged,
                min: 0,
                onChanged: (value) => setState(() => _damaged = value),
                caption: context.l10n.completionDamagedCaption,
              ),
            ),
          ],
        OrderPurpose.bulkWater => [
            _BulkCard(
              label: context.l10n.completionBulk5l,
              count: _bulk5Count,
              price: _bulk5Price,
              onCountChanged: (value) => setState(() {
                _bulk5Count = value;
                _recalculate();
              }),
              onPriceChanged: () => setState(_recalculate),
            ),
            _BulkCard(
              label: context.l10n.completionBulk10l,
              count: _bulk10Count,
              price: _bulk10Price,
              onCountChanged: (value) => setState(() {
                _bulk10Count = value;
                _recalculate();
              }),
              onPriceChanged: () => setState(_recalculate),
            ),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stop = widget.stop;

    return DetailScaffold(
      title: context.l10n.completionTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(stop.customerName,
                    style: AppTypography.bodyStrong.copyWith(color: t.text)),
                Row(
                  spacing: 4,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: t.text2),
                    Expanded(
                      child: Text(stop.customerAddress,
                          style:
                              AppTypography.secondary.copyWith(color: t.text2)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.location != null)
            LabeledCard(
              label: context.l10n.completionCoordinates,
              child: _LocationRow(
                fix: _fix,
                locating: _locating,
                onRetry: submitting ? null : _captureLocation,
              ),
            ),
          // Комментарий админа — до счётчиков и общий для всех целей: его
          // пишут ради того, чтобы водитель прочитал до доставки, а не после.
          if (widget.stop.comment case final String comment)
            _CommentCard(comment: comment),
          ..._purposeSections(context),
          LabeledCard(
            label: context.l10n.completionMethod,
            child: SegmentedToggle<PaymentMethod>(
              value: _method,
              columns: 2,
              onChanged: _onMethodChanged,
              options: [
                for (final method in PaymentMethod.values)
                  SegmentOption(
                      value: method, label: method.label(context.l10n)),
              ],
            ),
          ),
          LabeledCard(
            label: context.l10n.completionAmount,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        // В долг сумму не правят: сервер примет только ноль.
                        readOnly: _isDebt,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        // Правка руками отвязывает сумму от расчёта:
                        // программная подстановка сюда не приходит.
                        onChanged: (_) =>
                            setState(() => _amountLocked = true),
                        style:
                            AppTypography.statNumber.copyWith(color: t.text),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    Text(context.l10n.commonSum,
                        style:
                            AppTypography.secondary.copyWith(color: t.text2)),
                  ],
                ),
                // Сначала то, что мешает отправить, и лишь потом пояснения:
                // у вывоза способ по умолчанию «в долг», и подсказка про долг
                // перекрывала собой причину, по которой кнопка не нажимается.
                if (_amountOrNull == null)
                  Text(context.l10n.completionAmountRequired,
                      style: AppTypography.secondary.copyWith(color: t.danger))
                else if (_pickupEmpty)
                  Text(context.l10n.completionPickupRequired,
                      style: AppTypography.secondary.copyWith(color: t.danger))
                else if (_deliveryEmpty)
                  Text(context.l10n.completionDeliveryRequired,
                      style: AppTypography.secondary.copyWith(color: t.danger))
                else if (_bulkPriceMissing)
                  Text(context.l10n.completionBulkPriceRequired,
                      style: AppTypography.secondary.copyWith(color: t.danger))
                else if (_zeroAmountConflict)
                  Text(context.l10n.completionZeroNeedsDebt,
                      style: AppTypography.secondary.copyWith(color: t.danger))
                else if (_isDebt)
                  // Ноль в поле — это не «привезли бесплатно»: стоимость
                  // целиком уходит заказчику в долг, и водитель должен
                  // видеть, сколько именно ему записали.
                  Text(
                    context.l10n.completionDebtHint,
                    style: AppTypography.secondary.copyWith(color: t.text2),
                  )
                else if (_customPrice case final int customPrice)
                  // Подпись про договорную сумму вместо формулы по прайсу:
                  // счётчики здесь деньги не двигают. У вывоза — то же
                  // самое: сумма от админа, а не ноль.
                  _CustomPriceHint(
                    amount: customPrice,
                    onRestore: _amount == _calculatedAmount
                        ? null
                        : _restoreCalculatedAmount,
                  )
                else if (_purpose == OrderPurpose.pickup)
                  // Сюда попадают только с суммой больше нуля не в долг:
                  // водитель взял деньги за вывоз, о котором админ цены не
                  // задавал, — по договорённости на месте.
                  Text(context.l10n.completionPickupHint,
                      style: AppTypography.secondary.copyWith(color: t.text2))
                else if (_purpose == OrderPurpose.delivery19l)
                  _AmountHint(
                    capsules: _capsules,
                    price: _capsulePrice,
                    damaged: _damaged,
                    fine: _damagedFine,
                    returned: _returnedFull,
                    // Кнопка возврата нужна, только если сумма разошлась
                    // с расчётом: иначе возвращать нечего.
                    onRestore: _amount == _calculatedAmount
                        ? null
                        : _restoreCalculatedAmount,
                  ),
              ],
            ),
          ),
          // Подтверждать снимком есть что только у карты: перевод виден в
          // банковском приложении. У наличных и долга фотографировать нечего.
          if (_method.needsPhoto)
            PhotoAttachTile(
              photo: _photo,
              enabled: !submitting,
              onChanged: (photo) => setState(() => _photo = photo),
            ),
          if (submitError != null)
            Text(submitError!,
                style: AppTypography.secondary.copyWith(color: t.danger)),
        ],
      ),
      bottomBar: BottomActionBar(
        filled: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.l10n.completionTotal,
                    style: AppTypography.secondary.copyWith(color: t.text2)),
                Text(MoneyFormatter.sum(context.l10n, _amount),
                    style: AppTypography.money
                        .copyWith(fontSize: 18, color: t.text)),
              ],
            ),
            // Отдельной строкой, а не вместо итога: принято ноль и начислено
            // N — это два разных числа, и подменять одно другим нельзя.
            if (_isDebt && _debtAmount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.l10n.completionDebtLine,
                      style:
                          AppTypography.secondary.copyWith(color: t.text2)),
                  Text(MoneyFormatter.sum(context.l10n, _debtAmount),
                      style: AppTypography.money
                          .copyWith(fontSize: 18, color: t.danger)),
                ],
              ),
            AppButton(
              label: submitting ? context.l10n.commonSaving : context.l10n.completionSubmit,
              // Пустое поле суммы отправлять нельзя: на сервер ушёл бы ноль,
              // неотличимый от осознанной оплаты в долг. Опт без цены сервер
              // отвергнет сам — упираться в отказ у заказчика незачем.
              enabled: _canSubmit,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Состояние снятия координат: идёт замер, точка зафиксирована или причина
/// отказа с возможностью повторить.
/// Причина отказа геолокации словами. Отказ проговариваем, но подчёркиваем,
/// что он не мешает: адрес заказчика для маршрута всё равно остаётся.
String _failureText(BuildContext context, LocationFailure? failure) {
  final l10n = context.l10n;
  final reason = switch (failure) {
    LocationFailure.serviceDisabled => l10n.locationDisabled,
    LocationFailure.deniedForever => l10n.locationDeniedForever,
    LocationFailure.denied => l10n.locationDenied,
    LocationFailure.unknown => l10n.locationUnknown,
    null => '',
  };
  return '$reason ${l10n.locationCanContinue}'.trim();
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.fix,
    required this.locating,
    required this.onRetry,
  });

  final LocationFix? fix;
  final bool locating;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (locating) {
      return Row(
        spacing: AppSpacing.sm,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.text2),
          ),
          Text(context.l10n.locationSearching,
              style: AppTypography.secondary.copyWith(color: t.text2)),
        ],
      );
    }

    final current = fix;
    final failed = current == null || !current.isSuccess;

    return Row(
      spacing: AppSpacing.sm,
      children: [
        Icon(
          failed ? Icons.location_off_outlined : Icons.my_location,
          size: 18,
          color: failed ? t.text2 : t.success,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                failed ? context.l10n.locationNotFixed : context.l10n.locationFixed,
                style: AppTypography.bodyStrong.copyWith(color: t.text),
              ),
              Text(
                // Отказ проговариваем, но подчёркиваем, что он не мешает:
                // адрес заказчика для маршрута всё равно остаётся.
                failed
                    ? _failureText(context, current?.failure)
                    : '${current.latitude}, ${current.longitude}',
                style: AppTypography.secondary.copyWith(color: t.text2),
              ),
            ],
          ),
        ),
        if (failed)
          IconActionButton(
            icon: Icons.refresh,
            tooltip: context.l10n.locationRetry,
            size: 36,
            onPressed: onRetry,
          ),
      ],
    );
  }
}

/// Остаток заказчика после доставки: прежний склад плюс привезённое.
///
/// Показывается числом, а не счётчиком: сервер этим значением **заменяет**
/// склад клиента, и правка рукой уходила бы прямо в учёт. Слагаемые под
/// числом — чтобы водитель видел, из чего оно сложилось.
class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({
    required this.before,
    required this.delivered,
    this.returned = 0,
  });

  final int before;
  final int delivered;

  /// Возвращено с водой — вычитаемое показываем, только когда оно есть.
  final int returned;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: Column(
        spacing: 2,
        children: [
          Text('${before + delivered - returned}',
              style: AppTypography.statNumber.copyWith(color: t.text)),
          Text(
            returned > 0
                ? l10n.completionBalanceFormulaReturned(
                    before, delivered, returned)
                : l10n.completionBalanceFormula(before, delivered),
            style: AppTypography.secondary.copyWith(color: t.text2),
          ),
        ],
      ),
    );
  }
}

/// Подпись под суммой: по какому расчёту она получилась и как его вернуть.
class _AmountHint extends StatelessWidget {
  const _AmountHint({
    required this.capsules,
    required this.price,
    required this.damaged,
    required this.fine,
    required this.onRestore,
    this.returned = 0,
  });

  final int capsules;
  final int price;

  /// Возврат с водой: вычитаемое показываем, только когда оно есть, и рядом
  /// напоминаем, что итог по нему — за сервером.
  final int returned;

  /// Брак и штраф за него: показываем слагаемое, только когда оно есть, —
  /// иначе водитель видел бы «+ брак 0 × 0» на каждой обычной доставке.
  final int damaged;
  final int fine;

  /// null — сумма совпадает с расчётом, возвращать нечего.
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final formula = damaged > 0 && fine > 0
        ? l10n.completionFormulaDamaged(
            '$capsules',
            MoneyFormatter.sum(l10n, price),
            '$damaged',
            MoneyFormatter.sum(l10n, fine),
          )
        : '$capsules × ${MoneyFormatter.sum(l10n, price)}';
    final withReturn = returned > 0
        ? '$formula ${l10n.completionFormulaReturnedPart(
            '$returned', MoneyFormatter.sum(l10n, price))}'
        : formula;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Row(
          spacing: AppSpacing.sm,
          children: [
            Expanded(
              child: Text(
                context.l10n.completionByPrice(withReturn),
                style: AppTypography.secondary.copyWith(color: t.text2),
              ),
            ),
            if (onRestore != null)
              GestureDetector(
                onTap: onRestore,
                child: Text(context.l10n.completionRestoreAmount,
                    style: AppTypography.secondary.copyWith(
                      color: t.primary,
                      fontWeight: FontWeight.w700,
                    )),
              ),
          ],
        ),
        if (returned > 0)
          Text(
            l10n.completionReturnedFullHint,
            style: AppTypography.secondary.copyWith(color: t.text2),
          ),
      ],
    );
  }
}

/// Карточка с капс-подписью сверху и произвольным содержимым.
/// Строка опта: сколько бутылей и по какой цене.
///
/// Цену вводит водитель, а не подставляет прайс: у пятилитровок и
/// десятилитровок она договорная, у сервера её нет вовсе. Количество без
/// цены он отвергает (422), поэтому поле не спрятано и не необязательно.
class _BulkCard extends StatelessWidget {
  const _BulkCard({
    required this.label,
    required this.count,
    required this.price,
    required this.onCountChanged,
    required this.onPriceChanged,
  });

  final String label;
  final int count;
  final TextEditingController price;
  final ValueChanged<int> onCountChanged;
  final VoidCallback onPriceChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return LabeledCard(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          QuantityStepper(
            value: count,
            min: 0,
            onChanged: onCountChanged,
            caption: context.l10n.completionBulkCount,
          ),
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => onPriceChanged(),
                  style: AppTypography.bodyStrong.copyWith(color: t.text),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: context.l10n.completionBulkPrice,
                    hintStyle:
                        AppTypography.secondary.copyWith(color: t.text3),
                  ),
                ),
              ),
              Text(context.l10n.commonSum,
                  style: AppTypography.secondary.copyWith(color: t.text2)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Задание к доставке: сколько капсул назначил админ.
///
/// Отдельной карточкой над счётчиками, а не подписью у поля: это не то же
/// самое, что «привезено». Число из заказа, водитель его не правит — если
/// повезёт другое количество, он отметит факт ниже, и сервер увидит
/// расхождение.
/// Комментарий админа к точке. Только показ: менять его водителю нечем — да
/// и сервер правки комментария не умеет.
class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final String comment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        spacing: AppSpacing.md,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 20, color: t.primary),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(l10n.orderCommentTitle,
                    style: AppTypography.fieldLabel.copyWith(color: t.primary)),
                Text(comment,
                    style: AppTypography.bodyStrong.copyWith(color: t.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottleSellCard extends StatelessWidget {
  const _BottleSellCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Icon(Icons.assignment_outlined, size: 20, color: t.primary),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(l10n.completionBottleSell,
                    style: AppTypography.fieldLabel.copyWith(color: t.primary)),
                Text(l10n.completionBottleSellValue(count),
                    style: AppTypography.bodyStrong.copyWith(color: t.text)),
                Text(l10n.completionBottleSellHint,
                    style: AppTypography.secondary.copyWith(color: t.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Подпись под суммой при договорной цене заказа: откуда сумма и как её
/// вернуть после ручной правки.
class _CustomPriceHint extends StatelessWidget {
  const _CustomPriceHint({required this.amount, required this.onRestore});

  final int amount;

  /// null — сумма совпадает с договорной, возвращать нечего.
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    return Row(
      spacing: AppSpacing.sm,
      children: [
        Expanded(
          child: Text(
            l10n.completionByCustomPrice(MoneyFormatter.sum(l10n, amount)),
            style: AppTypography.secondary.copyWith(color: t.text2),
          ),
        ),
        if (onRestore != null)
          GestureDetector(
            onTap: onRestore,
            child: Text(l10n.completionRestoreAmount,
                style: AppTypography.secondary.copyWith(
                  color: t.primary,
                  fontWeight: FontWeight.w700,
                )),
          ),
      ],
    );
  }
}

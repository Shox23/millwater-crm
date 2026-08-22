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
  late int _capsules;

  /// Сколько капсул остаётся у заказчика после доставки. Сервер перезаписывает
  /// им остаток, а водительские эндпоинты текущего остатка не отдают —
  /// поэтому число вводит водитель, который видит склад клиента.
  late int _bottleBalance;

  /// Остаток правили вручную — перестаём тянуть его за количеством.
  bool _balanceLocked = false;

  /// Сумму правили вручную — расчёт за водителем её больше не перебивает.
  /// Так закрываются частичная оплата и долг: цифра остаётся его.
  bool _amountLocked = false;

  PaymentMethod _method = PaymentMethod.cash;
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
    _bottleBalance = _capsules;
    // Ранее введённая сумма важнее расчёта: значит, доставку уже проводили.
    final amount = widget.stop.paymentAmount ?? _capsules * _capsulePrice;
    _amountLocked = widget.stop.paymentAmount != null;
    _amountController = TextEditingController(text: '$amount');
    _loadPrice();
  }

  /// Цена капсулы, по которой считается сумма.
  ///
  /// Начинается со значения сборки и заменяется живым прайсом, если сервер
  /// его отдал, — см. [_loadPrice]. Ждать ответа экран не может: водитель
  /// стоит у двери, и пустое поле суммы ему дороже точной цены.
  int _capsulePrice = ProductConfig.capsulePrice;

  /// Спрашивает живую цену и пересчитывает сумму под неё.
  ///
  /// Пересчёт только пока сумму не назначили вручную: [_amountLocked] стоит и
  /// у доставки, которую уже проводили, — затирать введённое число ответом
  /// сервера значило бы менять принятую оплату за спиной водителя.
  Future<void> _loadPrice() async {
    final price = await widget.price.value();
    if (!mounted || price == _capsulePrice) return;
    setState(() {
      _capsulePrice = price;
      if (!_amountLocked) _amountController.text = '$_calculatedAmount';
    });
  }

  /// Сколько должно получиться по прайсу: капсулы × цена.
  int get _calculatedAmount => _capsules * _capsulePrice;

  void _onCapsulesChanged(int value) {
    setState(() {
      _capsules = value;
      // Обычный случай — привезли и столько же оставили; если водитель
      // поправил остаток сам, его значение больше не трогаем.
      if (!_balanceLocked) _bottleBalance = value;
      // Сумма идёт за количеством, пока водитель не назначил свою.
      if (!_amountLocked) _amountController.text = '$_calculatedAmount';
    });
  }

  /// Смена способа оплаты.
  ///
  /// Уход с карты стирает уже прикреплённый снимок: тайл исчезает с экрана, и
  /// оставшееся фото ушло бы на сервер незаметно для водителя — приложенным к
  /// оплате, которая его не предполагает.
  void _onMethodChanged(PaymentMethod method) {
    setState(() {
      _method = method;
      if (!method.needsPhoto) _photo = null;
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
        capsules: _capsules,
        amount: _amount,
        bottleBalance: _bottleBalance,
        method: _method,
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
            _LabeledCard(
              label: context.l10n.completionCoordinates,
              child: _LocationRow(
                fix: _fix,
                locating: _locating,
                onRetry: submitting ? null : _captureLocation,
              ),
            ),
          _LabeledCard(
            label: context.l10n.completionCapsules,
            child: QuantityStepper(
              value: _capsules,
              // Завершать доставку с нулём капсул нечего: это «не доставлено».
              min: 1,
              onChanged: _onCapsulesChanged,
              caption: context.l10n.completionCapsulesCaption(
                  ProductConfig.capsuleVolumeLiters),
            ),
          ),
          _LabeledCard(
            label: context.l10n.completionBalance,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: [
                QuantityStepper(
                  value: _bottleBalance,
                  min: 0,
                  onChanged: (value) => setState(() {
                    _bottleBalance = value;
                    _balanceLocked = true;
                  }),
                  caption: context.l10n.completionBalanceCaption,
                ),
                // Сервер этим числом ЗАМЕНЯЕТ остаток заказчика, а подставлено
                // сюда количество привезённых — правильного значения взять
                // негде, водительские эндпоинты остатка не отдают. Пока
                // счётчик не трогали, предупреждаем: не тронув его, водитель
                // молча затрёт склад клиента.
                if (!_balanceLocked) const _BalanceWarning(),
              ],
            ),
          ),
          _LabeledCard(
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
          _LabeledCard(
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
                if (_amountOrNull == null)
                  Text(context.l10n.completionAmountRequired,
                      style: AppTypography.secondary.copyWith(color: t.danger))
                else
                  _AmountHint(
                    capsules: _capsules,
                    price: _capsulePrice,
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
            AppButton(
              label: submitting ? context.l10n.commonSaving : context.l10n.completionSubmit,
              // Пустое поле суммы отправлять нельзя: на сервер ушёл бы ноль,
              // неотличимый от осознанной оплаты в долг.
              enabled: !submitting && _amountOrNull != null,
              onPressed:
                  (submitting || _amountOrNull == null) ? null : _submit,
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

/// Предупреждение под счётчиком остатка.
///
/// Висит, пока водитель не подтвердил число своей рукой: значение по умолчанию
/// равно привезённому количеству, а уходит оно на сервер как новый остаток
/// заказчика — не сверив со складом, легко стереть то, что там уже было.
class _BalanceWarning extends StatelessWidget {
  const _BalanceWarning();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.warnBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        spacing: AppSpacing.sm,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: t.warn),
          Expanded(
            child: Text(
              context.l10n.completionBalanceUnchecked,
              style: AppTypography.secondary.copyWith(color: t.warn),
            ),
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
    required this.onRestore,
  });

  final int capsules;
  final int price;

  /// null — сумма совпадает с расчётом, возвращать нечего.
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final formula = '$capsules × ${MoneyFormatter.sum(context.l10n, price)}';

    return Row(
      spacing: AppSpacing.sm,
      children: [
        Expanded(
          child: Text(
            context.l10n.completionByPrice(formula),
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
    );
  }
}

/// Карточка с капс-подписью сверху и произвольным содержимым.
class _LabeledCard extends StatelessWidget {
  const _LabeledCard({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Text(label, style: AppTypography.fieldLabel.copyWith(color: t.text2)),
          child,
        ],
      ),
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/utils/day.dart';
import '../../../core/utils/idempotency.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/uz_phone.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../../../core/widgets/segmented_toggle.dart';
import '../../../data/models/customer.dart';
import '../../../data/network/api_envelope.dart';
import '../../../core/forms/balance_kind.dart';
import '../../../data/repositories/crm_repository.dart';


/// Форма создания/редактирования заказчика.
class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({super.key, this.customer});

  final Customer? customer;

  bool get isEdit => customer != null;

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> with SubmitState {
  /// Правила проверки на языке интерфейса. Пересобираются при смене
  /// локали: `didChangeDependencies` вызывается снова.
  late Validators _v;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _v = Validators(context.l10n);
  }

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _comment;

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _commentFocus = FocusNode();
  final _balanceFocus = FocusNode();
  final _priceFocus = FocusNode();

  /// Сколько кулеров стоит у заказчика.
  ///
  /// Пришло на смену переключателю «есть кулер»: булево значение мигрирует
  /// само — `hasCooler` у модели теперь производное от количества.
  late int _coolerCount;

  /// Остаток капсул у заказчика. Уходит на сервер только когда админ его
  /// правил: остаток ведёт водитель, и присланным числом сервер **заменяет**
  /// его целиком — см. [_capsulesChanged].
  late int _capsuleBalance;

  /// Стартовый баланс: долг, предоплата или ничего.
  ///
  /// Одно поле суммы, а не два: сервер запрещает ненулевой долг вместе с
  /// ненулевой предоплатой (422 `BOTH_BALANCES_SET`), и форма не должна
  /// давать собрать состояние, которое он отвергнет.
  late BalanceKind _balanceKind;
  late final TextEditingController _balance;

  /// Цена капсулы для этого заказчика; выключено — считаем по общему прайсу.
  late bool _customPrice;
  late final TextEditingController _price;

  /// Действующая общая цена — под полем видно, от чего отступает админ.
  /// `null`, пока прайс не пришёл: показывать нечего, но и мешать нечему.
  int? _listPrice;

  /// Заказчик в работе. Только для правки: нового сервер и так заводит
  /// активным, отдельного поля в `CreateCustomer` нет.
  late bool _isActive;

  /// Когда заказчик брал воду в последний раз. `null` — не известно.
  ///
  /// Обычно дату ставит закрытие доставки, но заказчика, перенесённого из
  /// старой базы, иначе не отличить от новичка — и список не подсветит его,
  /// когда он замолчит. Уходит на сервер только когда админ её трогал —
  /// см. [_lastOrderDateChanged].
  DateTime? _lastOrderDate;

  /// Один ключ на весь экран: повтор после обрыва связи не должен завести
  /// второго заказчика. При редактировании не нужен — PATCH идемпотентен.
  final String _idempotencyKey = newIdempotencyKey('customer');

  // Правила живут в полях, чтобы поле и переход к первой ошибке
  // проверялись одним и тем же кодом.
  FormFieldValidator<String> get _nameRule => Validators.all([
    _v.notEmpty(context.l10n.customerFormNameEmpty),
    _v.maxLen(120),
  ]);
  FormFieldValidator<String> get _addressRule => Validators.all([
    _v.notEmpty(context.l10n.customerFormAddressEmpty),
    _v.maxLen(200),
  ]);
  FormFieldValidator<String> get _commentRule => _v.maxLen(300);

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer?.name ?? '');
    // У нового заказчика в поле уже стоит код страны — его не надо набирать.
    _phone = TextEditingController(
      text: customer == null ? UzPhone.prefix : UzPhone.format(customer.phone),
    );
    _address = TextEditingController(text: customer?.address ?? '');
    _comment = TextEditingController(text: customer?.comment ?? '');
    _coolerCount = customer?.coolerCount ?? 0;
    _capsuleBalance = customer?.capsuleBalance ?? 0;
    _isActive = customer?.isActive ?? true;
    _lastOrderDate = customer?.lastOrderDate;

    _balanceKind = switch (customer) {
      Customer(debt: > 0) => BalanceKind.debt,
      Customer(prepayment: > 0) => BalanceKind.prepayment,
      _ => BalanceKind.none,
    };
    _balance = TextEditingController(text: switch (_balanceKind) {
      BalanceKind.debt => '${customer!.debt}',
      BalanceKind.prepayment => '${customer!.prepayment}',
      BalanceKind.none => '',
    });

    _customPrice = customer?.hasIndividualPrice ?? false;
    _price = TextEditingController(
      text: customer?.customWaterPrice?.toString() ?? '',
    );

    _loadListPrice();
  }

  /// Подтягивает действующую цену капсулы для подсказки под полем.
  ///
  /// Молча: подсказка — удобство, а не условие сохранения, и упавший запрос
  /// за прайсом не повод мешать админу заводить заказчика.
  Future<void> _loadListPrice() async {
    try {
      final prices = await context.read<CrmRepository>().getPrices();
      if (mounted) setState(() => _listPrice = prices.capsulePrice);
    } catch (_) {
      // Подсказки просто не будет.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _comment.dispose();
    _balance.dispose();
    _price.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _addressFocus.dispose();
    _commentFocus.dispose();
    _balanceFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  /// Введённая сумма баланса; 0 — поле пустое или не число.
  int get _balanceAmount => int.tryParse(_balance.text.trim()) ?? 0;

  int get _debt => _balanceKind == BalanceKind.debt ? _balanceAmount : 0;
  int get _prepayment =>
      _balanceKind == BalanceKind.prepayment ? _balanceAmount : 0;

  /// Индивидуальная цена; `null` — считать по общему прайсу.
  int? get _customWaterPrice {
    if (!_customPrice) return null;
    final value = int.tryParse(_price.text.trim()) ?? 0;
    return value > 0 ? value : null;
  }

  String? get _commentOrNull =>
      _comment.text.trim().isEmpty ? null : _comment.text.trim();

  /// Форму меняли — уход без сохранения нужно подтвердить.
  bool get _dirty {
    final customer = widget.customer;
    return _name.text.trim() != (customer?.name ?? '') ||
        UzPhone.normalize(_phone.text) !=
            UzPhone.normalize(customer?.phone ?? '') ||
        _address.text.trim() != (customer?.address ?? '') ||
        _comment.text.trim() != (customer?.comment ?? '') ||
        _coolerCount != (customer?.coolerCount ?? 0) ||
        _capsulesChanged ||
        _balanceChanged ||
        _lastOrderDateChanged ||
        _customWaterPrice != customer?.customWaterPrice ||
        _isActive != (customer?.isActive ?? true);
  }

  /// Дату последнего заказа правили руками — только тогда она уйдёт.
  ///
  /// Причина та же, что у капсул и баланса: пока форма открыта, водитель
  /// мог закрыть доставку и сдвинуть дату; форма, отправив «свою», откатила
  /// бы её. Сравниваем по дням: календарь отдаёт полночь, а сервер — момент
  /// закрытия доставки, и без этого тот же день выглядел бы правкой.
  bool get _lastOrderDateChanged {
    final was = widget.customer?.lastOrderDate;
    final now = _lastOrderDate;
    if (was == null || now == null) return was != now;
    return dayOnly(was) != dayOnly(now);
  }

  Future<void> _pickLastOrderDate() async {
    final today = dayOnly(DateTime.now());
    final initial = _lastOrderDate == null ? today : dayOnly(_lastOrderDate!);
    var first = DateTime(today.year - 10, today.month, today.day);
    // Дата из базы может быть старше окна — календарь падал бы на ассерте
    // SDK: initialDate раньше firstDate.
    if (initial.isBefore(first)) first = initial;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      // Будущее сервер отвергнет (422 LAST_ORDER_DATE_FUTURE) — календарь
      // туда и не пускает.
      lastDate: today,
    );
    if (picked != null) setState(() => _lastOrderDate = dayOnly(picked));
  }

  /// Остаток капсул правили руками — только тогда он уйдёт на сервер.
  ///
  /// Пока админ правит телефон, водитель может закрыть доставку и изменить
  /// остаток. Отправив «своё» число, форма затёрла бы этот склад значением,
  /// которое было в ней при открытии.
  bool get _capsulesChanged =>
      _capsuleBalance != (widget.customer?.capsuleBalance ?? 0);

  /// Баланс правили руками — только тогда он уйдёт на сервер.
  ///
  /// Иначе форма правки названия отправила бы долг, каким он был при её
  /// открытии, и откатила бы оплату, которую водитель принял тем временем.
  bool get _balanceChanged {
    final customer = widget.customer;
    return _debt != (customer?.debt ?? 0) ||
        _prepayment != (customer?.prepayment ?? 0);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      _focusFirstInvalid();
      return;
    }
    await _save();
  }

  /// Поля и их текущие ошибки — один источник и для кнопки, и для перехода
  /// к первой ошибке. Разъедься эти два списка, кнопка разрешала бы
  /// отправку формы, которую `validate()` тут же отклонит.
  ///
  /// Порядок — как на экране, адрес первым: иначе «первая ошибка» оказалась
  /// бы не верхней.
  List<(FocusNode, String?)> get _checks => [
        (_addressFocus, _addressRule(_address.text)),
        (_nameFocus, _nameRule(_name.text)),
        (_phoneFocus, _v.phone(_phone.text)),
        (_commentFocus, _commentRule(_comment.text)),
        (_balanceFocus, _balanceRule(_balance.text)),
        (_priceFocus, _priceRule(_price.text)),
      ];

  /// Сумма баланса обязательна, когда выбран долг или предоплата: «Долг» с
  /// пустым полем — это не ноль, а недозаполненная форма.
  String? _balanceRule(String? value) {
    if (_balanceKind == BalanceKind.none) return null;
    final amount = int.tryParse((value ?? '').trim()) ?? 0;
    return amount > 0 ? null : context.l10n.customerFormBalanceEmpty;
  }

  /// То же для индивидуальной цены: включённый переключатель без цены
  /// сервер отвергнет (`custom_water_price` должен быть больше нуля).
  String? _priceRule(String? value) {
    if (!_customPrice) return null;
    final amount = int.tryParse((value ?? '').trim()) ?? 0;
    return amount > 0 ? null : context.l10n.customerFormPriceEmpty;
  }

  /// Все поля заполнены верно — кнопку можно разблокировать.
  bool get _valid => _checks.every((c) => c.$2 == null);

  /// Ставит курсор в первое поле с ошибкой — иначе непонятно, куда смотреть.
  void _focusFirstInvalid() {
    for (final (node, error) in _checks) {
      if (error != null) {
        node.requestFocus();
        return;
      }
    }
  }

  Future<void> _save() async {
    final repo = context.read<CrmRepository>();
    // Строки берём до запроса: после await контекст уже мог уйти.
    final l10n = context.l10n;
    final phone = UzPhone.normalize(_phone.text);

    final saved = await submit(
      () => widget.isEdit
          ? repo.updateCustomer(
              widget.customer!.copyWith(
                name: _name.text.trim(),
                phone: phone,
                address: _address.text.trim(),
                comment: _commentOrNull,
                coolerCount: _coolerCount,
                capsuleBalance: _capsuleBalance,
                debt: _debt,
                prepayment: _prepayment,
                customWaterPrice: _customWaterPrice,
                isActive: _isActive,
                lastOrderDate: _lastOrderDate,
              ),
              balanceChanged: _balanceChanged,
              capsulesChanged: _capsulesChanged,
              lastOrderDateChanged: _lastOrderDateChanged,
            )
          : repo.addCustomer(
              name: _name.text.trim(),
              phone: phone,
              address: _address.text.trim(),
              comment: _commentOrNull,
              coolerCount: _coolerCount,
              capsuleBalance: _capsuleBalance,
              debt: _debt,
              prepayment: _prepayment,
              customWaterPrice: _customWaterPrice,
              lastOrderDate: _lastOrderDate,
              idempotencyKey: _idempotencyKey,
            ),
      // Сервер может отклонить и валидные с виду данные: занятый телефон,
      // упавшая сеть.
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.customerFormSaveFailed)
          : l10n.customerFormSaveFailed,
    );

    if (saved && mounted) Navigator.of(context).pop(true);
  }

  /// Закрытие формы: при изменённых данных спрашиваем подтверждение.
  Future<void> _leave() async {
    if (!_dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    final leave = await showConfirmDialog(
      context,
      title: context.l10n.leaveWithoutSavingTitle,
      message: context.l10n.leaveWithoutSavingMessage,
      confirmLabel: context.l10n.commonLeave,
      cancelLabel: context.l10n.commonStay,
    );
    if (leave && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Не `false`: наглухо запрещённый pop гасит краевой жест «назад» на
      // iOS (`PageRoute.popGestureEnabled`). Пока форму не трогали, уходить
      // не жалко — и жест работает; тронутую перехватываем и переспрашиваем.
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: DetailScaffold(
        title: widget.isEdit ? context.l10n.customerFormEditTitle : context.l10n.customerFormNewTitle,
        body: Form(
          key: _formKey,
          // Ошибка появляется, когда поле закончили заполнять и ушли из него.
          autovalidateMode: AutovalidateMode.onUnfocus,
          // Любое изменение — пересчёт состояния кнопки.
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.lg,
            children: [
              // Адрес первым: заказчика заводят с точки доставки, название
              // узнают уже на месте. Вместе с полем наверх уехали автофокус
              // и первый шаг цепочки «Далее» — курсор идёт сверху вниз.
              LabeledTextField(
                label: context.l10n.customerFormAddress,
                hint: context.l10n.customerFormAddressHint,
                controller: _address,
                focusNode: _addressFocus,
                validator: _addressRule,
                maxLength: 200,
                autofocus: !widget.isEdit,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _nameFocus.requestFocus(),
              ),
              LabeledTextField(
                label: context.l10n.customerFormName,
                hint: context.l10n.customerFormNameHint,
                controller: _name,
                focusNode: _nameFocus,
                validator: _nameRule,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _phoneFocus.requestFocus(),
              ),
              LabeledTextField(
                label: context.l10n.loginPhone,
                hint: '+998 90 123 45 67',
                controller: _phone,
                focusNode: _phoneFocus,
                validator: _v.phone,
                keyboardType: TextInputType.phone,
                inputFormatters: const [UzPhoneInputFormatter()],
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _commentFocus.requestFocus(),
              ),
              LabeledTextField(
                label: context.l10n.customerFormComment,
                hint: context.l10n.customerFormCommentHint,
                helper: context.l10n.commonOptional,
                controller: _comment,
                focusNode: _commentFocus,
                validator: _commentRule,
                maxLength: 300,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              // Кулеры считаем штуками: у офиса их бывает несколько, и на
              // вывозе водителю надо знать, сколько забирать. Прежний
              // переключатель «есть кулер» мигрирует сам — 0 или 1.
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.md,
                  children: [
                    Text(
                      context.l10n.customerFormCoolers,
                      style: AppTypography.bodyStrong
                          .copyWith(color: context.tokens.text),
                    ),
                    QuantityStepper(
                      value: _coolerCount,
                      max: 10,
                      caption: context.l10n.customerFormCoolersHint,
                      onChanged: submitting
                          ? (_) {}
                          : (value) => setState(() => _coolerCount = value),
                    ),
                  ],
                ),
              ),
              // Капсулы на руках: тара, которую заказчик держит у себя. У
              // нового её задают сразу — он приходит со своими бутылями от
              // прежнего поставщика, и без этого числа первая же доставка
              // разошлась бы со складом.
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.md,
                  children: [
                    Text(
                      context.l10n.customerFormCapsules,
                      style: AppTypography.bodyStrong
                          .copyWith(color: context.tokens.text),
                    ),
                    QuantityStepper(
                      value: _capsuleBalance,
                      max: 99,
                      caption: context.l10n.customerFormCapsulesHint,
                      onChanged: submitting
                          ? (_) {}
                          : (value) =>
                              setState(() => _capsuleBalance = value),
                    ),
                    // Предупреждаем только при правке и только когда число
                    // тронули: у нового заказчика перезаписывать нечего.
                    if (widget.isEdit && _capsulesChanged)
                      Text(
                        context.l10n.customerFormCapsulesLocked,
                        style: AppTypography.secondary
                            .copyWith(color: context.tokens.warn),
                      ),
                  ],
                ),
              ),
              _LastOrderBlock(
                date: _lastOrderDate,
                // Предупреждение по тому же правилу, что у капсул.
                locked: widget.isEdit && _lastOrderDateChanged,
                onTap: submitting ? null : _pickLastOrderDate,
              ),
              _BalanceBlock(
                kind: _balanceKind,
                controller: _balance,
                focusNode: _balanceFocus,
                validator: _balanceRule,
                enabled: !submitting,
                onKindChanged: (kind) => setState(() {
                  _balanceKind = kind;
                  // «Нет» стирает сумму: иначе она осталась бы в поле и
                  // вернулась бы при следующем переключении, а на сервер
                  // ушёл бы ноль — расхождение видимого и отправленного.
                  if (kind == BalanceKind.none) _balance.clear();
                }),
              ),
              _PriceBlock(
                custom: _customPrice,
                controller: _price,
                focusNode: _priceFocus,
                validator: _priceRule,
                listPrice: _listPrice,
                enabled: !submitting,
                onModeChanged: (custom) => setState(() {
                  _customPrice = custom;
                  if (!custom) _price.clear();
                }),
              ),
              // Только в правке: у нового заказчика выключать нечего, да и
              // `CreateCustomer` такого поля не принимает.
              if (widget.isEdit)
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              context.l10n.customerFormIsActive,
                              style: AppTypography.bodyStrong
                                  .copyWith(color: context.tokens.text),
                            ),
                            Text(
                              context.l10n.customerFormIsActiveHint,
                              style: AppTypography.secondary
                                  .copyWith(color: context.tokens.text2),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isActive,
                        onChanged: submitting
                            ? null
                            : (value) => setState(() => _isActive = value),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        bottomBar: BottomActionBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              if (submitError != null)
                Text(
                  submitError!,
                  style: AppTypography.secondary
                      .copyWith(color: context.tokens.danger),
                  textAlign: TextAlign.center,
                ),
              Row(
                spacing: AppSpacing.md,
                children: [
                  Expanded(
                    child: AppButton(
                      label: context.l10n.commonCancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: submitting ? null : _leave,
                    ),
                  ),
                  Expanded(
                    child: AppButton(
                      label: submitting
                          ? context.l10n.commonSaving
                          : (widget.isEdit ? context.l10n.commonSave : context.l10n.commonAdd),
                      // Пока в форме есть ошибки, отправлять нечего.
                      enabled: _valid && !submitting,
                      onPressed: (_valid && !submitting) ? _submit : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Дата последнего заказа: день в карточке-кнопке, календарь по нажатию.
///
/// Стереть выбранное нельзя намеренно: сервер `null` в PATCH пропускает как
/// «не менять», и крестик обещал бы то, чего не случится. Дату можно только
/// заменить.
class _LastOrderBlock extends StatelessWidget {
  const _LastOrderBlock({
    required this.date,
    required this.locked,
    required this.onTap,
  });

  final DateTime? date;

  /// Показать, что правка заменит дату, которую ведёт закрытие доставки.
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final enabled = onTap != null;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Text(
            l10n.customerFormLastOrder,
            style: AppTypography.bodyStrong.copyWith(color: t.text),
          ),
          Row(
            spacing: AppSpacing.md,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: enabled ? t.primary : t.text3,
              ),
              Expanded(
                child: Text(
                  date == null
                      ? l10n.customerFormLastOrderNone
                      : DateFormat('dd.MM.yyyy').format(date!),
                  style: AppTypography.bodyStrong.copyWith(
                    color: date == null ? t.text2 : t.text,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: t.text2),
            ],
          ),
          Text(
            locked ? l10n.customerFormLastOrderLocked : l10n.customerFormLastOrderHint,
            style: AppTypography.secondary.copyWith(
              color: locked ? t.warn : t.text2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Стартовый баланс: чем задан и на сколько.
///
/// Переключатель и поле суммы живут вместе, потому что порознь они врут:
/// «Долг» без суммы и сумма без выбранного вида — оба состояния сервер
/// отвергнет, и увидеть это надо на экране, а не в ответе 422.
class _BalanceBlock extends StatelessWidget {
  const _BalanceBlock({
    required this.kind,
    required this.controller,
    required this.focusNode,
    required this.validator,
    required this.enabled,
    required this.onKindChanged,
  });

  final BalanceKind kind;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final ValueChanged<BalanceKind> onKindChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Text(
            l10n.customerFormBalance,
            style: AppTypography.bodyStrong.copyWith(color: context.tokens.text),
          ),
          SegmentedToggle<BalanceKind>(
            value: kind,
            onChanged: enabled ? onKindChanged : (_) {},
            columns: 3,
            options: [
              SegmentOption(
                value: BalanceKind.none,
                label: l10n.customerFormBalanceNone,
              ),
              SegmentOption(
                value: BalanceKind.debt,
                label: l10n.customerFormBalanceDebt,
              ),
              SegmentOption(
                value: BalanceKind.prepayment,
                label: l10n.customerFormBalancePrepayment,
              ),
            ],
          ),
          if (kind != BalanceKind.none)
            LabeledTextField(
              label: l10n.customerFormBalanceAmount,
              helper: l10n.customerFormBalanceHint,
              // Подсказка объясняет запрет сервера (422 BOTH_BALANCES_SET) —
              // обрезанная одной строкой, она обрывалась на «невозмо…» и
              // переставала объяснять, почему полей не два, а одно.
              helperMaxLines: 2,
              controller: controller,
              focusNode: focusNode,
              validator: validator,
              keyboardType: TextInputType.number,
              maxLength: 12,
            ),
        ],
      ),
    );
  }
}

/// Цена капсулы: по общему прайсу или своя.
class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.custom,
    required this.controller,
    required this.focusNode,
    required this.validator,
    required this.listPrice,
    required this.enabled,
    required this.onModeChanged,
  });

  final bool custom;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FormFieldValidator<String> validator;

  /// Действующая общая цена; `null` — прайс ещё не пришёл или не добыт.
  final int? listPrice;
  final bool enabled;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final price = listPrice;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Text(
            l10n.customerFormPrice,
            style: AppTypography.bodyStrong.copyWith(color: context.tokens.text),
          ),
          SegmentedToggle<bool>(
            value: custom,
            onChanged: enabled ? onModeChanged : (_) {},
            options: [
              SegmentOption(
                value: false,
                label: l10n.customerFormPriceDefault,
              ),
              SegmentOption(value: true, label: l10n.customerFormPriceCustom),
            ],
          ),
          if (custom)
            LabeledTextField(
              label: l10n.customerFormPriceValue,
              // Видно, от чего админ отступает: без общей цены рядом «15 000»
              // не читается ни как скидка, ни как наценка.
              helper: price == null
                  ? null
                  : l10n.customerFormPriceHelper(
                      MoneyFormatter.sum(l10n, price),
                    ),
              controller: controller,
              focusNode: focusNode,
              validator: validator,
              keyboardType: TextInputType.number,
              maxLength: 9,
            ),
        ],
      ),
    );
  }
}

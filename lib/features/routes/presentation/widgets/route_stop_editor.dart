import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../data/models/enums.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/route_draft.dart';

/// Редактор заказа в точке: цель, количество, договорная сумма, комментарий.
///
/// Общий у админа, собирающего маршрут (`RouteCreateStopCard`), и у водителя,
/// который добавляет заказ в свой маршрут по дороге: поля и их правила одни —
/// это одна и та же схема на сервере (`AddRouteCustomer`).
///
/// Состояние — [stop], редактор только сообщает изменения наверх. Текст полей
/// держит сам: количество меняют ещё степпер и пресеты, а цену — кнопка
/// «По прайсу».
class RouteStopEditor extends StatefulWidget {
  const RouteStopEditor({
    super.key,
    required this.stop,
    required this.unitPrice,
    required this.onPurpose,
    required this.onQty,
    required this.onPrice,
    required this.onComment,
    this.usualQty,
    this.compact = false,
    this.forDriver = false,
  });

  final RouteDraftStop stop;

  /// Цена капсулы для этого заказчика, сум; `null` — неизвестна.
  ///
  /// Водитель индивидуальной цены заказчика до добавления точки не знает:
  /// `GET /driver/customers` её не отдаёт. Тогда подсказки говорят «по цене
  /// заказчика» без числа — число по общему прайсу было бы неправдой для
  /// тех, у кого цена своя.
  final int? unitPrice;

  final ValueChanged<OrderPurpose> onPurpose;
  final ValueChanged<int> onQty;

  /// `null` — считать по прайсу.
  final ValueChanged<int?> onPrice;

  /// Комментарий к точке; `null` — комментария нет.
  final ValueChanged<String?> onComment;

  /// Обычный объём заказчика — из него берётся пресет «обычно N».
  final int? usualQty;

  /// Телефонная раскладка: касания крупнее.
  final bool compact;

  /// Форму заполняет водитель: подписи от его лица. Комментарий он пишет не
  /// «водителю», а себе и админу, а цену опта поставит сам при закрытии.
  final bool forDriver;

  @override
  State<RouteStopEditor> createState() => _RouteStopEditorState();
}

class _RouteStopEditorState extends State<RouteStopEditor> {
  late final TextEditingController _qty =
      TextEditingController(text: '${widget.stop.qty}');
  late final TextEditingController _price =
      TextEditingController(text: _priceText(widget.stop.price));
  late final TextEditingController _comment =
      TextEditingController(text: widget.stop.comment ?? '');
  final FocusNode _qtyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Пустое или нечитаемое количество при уходе из поля возвращаем к тому,
    // что в состоянии: точка без количества не бывает, а «стёр и ушёл» —
    // обычное дело.
    _qtyFocus.addListener(() {
      if (_qtyFocus.hasFocus) return;
      if (int.tryParse(_qty.text) == widget.stop.qty) return;
      _qty.text = '${widget.stop.qty}';
    });
  }

  @override
  void didUpdateWidget(RouteStopEditor old) {
    super.didUpdateWidget(old);
    // Состояние — источник правды: количество меняют ещё степпер и пресеты,
    // цену — кнопка «По прайсу». Текст трогаем, только когда он разошёлся,
    // иначе курсор прыгал бы на каждый набранный символ.
    if (int.tryParse(_qty.text) != widget.stop.qty) {
      _qty.text = '${widget.stop.qty}';
    }
    final priceText = _priceText(widget.stop.price);
    if (_price.text != priceText && _parsePrice(_price.text) != widget.stop.price) {
      _price.text = priceText;
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _comment.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  static String _priceText(int? price) => price == null ? '' : '$price';

  static int? _parsePrice(String text) {
    final digits = text.trim();
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  RouteDraftStop get _stop => widget.stop;

  /// Ноль — это не цена, а незаконченный ввод: сервер такую сумму не примет,
  /// и форма с ней точку не отпускает.
  bool get _priceInvalid => _stop.price == 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.md,
      children: [
        Row(
          spacing: AppSpacing.sm,
          children: [
            for (final purpose in OrderPurpose.values)
              Expanded(
                child: _PurposeButton(
                  label: purpose.label(l10n),
                  selected: purpose == _stop.purpose,
                  compact: widget.compact,
                  onTap: () => widget.onPurpose(purpose),
                ),
              ),
          ],
        ),
        // Количество спрашиваем у доставки и у вывоза; опту его передать
        // нечем — бутыли 5/10 л считает водитель на месте.
        if (_stop.hasQty) ...[
          Text(
            _stop.purpose == OrderPurpose.pickup
                ? l10n.routeCreateQtyTitlePickup
                : l10n.routeCreateQtyTitle,
            style: AppTypography.secondary
                .copyWith(color: t.text2, fontWeight: FontWeight.w600),
          ),
          _qtyRow(context),
        ],
        Text(
          l10n.routeFormCustomPrice,
          style: AppTypography.secondary
              .copyWith(color: t.text2, fontWeight: FontWeight.w600),
        ),
        _priceRow(context),
        Text(
          widget.forDriver ? l10n.orderCommentTitle : l10n.orderComment,
          style: AppTypography.secondary
              .copyWith(color: t.text2, fontWeight: FontWeight.w600),
        ),
        _commentField(context),
      ],
    );
  }

  /// Комментарий к точке: необязательная записка.
  ///
  /// Длину режем на 255 символов — ровно столько держит колонка на сервере,
  /// а сам он не обрезает и отвечает на длинный текст ошибкой.
  Widget _commentField(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        TextField(
          controller: _comment,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          minLines: 1,
          inputFormatters: [LengthLimitingTextInputFormatter(255)],
          style: TextStyle(color: t.text),
          decoration: InputDecoration(
            hintText: widget.forDriver
                ? l10n.addOrderCommentHint
                : l10n.orderCommentHint,
            counterText: '',
          ),
          onChanged: (value) {
            final text = value.trim();
            widget.onComment(text.isEmpty ? null : text);
          },
        ),
        Text(
          widget.forDriver
              ? l10n.addOrderCommentHelper
              : l10n.orderCommentHelper,
          style: AppTypography.secondary.copyWith(color: t.text3),
        ),
      ],
    );
  }

  Widget _qtyRow(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final side = widget.compact ? 44.0 : 36.0;

    // Пресеты: обычный объём заказчика и три круглых числа. Двадцать капсул
    // кнопкой «+» — двадцать нажатий, поэтому рядом со степпером и прямой
    // ввод, и готовые значения.
    final presets = <int>{
      if (widget.usualQty != null) widget.usualQty!,
      5,
      10,
      20,
    }.toList();

    final stepper = Container(
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            side: side,
            onTap: _stop.qty > 1 ? () => widget.onQty(_stop.qty - 1) : null,
          ),
          SizedBox(
            width: widget.compact ? 52 : 46,
            child: TextField(
              controller: _qty,
              focusNode: _qtyFocus,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: AppTypography.money.copyWith(color: t.text),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
              ),
              onChanged: (value) {
                // Пустое поле состояние не трогает: иначе стирание последней
                // цифры подставляло бы единицу под курсор.
                final parsed = int.tryParse(value);
                if (parsed != null && parsed > 0) widget.onQty(parsed);
              },
            ),
          ),
          _StepButton(
            icon: Icons.add,
            side: side,
            onTap: () => widget.onQty(_stop.qty + 1),
          ),
        ],
      ),
    );

    final chips = [
      for (final value in presets)
        _PresetChip(
          label: value == widget.usualQty
              ? l10n.routeCreateUsual(value)
              : '$value',
          selected: value == _stop.qty,
          compact: widget.compact,
          onTap: () => widget.onQty(value),
        ),
    ];

    return Row(
      spacing: AppSpacing.sm,
      children: [
        stepper,
        // Ряд пресетов прокручивается: на 390px он в строку не встаёт, а
        // переносить его вниз значило бы оторвать от счётчика.
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(spacing: AppSpacing.sm, children: chips),
          ),
        ),
      ],
    );
  }

  Widget _priceRow(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final unitPrice = widget.unitPrice;

    final hint = switch (_stop.purpose) {
      OrderPurpose.delivery19l => unitPrice == null
          ? l10n.routeCreatePricePlaceholderCustomer
          : l10n.routeCreatePricePlaceholder(
              MoneyFormatter.amount(_stop.listPrice(unitPrice)),
            ),
      OrderPurpose.pickup => l10n.routeFormPickupPriceHint,
      OrderPurpose.bulkWater => l10n.routeCreatePriceOnSite,
    };

    final helper = switch (_stop.purpose) {
      OrderPurpose.delivery19l => unitPrice == null
          ? l10n.routeCreatePriceHintCustomer
          : l10n.routeCreatePriceHint(MoneyFormatter.sum(l10n, unitPrice)),
      OrderPurpose.pickup => widget.forDriver
          ? l10n.addOrderPickupPriceHint
          : l10n.routeCreatePickupPriceHint,
      OrderPurpose.bulkWater => widget.forDriver
          ? l10n.addOrderBulkPriceHint
          : l10n.routeCreateBulkPriceHint,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        Row(
          spacing: AppSpacing.sm,
          children: [
            Expanded(
              child: TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: TextStyle(color: t.text),
                decoration: InputDecoration(hintText: hint, counterText: ''),
                onChanged: (value) => widget.onPrice(_parsePrice(value)),
              ),
            ),
            // Появляется только при заданной цене: сбрасывать нечего, пока
            // считаем по прайсу.
            if (_stop.hasCustomPrice)
              _ResetPriceButton(
                compact: widget.compact,
                onTap: () => widget.onPrice(null),
              ),
          ],
        ),
        Text(
          _priceInvalid ? l10n.routeFormCustomPriceInvalid : helper,
          style: AppTypography.secondary
              .copyWith(color: _priceInvalid ? t.danger : t.text3),
        ),
      ],
    );
  }
}

/// Кнопка цели точки.
///
/// Своя, а не `SegmentedToggle`: тот рассчитан на две широкие ячейки высотой
/// 52px, а здесь их три в колонке 340px — «Доставка 19 л» в ячейку не
/// влезает. Подпись поэтому мельче и с многоточием.
class _PurposeButton extends StatelessWidget {
  const _PurposeButton({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.softOf(t.primary) : t.surface2,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          height: compact ? 44 : 38,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? t.primary : t.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.secondary.copyWith(
              color: selected ? t.primary : t.text2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Готовое количество: «обычно 6», 5, 10, 20.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.softOf(t.primary) : t.surface2,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          height: compact ? 44 : 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: selected ? t.primary : t.border),
          ),
          child: Text(
            label,
            style: AppTypography.secondary.copyWith(
              color: selected ? t.primary : t.text2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Кнопка «По прайсу» — сбрасывает договорную цену.
class _ResetPriceButton extends StatelessWidget {
  const _ResetPriceButton({required this.compact, required this.onTap});

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface2,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          height: compact ? 48 : 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: t.border),
          ),
          child: Text(
            context.l10n.routeCreatePriceReset,
            style: AppTypography.secondary
                .copyWith(color: t.text2, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// Кнопка счётчика количества.
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.side, this.onTap});

  final IconData icon;
  final double side;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor:
            onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: SizedBox(
          width: side,
          height: side,
          child: Icon(icon, size: 20, color: onTap == null ? t.text3 : t.text),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../data/models/enums.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/route_draft.dart';

/// Грип-хендл точки: за него и только за него точку перетаскивают.
///
/// Вынесен наружу, потому что оборачивать его в слушателя перетаскивания
/// должен список (`ReorderableDragStartListener` знает индекс), а рисовать
/// одинаково — обе раскладки.
class RouteCreateGrip extends StatelessWidget {
  const RouteCreateGrip({
    super.key,
    this.compact = false,
    this.hint = true,
    this.enabled = true,
  });

  final bool compact;

  /// Показывать подсказку при наведении. У карточки, которая уже едет за
  /// курсором, подсказка не нужна — и не должна попасть в оверлей вторым
  /// слоем.
  final bool hint;

  /// За грип можно взяться.
  ///
  /// У раскрытой точки — нельзя: карточка с редактированием бывает выше
  /// видимой части списка (в шторке телефона это обычное дело), а
  /// перетаскивание такого элемента Flutter не поддерживает — автопрокрутка
  /// упирается в утверждение «drag target is larger than scrollable size».
  /// Подсказка при наведении объясняет, что делать: свернуть точку.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final grip = SizedBox(
      width: compact ? 32 : 24,
      height: compact ? 44 : 34,
      child: Icon(
        Icons.drag_indicator,
        size: 18,
        color: enabled ? t.text3 : t.border,
      ),
    );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.grab : SystemMouseCursors.basic,
      child: hint
          ? Tooltip(
              message: enabled
                  ? l10n.routeCreateDragHint
                  : l10n.routeCreateCollapseToDrag,
              child: grip,
            )
          : grip,
    );
  }
}

/// Карточка точки в собираемом маршруте.
///
/// Свёрнутая — одна строка: номер объезда, название и метастрока «цель ·
/// капсулы · сумма». Тап по ней разворачивает редактирование цели, количества
/// и цены. Точка приходит уже заполненной, поэтому свёрнутого вида хватает в
/// большинстве случаев, а разворачивать приходится ради исключений.
class RouteCreateStopCard extends StatefulWidget {
  const RouteCreateStopCard({
    super.key,
    required this.number,
    required this.name,
    required this.stop,
    required this.unitPrice,
    required this.usualQty,
    required this.expanded,
    required this.onExpand,
    required this.onRemove,
    required this.onPurpose,
    required this.onQty,
    required this.onPrice,
    required this.onComment,
    this.compact = false,
    this.dragging = false,
    this.grip,
    this.onMoveUp,
    this.onMoveDown,
  });

  /// Номер в объезде, считая с единицы.
  final int number;
  final String name;
  final RouteDraftStop stop;

  /// Цена капсулы для этого заказчика, сум.
  final int unitPrice;

  /// Обычный объём заказчика — из него берётся пресет «обычно N».
  final int? usualQty;

  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onRemove;
  final ValueChanged<OrderPurpose> onPurpose;
  final ValueChanged<int> onQty;

  /// `null` — считать по прайсу.
  final ValueChanged<int?> onPrice;

  /// Комментарий водителю; `null` — комментария нет.
  final ValueChanged<String?> onComment;

  /// Телефонная раскладка: касания крупнее, стрелок порядка нет.
  final bool compact;

  /// Карточка показывается в оверлее под курсором или пальцем.
  ///
  /// У неё нет ни кнопки удаления, ни стрелок: нажимать её всё равно нельзя,
  /// а вторые экземпляры кнопок с подсказками в оверлее ни к чему — см.
  /// `proxyDecorator` на странице.
  final bool dragging;

  /// Хендл перетаскивания, уже обёрнутый списком.
  final Widget? grip;

  /// Сдвиг на шаг — фолбэк к перетаскиванию на десктопе и единственный путь
  /// с клавиатуры. `null` — точка уже крайняя.
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  State<RouteCreateStopCard> createState() => _RouteCreateStopCardState();
}

class _RouteCreateStopCardState extends State<RouteCreateStopCard> {
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
  void didUpdateWidget(RouteCreateStopCard old) {
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

  /// Сумма точки по текущему состоянию.
  int get _money => _stop.money(widget.unitPrice);

  /// Ноль — это не цена, а незаконченный ввод: сервер такую сумму не примет,
  /// и форма с ней не отпускает маршрут.
  bool get _priceInvalid => _stop.price == 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        // Толщина одна: рамка потолще сдвигала бы соседние точки на пиксель.
        border: Border.all(color: widget.expanded ? t.primary : t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          if (widget.expanded) ...[
            Divider(height: 1, color: t.border),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _editor(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.grip == null ? AppSpacing.md : AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          ?widget.grip,
          if (!widget.compact &&
              !widget.dragging &&
              (widget.onMoveUp != null || widget.onMoveDown != null))
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ArrowButton(
                  icon: Icons.keyboard_arrow_up_rounded,
                  tooltip: l10n.routeCreateMoveUp,
                  onPressed: widget.onMoveUp,
                ),
                _ArrowButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  tooltip: l10n.routeCreateMoveDown,
                  onPressed: widget.onMoveDown,
                ),
              ],
            ),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.surface3,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '${widget.number}',
              style: AppTypography.badge.copyWith(color: t.text2),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: widget.dragging ? null : widget.onExpand,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              mouseCursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [
                    Text(
                      widget.name,
                      style: AppTypography.bodyStrong.copyWith(color: t.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _metaLine(context),
                    // Комментарий видно и в свёрнутой карточке: иначе о нём
                    // забывают, а исправить его после создания нечем.
                    if (_stop.comment case final String comment)
                      Row(
                        spacing: AppSpacing.xs,
                        children: [
                          Icon(Icons.sticky_note_2_outlined,
                              size: 14, color: t.text3),
                          Expanded(
                            child: Text(
                              comment,
                              style: AppTypography.secondary
                                  .copyWith(color: t.text2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!widget.dragging)
            Tooltip(
              message: l10n.routeCreateRemoveStop,
              child: IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: t.text2,
                constraints: BoxConstraints.tightFor(
                  width: widget.compact ? 44 : 34,
                  height: widget.compact ? 44 : 34,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  side: BorderSide(color: t.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// «Доставка 19 л · 6 капсул · 132 000 сум · своя цена».
  ///
  /// Количество — только у доставки: у вывоза и опта его некуда отправить
  /// (`bottle_sell_count` — задание к доставке), и обещать его в маршруте
  /// значило бы потерять цифру по дороге.
  Widget _metaLine(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final custom = _stop.hasCustomPrice;

    final money = switch (_stop.purpose) {
      OrderPurpose.pickup when !custom => l10n.routeCreateNoPayment,
      OrderPurpose.bulkWater when !custom => l10n.routeCreatePriceOnSite,
      _ => MoneyFormatter.sum(l10n, _money),
    };

    return Wrap(
      spacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          _stop.purpose.label(l10n),
          style: AppTypography.secondary.copyWith(
            color: _purposeColor(t, _stop.purpose),
            fontWeight: FontWeight.w700,
          ),
        ),
        if (_stop.countsCapsules) _dot(t),
        if (_stop.countsCapsules)
          Text(
            l10n.capsulesCount(_stop.qty),
            style: AppTypography.secondary
                .copyWith(color: t.text2, fontWeight: FontWeight.w700),
          ),
        _dot(t),
        Text(
          money,
          style: AppTypography.secondary.copyWith(
            color: custom ? t.warn : t.text2,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (custom) ...[
          _dot(t),
          Text(
            l10n.routeCreateOwnPrice,
            style: AppTypography.secondary.copyWith(color: t.warn),
          ),
        ],
      ],
    );
  }

  Widget _dot(AppTokens t) =>
      Text('·', style: AppTypography.secondary.copyWith(color: t.text3));

  static Color _purposeColor(AppTokens t, OrderPurpose purpose) =>
      switch (purpose) {
        OrderPurpose.delivery19l => t.aqua,
        OrderPurpose.pickup => t.primary,
        OrderPurpose.bulkWater => t.warn,
      };

  Widget _editor(BuildContext context) {
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
        // Количество — только у доставки, см. [_metaLine].
        if (_stop.countsCapsules) ...[
          Text(
            l10n.routeCreateQtyTitle,
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
          l10n.orderComment,
          style: AppTypography.secondary
              .copyWith(color: t.text2, fontWeight: FontWeight.w600),
        ),
        _commentField(context),
      ],
    );
  }

  /// Комментарий водителю: необязательная записка к точке.
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
            hintText: l10n.orderCommentHint,
            counterText: '',
          ),
          onChanged: (value) {
            final text = value.trim();
            widget.onComment(text.isEmpty ? null : text);
          },
        ),
        Text(
          l10n.orderCommentHelper,
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

    final hint = switch (_stop.purpose) {
      OrderPurpose.delivery19l =>
        l10n.routeCreatePricePlaceholder(MoneyFormatter.amount(
          _stop.listPrice(widget.unitPrice),
        )),
      OrderPurpose.pickup => l10n.routeFormPickupPriceHint,
      OrderPurpose.bulkWater => l10n.routeCreatePriceOnSite,
    };

    final helper = switch (_stop.purpose) {
      OrderPurpose.delivery19l => l10n.routeCreatePriceHint(
          MoneyFormatter.sum(l10n, widget.unitPrice),
        ),
      OrderPurpose.pickup => l10n.routeCreatePickupPriceHint,
      OrderPurpose.bulkWater => l10n.routeCreateBulkPriceHint,
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

/// Стрелка порядка объезда: мелкая кнопка на десктопе, доступная с
/// клавиатуры. На телефоне порядок меняют пальцем, и стрелок там нет.
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      color: t.text2,
      disabledColor: t.text3,
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 26, height: 22),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

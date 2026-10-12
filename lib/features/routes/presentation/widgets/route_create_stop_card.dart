import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../data/models/enums.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/route_draft.dart';
import 'route_stop_editor.dart';

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
///
/// Редактор под раскрытой карточкой общий с формой водителя — см.
/// [RouteStopEditor].
class RouteCreateStopCard extends StatelessWidget {
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

  /// Сумма точки по текущему состоянию.
  int get _money => stop.money(unitPrice);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        // Толщина одна: рамка потолще сдвигала бы соседние точки на пиксель.
        border: Border.all(color: expanded ? t.primary : t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          if (expanded) ...[
            Divider(height: 1, color: t.border),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: RouteStopEditor(
                stop: stop,
                unitPrice: unitPrice,
                usualQty: usualQty,
                compact: compact,
                onPurpose: onPurpose,
                onQty: onQty,
                onPrice: onPrice,
                onComment: onComment,
              ),
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
        grip == null ? AppSpacing.md : AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          ?grip,
          if (!compact &&
              !dragging &&
              (onMoveUp != null || onMoveDown != null))
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ArrowButton(
                  icon: Icons.keyboard_arrow_up_rounded,
                  tooltip: l10n.routeCreateMoveUp,
                  onPressed: onMoveUp,
                ),
                _ArrowButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  tooltip: l10n.routeCreateMoveDown,
                  onPressed: onMoveDown,
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
              '$number',
              style: AppTypography.badge.copyWith(color: t.text2),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: dragging ? null : onExpand,
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
                      name,
                      style: AppTypography.bodyStrong.copyWith(color: t.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _metaLine(context),
                    // Комментарий видно и в свёрнутой карточке: иначе о нём
                    // забывают, а исправить его после создания нечем.
                    if (stop.comment case final String comment)
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
          if (!dragging)
            Tooltip(
              message: l10n.routeCreateRemoveStop,
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: t.text2,
                constraints: BoxConstraints.tightFor(
                  width: compact ? 44 : 34,
                  height: compact ? 44 : 34,
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
  /// Количество — у доставки и вывоза (у вывоза это «забрать»). У опта его
  /// некуда отправить: бутыли 5/10 л считает водитель на месте, и обещать их
  /// в маршруте значило бы потерять цифру по дороге.
  Widget _metaLine(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final custom = stop.hasCustomPrice;

    final money = switch (stop.purpose) {
      OrderPurpose.pickup when !custom => l10n.routeCreateNoPayment,
      OrderPurpose.bulkWater when !custom => l10n.routeCreatePriceOnSite,
      _ => MoneyFormatter.sum(l10n, _money),
    };

    return Wrap(
      spacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          stop.purpose.label(l10n),
          style: AppTypography.secondary.copyWith(
            color: _purposeColor(t, stop.purpose),
            fontWeight: FontWeight.w700,
          ),
        ),
        if (stop.hasQty) _dot(t),
        if (stop.hasQty)
          Text(
            // У вывоза то же число значит обратное — «забрать», а не «везти».
            stop.purpose == OrderPurpose.pickup
                ? l10n.routeCreatePickupTake(l10n.capsulesCount(stop.qty))
                : l10n.capsulesCount(stop.qty),
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

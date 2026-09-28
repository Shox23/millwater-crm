import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/day.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../../data/models/customer.dart';
import '../../../../l10n/l10n.dart';

/// Строка заказчика в наборе маршрута.
///
/// Тап добавляет точку и **ничего не раскрывает**: форма точки живёт в зоне
/// маршрута, а список от выбора не перестраивается и не прыгает. Раньше под
/// выбранной строкой разворачивалось три поля, и следующий заказчик уезжал
/// за экран.
///
/// Всё, по чему оператор решает, везти ли воду, стоит в самой строке: долг,
/// обычный объём и давность последней доставки. Адрес — потому что заказчиков
/// зовут по улице, а название часто её повторяет («Олмазор Нодира 58» при
/// адресе «Олмазор, Нодира 58»), и одного названия для выбора мало.
class RouteCreateCustomerRow extends StatelessWidget {
  const RouteCreateCustomerRow({
    super.key,
    required this.customer,
    required this.selected,
    required this.usualQty,
    required this.today,
    required this.onTap,
    this.compact = false,
  });

  final Customer customer;
  final bool selected;

  /// Обычный объём заказа; `null` — ещё не знаем (см. `CustomerHabits`).
  final int? usualQty;

  /// День, от которого считается давность доставки. Параметром, а не
  /// `DateTime.now()` внутри: иначе подпись не проверить тестом.
  final DateTime today;

  final VoidCallback onTap;

  /// Телефонная раскладка: у бейджа долга сумму не показываем — в 390px она
  /// вытесняет название.
  final bool compact;

  /// С какой давности последней доставки заказчику «ПОРА».
  ///
  /// Неделя — обычный цикл: капсулы на кулере у офиса кончаются примерно за
  /// это время. Порог мягкий, это подсказка к выбору, а не правило.
  static const int dueAfterDays = 7;

  /// Сколько дней прошло с последней доставки; `null` — доставок не было.
  int? get _daysSince {
    final last = customer.lastOrderDate;
    if (last == null) return null;
    return dayOnly(today).difference(dayOnly(last)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final days = _daysSince;
    final due = days != null && days >= dueAfterDays;

    return Material(
      color: selected ? t.softOf(t.primary) : t.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            // Толщина одна на любое состояние: полтора пикселя у выбранной
            // строки делали её на пиксель выше, и список подпрыгивал —
            // ровно то, от чего эту страницу и переделывали.
            border: Border.all(color: selected ? t.primary : t.border),
          ),
          child: Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [
                    // Переносом, а не строкой: название с двумя бейджами в
                    // узкой колонке (340px на десктопе, 390px на телефоне) в
                    // строку не встаёт, и бейдж «ДОЛГ 120 000» выдавливал
                    // содержимое за край карточки.
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          customer.name,
                          style: AppTypography.bodyStrong.copyWith(
                            color: selected ? t.primary : t.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (due)
                          _Badge(
                            label: l10n.routeCreateBadgeDue,
                            color: t.primary,
                            background: t.softOf(t.primary),
                          ),
                        if (customer.debt > 0)
                          _Badge(
                            label: compact
                                ? l10n.routeCreateBadgeDebt
                                : l10n.routeCreateBadgeDebtAmount(
                                    MoneyFormatter.amount(customer.debt),
                                  ),
                            color: t.danger,
                            background: t.dangerBg,
                          ),
                      ],
                    ),
                    Row(
                      spacing: AppSpacing.xs,
                      children: [
                        Icon(Icons.place_outlined, size: 14, color: t.text3),
                        Expanded(
                          child: Text(
                            customer.address,
                            style: AppTypography.secondary
                                .copyWith(color: t.text2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _habitLine(l10n, days),
                      style: AppTypography.secondary.copyWith(color: t.text2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Отметка, а не чекбокс: у выбранной строки это подтверждение,
              // что точка уже в маршруте, а не поле ввода.
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? t.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: selected ? t.primary : t.border),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.add_rounded,
                  size: 18,
                  color: selected ? t.surface : t.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// «обычно 6 · последняя 7 дн. назад». Обычный объём появляется, только
  /// когда он известен: в API его нет, и до первого добавления точки мы его
  /// не спрашиваем — см. `CustomerHabits`.
  String _habitLine(AppLocalizations l10n, int? days) {
    final parts = [
      if (usualQty != null) l10n.routeCreateUsual(usualQty!),
      if (days == null)
        l10n.routeCreateNoDeliveries
      else
        l10n.routeCreateLastDelivery(days),
    ];
    return parts.join(' · ');
  }
}

/// Бейдж строки: «ПОРА», «ДОЛГ 120 000».
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: AppTypography.badge.copyWith(color: color)),
    );
  }
}

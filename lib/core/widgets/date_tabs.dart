import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import '../../l10n/l10n.dart';
import '../utils/day.dart';
import 'app_button.dart';

/// Горизонтальная лента дат: окно вокруг выбранного дня плюс календарь.
///
/// Показывает `[selected - radius … selected + radius]`; сегодняшний день
/// подписан словом, остальные — `dd.MM`. Прокрутка сама подводит выбранный
/// таб к центру.
class DateTabs extends StatefulWidget {
  const DateTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.radius = 7,
  });

  /// Выбранный день; время игнорируется.
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  /// Сколько дней показывать в каждую сторону от выбранного.
  final int radius;

  /// Насколько далеко пускает календарь.
  static const int pickerRange = 365;

  @override
  State<DateTabs> createState() => _DateTabsState();
}

class _DateTabsState extends State<DateTabs> {
  /// Ключ живёт на выбранном табе — по нему лента и подводится.
  final _selectedKey = GlobalKey();
  final _controller = ScrollController();

  /// Ширина затухания у края ленты.
  static const double _fadeWidth = 24;

  /// С какой стороны лента продолжается за краем экрана.
  bool _fadeStart = false;
  bool _fadeEnd = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncFades);
    _centerSelected();
  }

  @override
  void didUpdateWidget(DateTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.selected, widget.selected)) {
      _centerSelected();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Подводит выбранный таб к середине ленты после отрисовки кадра.
  ///
  /// Считать смещение вручную нельзя: «Сегодня» шире, чем `12.08`, и ширины
  /// табов заранее не известны.
  void _centerSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // До первой раскладки границ прокрутки ещё нет — считаем затухание
      // здесь же, когда лента уже померена.
      _syncFades();
      final target = _selectedKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Гасим край только с той стороны, где лента реально продолжается: иначе
  /// у нетронутой ленты подтаивал бы первый таб, будто там что-то есть.
  void _syncFades() {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    if (!p.hasContentDimensions) return;
    final start = p.pixels > p.minScrollExtent + 1;
    final end = p.pixels < p.maxScrollExtent - 1;
    if (start == _fadeStart && end == _fadeEnd) return;
    setState(() {
      _fadeStart = start;
      _fadeEnd = end;
    });
  }

  Future<void> _pickDate() async {
    final today = dayOnly(DateTime.now());
    final first = today.subtract(const Duration(days: DateTabs.pickerRange));
    final last = today.add(const Duration(days: DateTabs.pickerRange));
    final selected = dayOnly(widget.selected);

    final picked = await showDatePicker(
      context: context,
      // Зажимаем: календарь падает на ассерте, если initialDate вне границ,
      // а выбранная дата могла прийти откуда угодно.
      initialDate: selected.isBefore(first)
          ? first
          : selected.isAfter(last)
              ? last
              : selected,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) widget.onSelected(dayOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final selected = dayOnly(widget.selected);
    final days = [
      for (var i = -widget.radius; i <= widget.radius; i++)
        selected.add(Duration(days: i)),
    ];
    // Календарь мог увести окно так далеко, что сегодняшнего дня в нём нет.
    // Без отдельного таба вернуться было бы нечем.
    final todayOutside = !days.any((d) => DateUtils.isSameDay(d, today));

    return Row(
      spacing: AppSpacing.sm,
      children: [
        Expanded(
          child: ShaderMask(
            // Гасим края, чтобы обрезанный на границе таб читался как
            // «дальше есть ещё», а не как брак вёрстки. dstIn берёт от
            // градиента только альфу и применяет её к ленте.
            shaderCallback: (rect) {
              final fade = (_fadeWidth / rect.width).clamp(0.0, 0.5);
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _fadeStart ? Colors.transparent : Colors.black,
                  Colors.black,
                  Colors.black,
                  _fadeEnd ? Colors.transparent : Colors.black,
                ],
                stops: [0, fade, 1 - fade, 1],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: AppSpacing.page),
              child: Row(
                spacing: AppSpacing.sm,
                children: [
                  if (todayOutside) ...[
                    _DateTab(
                      label: context.l10n.periodToday,
                      selected: false,
                      onTap: () => widget.onSelected(today),
                    ),
                    const _Separator(),
                  ],
                  for (final day in days)
                    _DateTab(
                      key: DateUtils.isSameDay(day, selected)
                          ? _selectedKey
                          : null,
                      label: DateUtils.isSameDay(day, today)
                          ? context.l10n.periodToday
                          : DateFormat('dd.MM').format(day),
                      selected: DateUtils.isSameDay(day, selected),
                      onTap: () => widget.onSelected(day),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.page),
          child: IconActionButton(
            icon: Icons.calendar_month_outlined,
            tooltip: context.l10n.dateTabsPick,
            onPressed: _pickDate,
          ),
        ),
      ],
    );
  }
}

/// Отбивка между «Сегодня» и окном дат, когда они не рядом.
class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 20, color: context.tokens.border);
  }
}

/// Пилюля одного дня. Форма та же, что у чипов фильтра, — лента должна
/// читаться как часть той же системы.
class _DateTab extends StatelessWidget {
  const _DateTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.primary : t.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: selected ? t.primary : t.border),
          ),
          child: Text(
            label,
            style: AppTypography.badge
                .copyWith(color: selected ? Colors.white : t.text2),
          ),
        ),
      ),
    );
  }
}

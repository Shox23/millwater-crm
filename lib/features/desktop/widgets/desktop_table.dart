import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../theme/desktop_typography.dart';

/// Колонка таблицы: подпись в шапке и то, как она делит ширину.
class DesktopColumn {
  const DesktopColumn(this.label, {this.flex = 10, this.width});

  final String label;

  /// Доля ширины. Дроби макета переведены в целые: 2.1fr → 21.
  final int flex;

  /// Фиксированная ширина вместо доли — для колонки с шевроном.
  final double? width;
}

/// Таблица десктопа: шапка на приглушённой поверхности и строки-кнопки.
///
/// Не `DataTable`: тому нужны ячейки одной высоты и он не умеет ни строку
/// в два яруса («имя + адрес»), ни подсветку выбранной строки.
class DesktopTable extends StatelessWidget {
  const DesktopTable({
    super.key,
    required this.columns,
    required this.itemCount,
    required this.cellsBuilder,
    this.onRowTap,
    this.selectedIndex,
    this.empty,
  });

  final List<DesktopColumn> columns;
  final int itemCount;

  /// Ячейки строки; длина должна совпадать с числом колонок.
  final List<Widget> Function(int index) cellsBuilder;

  final ValueChanged<int>? onRowTap;

  /// Какая строка открыта в drawer — она подсвечивается.
  final int? selectedIndex;

  /// Что показать вместо строк, когда их нет.
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: t.border),
        boxShadow: t.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(columns: columns),
          if (itemCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: empty ?? const SizedBox.shrink(),
            )
          else
            for (var i = 0; i < itemCount; i++)
              _Row(
                columns: columns,
                cells: cellsBuilder(i),
                selected: i == selectedIndex,
                last: i == itemCount - 1,
                onTap: onRowTap == null ? null : () => onRowTap!(i),
              ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.columns});

  final List<DesktopColumn> columns;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      color: t.surface2,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          for (final column in columns)
            _Cell(
              column: column,
              child: Text(
                column.label,
                style: DesktopTypography.tableHeader.copyWith(color: t.text3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.columns,
    required this.cells,
    required this.selected,
    required this.last,
    required this.onTap,
  });

  final List<DesktopColumn> columns;
  final List<Widget> cells;
  final bool selected;
  final bool last;
  final VoidCallback? onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: widget.selected
            ? t.primarySoft
            : (_hovered ? t.surface2 : Colors.transparent),
        border: widget.last
            ? null
            : Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          for (final (i, column) in widget.columns.indexed)
            _Cell(column: column, child: widget.cells[i]),
        ],
      ),
    );

    if (widget.onTap == null) return row;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        selected: widget.selected,
        child: GestureDetector(onTap: widget.onTap, child: row),
      ),
    );
  }
}

/// Ячейка: либо доля ширины, либо фиксированная колонка.
class _Cell extends StatelessWidget {
  const _Cell({required this.column, required this.child});

  final DesktopColumn column;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (column.width != null) {
      return SizedBox(width: column.width, child: child);
    }
    return Expanded(flex: column.flex, child: child);
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/section_block.dart';
import '../../../data/models/route_expense.dart';
import '../../../data/models/route_models.dart';
import '../../../data/repositories/driver_repository.dart';
import 'expense_form_page.dart';

/// Касса маршрута: сколько собрано, сколько потрачено и сколько сдавать.
///
/// Числа считает сервер — он видит и правки оплаты админом, и возвраты,
/// которых в точках маршрута не видно. Клиент их только показывает: свой
/// подсчёт по точкам разошёлся бы с тем, что спросят с водителя в кассе.
class RouteCashPage extends StatefulWidget {
  const RouteCashPage({super.key, required this.routeId});

  final String routeId;

  @override
  State<RouteCashPage> createState() => _RouteCashPageState();
}

class _RouteCashPageState extends State<RouteCashPage> {
  RouteDetail? _route;
  List<RouteExpense> _expenses = const [];
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final repo = context.read<DriverRepository>();
      // Маршрут и расходы вместе: касса без списка трат — это число без
      // объяснения, откуда оно взялось.
      final route = await repo.getMyRoute(widget.routeId);
      final expenses = await repo.getRouteExpenses(widget.routeId);
      if (!mounted) return;
      setState(() {
        _route = route;
        _expenses = expenses;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _addExpense() async {
    final added = await Navigator.of(context).push<bool>(
      OverlayPageRoute(builder: (_) => ExpenseFormPage(routeId: widget.routeId)),
    );
    if (added == true && mounted) {
      showAppSnackBar(context, context.l10n.expenseSaved);
      await _load();
    }
  }

  Future<void> _deleteExpense(RouteExpense expense) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.expenseDelete,
      message: l10n.expenseDeleteConfirm,
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<DriverRepository>().deleteExpense(expense.id);
      if (mounted) await _load();
    } on DioException {
      if (mounted) showAppSnackBar(context, l10n.expenseDeleteFailed, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final route = _route;

    return DetailScaffold(
      title: l10n.cashTitle,
      body: _loading
          ? const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          : _loadFailed || route == null
              ? Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: ErrorRetryView(
                    onRetry: _load,
                    message: l10n.cashLoadFailed,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.lg,
                  children: [
                    _CashCard(route: route),
                    SectionBlock(
                      label: l10n.cashExpensesSection,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: AppSpacing.md,
                        children: [
                          if (_expenses.isEmpty)
                            Text(l10n.cashNoExpenses,
                                style: AppTypography.secondary
                                    .copyWith(color: t.text2))
                          else
                            for (final expense in _expenses)
                              _ExpenseRow(
                                expense: expense,
                                onDelete: () => _deleteExpense(expense),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomBar: BottomActionBar(
        child: AppButton(
          label: l10n.cashAddExpense,
          enabled: !_loading && !_loadFailed,
          onPressed: (_loading || _loadFailed) ? null : _addExpense,
        ),
      ),
    );
  }
}

/// Сводка кассы. Числа берутся у сервера; на стенде без этих полей строки
/// показывают ноль, а не пустоту — «нет данных» и «не собрано» водителю
/// одинаково означают «сдавать нечего».
class _CashCard extends StatelessWidget {
  const _CashCard({required this.route});

  final RouteDetail route;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final balance = route.cashBalance ?? 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          _CashRow(
            label: l10n.cashCollectedCash,
            value: route.cashCollected ?? 0,
          ),
          _CashRow(
            label: l10n.cashCollectedCashless,
            value: route.cashlessCollected ?? 0,
          ),
          _CashRow(label: l10n.cashDebtAmount, value: route.debtAmount ?? 0),
          _CashRow(
            label: l10n.cashExpensesTotal,
            value: route.expensesTotal ?? 0,
          ),
          Divider(color: t.border, height: 1),
          _CashRow(
            label: l10n.cashBalance,
            value: balance,
            strong: true,
            // Минус — рабочее состояние: расход больше собранного разрешён,
            // водитель заправился на свои.
            color: balance < 0 ? t.danger : t.success,
          ),
          Text(l10n.cashBalanceHint,
              style: AppTypography.secondary.copyWith(color: t.text2)),
        ],
      ),
    );
  }
}

class _CashRow extends StatelessWidget {
  const _CashRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.color,
  });

  final String label;
  final int value;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppTypography.secondary.copyWith(color: t.text2)),
        ),
        Text(
          MoneyFormatter.sum(context.l10n, value),
          style: strong
              ? AppTypography.money.copyWith(fontSize: 18, color: color ?? t.text)
              : AppTypography.bodyStrong.copyWith(color: color ?? t.text),
        ),
      ],
    );
  }
}

/// Строка расхода: категория, сумма, комментарий и время.
class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, required this.onDelete});

  final RouteExpense expense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;

    return AppCard(
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Expanded(
                      child: Text(expense.category.label(l10n),
                          style:
                              AppTypography.bodyStrong.copyWith(color: t.text)),
                    ),
                    Text(MoneyFormatter.sum(l10n, expense.amount),
                        style:
                            AppTypography.bodyStrong.copyWith(color: t.danger)),
                  ],
                ),
                if (expense.comment != null)
                  Text(expense.comment!,
                      style:
                          AppTypography.secondary.copyWith(color: t.text2)),
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Text(DateFormat('HH:mm').format(expense.createdAt),
                        style:
                            AppTypography.secondary.copyWith(color: t.text3)),
                    if (expense.hasPhoto)
                      Icon(Icons.receipt_long_outlined,
                          size: 14, color: t.text3),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: l10n.expenseDelete,
            icon: Icon(Icons.delete_outline, size: 20, color: t.danger),
          ),
        ],
      ),
    );
  }
}

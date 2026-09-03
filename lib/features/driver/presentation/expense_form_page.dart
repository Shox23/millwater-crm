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
import '../../../core/utils/idempotency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../core/widgets/photo_attach_tile.dart';
import '../../../core/widgets/segmented_toggle.dart';
import '../../../data/models/enums.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/driver_repository.dart';

/// Форма расхода водителя: сумма, категория, комментарий, чек.
///
/// Расход вычитается из наличной кассы маршрута, поэтому запись здесь — не
/// заметка для себя, а часть денежного отчёта: по ней сходится то, что
/// водитель сдаёт в конце дня.
class ExpenseFormPage extends StatefulWidget {
  const ExpenseFormPage({super.key, required this.routeId});

  final String routeId;

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> with SubmitState {
  final _amount = TextEditingController();
  final _comment = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.fuel;
  XFile? _photo;

  /// Один ключ на весь экран: связь у водителя рвётся, а повторная отправка —
  /// это второе списание из кассы.
  ///
  /// Сервер ключ пока не соблюдает: сохраняет его под шаблоном пути, а ищет по
  /// фактическому, и на повтор отвечает 500 вместо тихого успеха. Ключ всё
  /// равно шлём — когда починят, защита заработает без правок здесь.
  final String _idempotencyKey = newIdempotencyKey('expense');

  @override
  void dispose() {
    _amount.dispose();
    _comment.dispose();
    super.dispose();
  }

  int? get _amountOrNull => int.tryParse(_amount.text.trim());

  /// Ноль расходом не бывает: сервер требует сумму больше нуля.
  bool get _valid => (_amountOrNull ?? 0) > 0;

  Future<void> _submit() async {
    final repo = context.read<DriverRepository>();
    // Строки берём до запроса: после await контекст уже мог уйти.
    final l10n = context.l10n;

    final saved = await submit(
      () => repo.addExpense(
        routeId: widget.routeId,
        amount: _amountOrNull ?? 0,
        category: _category,
        comment: _comment.text,
        photoPath: _photo?.path,
        idempotencyKey: _idempotencyKey,
      ),
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.expenseFailed)
          : l10n.expenseFailed,
    );

    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;

    return DetailScaffold(
      title: l10n.expenseTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          LabeledTextField(
            label: l10n.expenseAmount,
            helper: l10n.expenseAmountHint,
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 12,
            onChanged: (_) => setState(() {}),
            validator: (value) =>
                (int.tryParse((value ?? '').trim()) ?? 0) > 0
                    ? null
                    : l10n.expenseAmountRequired,
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: [
                Text(l10n.expenseCategory,
                    style: AppTypography.bodyStrong.copyWith(color: t.text)),
                SegmentedToggle<ExpenseCategory>(
                  value: _category,
                  onChanged: submitting
                      ? (_) {}
                      : (category) => setState(() => _category = category),
                  options: [
                    for (final category in ExpenseCategory.values)
                      SegmentOption(
                          value: category, label: category.label(l10n)),
                  ],
                ),
              ],
            ),
          ),
          LabeledTextField(
            label: l10n.expenseComment,
            hint: l10n.expenseCommentHint,
            helper: l10n.commonOptional,
            controller: _comment,
            maxLength: 255,
          ),
          // Чек прикладывают к любому расходу, а не только к части из них:
          // в отчёте спрашивают именно за наличные, потраченные в дороге.
          PhotoAttachTile(
            photo: _photo,
            enabled: !submitting,
            onChanged: (photo) => setState(() => _photo = photo),
            title: l10n.expensePhoto,
            // Своя подпись: общая говорит про фото доставки, а здесь снимают
            // чек из магазина или с заправки.
            subtitle: l10n.expensePhotoSubtitle,
          ),
        ],
      ),
      bottomBar: BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.md,
          children: [
            if (submitError != null)
              Text(submitError!,
                  style: AppTypography.secondary.copyWith(color: t.danger),
                  textAlign: TextAlign.center),
            AppButton(
              label: submitting ? l10n.commonSaving : l10n.commonSave,
              enabled: _valid && !submitting,
              onPressed: (_valid && !submitting) ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

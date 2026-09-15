import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../data/network/api_envelope.dart';

/// Форма отмены заказа: предупреждение и причина.
///
/// Одна на две роли: админ открывает её из карточки заказа, водитель — с
/// точки маршрута. Ручки у ролей разные (`/admin/orders/{id}/cancel` и
/// `/driver/orders/{id}/cancel`), поэтому сам запрос форма не знает —
/// вызывающий передаёт его в [cancel], а форма ведёт только ввод причины,
/// занятость кнопки и текст отказа. Так водительское дерево не получает
/// админский репозиторий, как и везде.
///
/// Причина необязательна: заказчик может просто не открыть дверь, и
/// заставлять писать «не открыл» ради галочки незачем. Пустая уходит как
/// отсутствие поля (см. `cancelOrderBody`).
///
/// Закрывается с `true`, когда сервер принял отмену.
class CancelOrderPage extends StatefulWidget {
  const CancelOrderPage({
    super.key,
    required this.customerName,
    required this.cancel,
  });

  /// Чей заказ — чтобы форма не выглядела безымянной.
  final String customerName;

  /// Запрос отмены с причиной (`null` — без причины).
  final Future<void> Function(String? reason) cancel;

  @override
  State<CancelOrderPage> createState() => _CancelOrderPageState();
}

class _CancelOrderPageState extends State<CancelOrderPage> with SubmitState {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Строки берём до запроса: после await контекст уже мог уйти.
    final l10n = context.l10n;
    final reason = _reason.text.trim();

    final done = await submit(
      () => widget.cancel(reason.isEmpty ? null : reason),
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.orderCancelFailed)
          : l10n.orderCancelFailed,
    );

    if (done && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;

    return DetailScaffold(
      title: l10n.orderCancelTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(widget.customerName,
                    style: AppTypography.bodyStrong.copyWith(color: t.text)),
                // Отмена необратима — говорим это до нажатия, а не после:
                // ручки «вернуть в работу» у сервера нет.
                Text(l10n.orderCancelWarning,
                    style: AppTypography.secondary.copyWith(color: t.danger)),
              ],
            ),
          ),
          LabeledTextField(
            label: l10n.orderCancelReason,
            helper: l10n.orderCancelReasonHint,
            controller: _reason,
            maxLength: 255,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => submitting ? null : _submit(),
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
              label: submitting ? l10n.commonSaving : l10n.orderActionCancel,
              enabled: !submitting,
              onPressed: submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

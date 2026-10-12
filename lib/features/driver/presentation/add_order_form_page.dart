import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/section_block.dart';
import '../../../data/models/driver_customer.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../routes/domain/route_draft.dart';
import '../../routes/presentation/widgets/route_stop_editor.dart';

/// Чем закончился новый заказ — это показывает карточка маршрута.
enum AddOrderResult {
  /// Заказ добавлен.
  added,

  /// Заказчик уже оказался в маршруте: его добавил админ, или прошлый запрос
  /// дошёл, а ответ потерялся в дороге. Точка в маршруте есть, новой нет.
  alreadyInRoute,
}

/// Второй шаг нового заказа: что везти выбранному заказчику.
///
/// Поля те же, что у админа при сборке маршрута, — цель, количество,
/// договорная сумма за весь заказ и комментарий (см. [RouteStopEditor]).
/// Цены заказчика водитель здесь не знает: `GET /driver/customers` её не
/// отдаёт, и подсказки к сумме говорят «по цене заказчика» без числа. После
/// добавления точка придёт с ней от сервера (`effective_water_price`).
class AddOrderFormPage extends StatefulWidget {
  const AddOrderFormPage({
    super.key,
    required this.routeId,
    required this.customer,
  });

  final String routeId;
  final DriverCustomer customer;

  @override
  State<AddOrderFormPage> createState() => _AddOrderFormPageState();
}

class _AddOrderFormPageState extends State<AddOrderFormPage> with SubmitState {
  late RouteDraftStop _stop =
      RouteDraftStop(customerId: widget.customer.id, qty: 1);

  /// Ноль в сумме — незаконченный ввод: сервер такую сумму не примет.
  bool get _valid => _stop.price != 0;

  Future<void> _submit() async {
    final repo = context.read<DriverRepository>();
    // Строки берём до запроса: после await контекст уже мог уйти.
    final l10n = context.l10n;
    final stop = _stop;
    var alreadyInRoute = false;

    final done = await submit(
      () async {
        try {
          await repo.addRouteOrder(
            routeId: widget.routeId,
            customerId: stop.customerId,
            purpose: stop.purpose,
            // У опта количества нет — см. [RouteDraftStop.hasQty]; у доставки
            // сервер его требует.
            bottleSellCount: stop.hasQty ? stop.qty : null,
            customPrice: stop.price,
            comment: stop.comment,
          );
        } on DioException catch (e) {
          // Ключа идемпотентности у ручки нет, и повтор после обрыва связи
          // упирается в 409. Ошибкой формы это не считаем: заказчик в
          // маршруте есть — водителю нужна карточка, а не повтор.
          if (errorCode(e.response?.data) != 'CUSTOMER_ALREADY_IN_ROUTE') {
            rethrow;
          }
          alreadyInRoute = true;
        }
      },
      message: (e) => e is DioException
          ? apiErrorMessage(l10n, e, fallback: l10n.addOrderFailed)
          : l10n.addOrderFailed,
    );

    if (done && mounted) {
      Navigator.of(context).pop(
        alreadyInRoute ? AddOrderResult.alreadyInRoute : AddOrderResult.added,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final canSubmit = _valid && !submitting;

    return DetailScaffold(
      title: l10n.addOrderTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          SectionBlock(
            label: l10n.addOrderCustomer,
            child: _CustomerCard(customer: widget.customer),
          ),
          SectionBlock(
            label: l10n.addOrderOrder,
            child: AppCard(
              // Пока запрос в пути, форма не меняется: ушли уже прежние
              // значения, и правка на экране разошлась бы с заказом.
              child: IgnorePointer(
                ignoring: submitting,
                child: RouteStopEditor(
                  stop: _stop,
                  unitPrice: null,
                  compact: true,
                  forDriver: true,
                  onPurpose: (purpose) =>
                      setState(() => _stop = _stop.copyWith(purpose: purpose)),
                  onQty: (qty) => setState(() => _stop = _stop.copyWith(qty: qty)),
                  onPrice: (price) =>
                      setState(() => _stop = _stop.copyWith(price: price)),
                  onComment: (comment) =>
                      setState(() => _stop = _stop.copyWith(comment: comment)),
                ),
              ),
            ),
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
              label: submitting ? l10n.commonSaving : l10n.addOrderSubmit,
              enabled: canSubmit,
              onPressed: canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Кому заказ: имя, адрес, телефоны и заметка админа о заказчике.
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final DriverCustomer customer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final secondary = AppTypography.secondary.copyWith(color: t.text2);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          Text(customer.name,
              style: AppTypography.bodyStrong.copyWith(color: t.text)),
          if (customer.address.isNotEmpty)
            Text(customer.address, style: secondary),
          Text(
            [customer.phone, ?customer.phoneSecondary]
                .where((p) => p.isNotEmpty)
                .join(' · '),
            style: secondary,
          ),
          if (customer.comment case final String comment)
            Row(
              spacing: AppSpacing.xs,
              children: [
                Icon(Icons.sticky_note_2_outlined, size: 14, color: t.text3),
                Expanded(child: Text(comment, style: secondary)),
              ],
            ),
        ],
      ),
    );
  }
}

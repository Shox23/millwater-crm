import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/photo_attach_tile.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../../../core/widgets/segmented_toggle.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/route_models.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/crm_repository.dart';

/// Экран «Завершение маршрута»: количество капсул, способ и сумма оплаты.
class DeliveryCompletionPage extends StatefulWidget {
  const DeliveryCompletionPage({super.key, required this.stop});

  final RouteStop stop;

  @override
  State<DeliveryCompletionPage> createState() => _DeliveryCompletionPageState();
}

class _DeliveryCompletionPageState extends State<DeliveryCompletionPage> {
  late int _capsules;
  PaymentMethod _method = PaymentMethod.cash;
  late final TextEditingController _amountController;
  bool _submitting = false;
  String? _error;

  /// Сумму правил вручную либо она пришла с сервера — не перетираем.
  late bool _amountLocked;

  /// Цена капсулы приходит с сервера (/admin/prices/current).
  int _capsulePrice = 0;

  @override
  void initState() {
    super.initState();
    _capsules = widget.stop.deliveredCapsules ?? 1;
    _amountController =
        TextEditingController(text: '${widget.stop.paymentAmount ?? 0}');
    _amountLocked = widget.stop.paymentAmount != null;
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    final int price;
    try {
      price = await context.read<CrmRepository>().getCapsulePrice();
    } catch (_) {
      // Цена не пришла — сумму просто вводят вручную.
      return;
    }
    if (!mounted) return;
    setState(() {
      _capsulePrice = price;
      // Ответ сервера может прийти после того, как сумму уже набрали.
      if (!_amountLocked) _amountController.text = '${_capsules * price}';
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountController.text.trim()) ?? 0;

  void _onCapsulesChanged(int value) {
    setState(() {
      _capsules = value;
      _amountController.text = '${value * _capsulePrice}';
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<CrmRepository>().completeDelivery(
            stopId: widget.stop.id,
            capsules: _capsules,
            amount: _amount,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // Завершение — driver-эндпоинт: под админским токеном возможен отказ.
        _error = e.response?.statusCode == 403
            ? 'Завершать доставку может только водитель маршрута.'
            : apiErrorMessage(e, fallback: 'Не удалось завершить доставку.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Не удалось завершить доставку.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stop = widget.stop;

    return DetailScaffold(
      title: 'Завершение доставки',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(stop.customerName,
                    style: AppTypography.bodyStrong.copyWith(color: t.text)),
                Row(
                  spacing: 4,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: t.text2),
                    Expanded(
                      child: Text(stop.customerAddress,
                          style:
                              AppTypography.secondary.copyWith(color: t.text2)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _LabeledCard(
            label: 'КОЛИЧЕСТВО КАПСУЛ',
            child: QuantityStepper(
              value: _capsules,
              min: 0,
              onChanged: _onCapsulesChanged,
              caption: 'капсул ${CrmRepository.capsuleVolumeLiters}л',
            ),
          ),
          _LabeledCard(
            label: 'СПОСОБ ОПЛАТЫ',
            child: SegmentedToggle<PaymentMethod>(
              value: _method,
              columns: 2,
              onChanged: (m) => setState(() => _method = m),
              options: const [
                SegmentOption(value: PaymentMethod.cash, label: 'Наличные'),
                SegmentOption(value: PaymentMethod.card, label: 'Карта'),
                SegmentOption(
                    value: PaymentMethod.transfer, label: 'Перечисление'),
                SegmentOption(value: PaymentMethod.debt, label: 'В долг'),
              ],
            ),
          ),
          _LabeledCard(
            label: 'СУММА ОПЛАТЫ',
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() => _amountLocked = true),
                    style: AppTypography.statNumber.copyWith(color: t.text),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                Text('сум',
                    style: AppTypography.secondary.copyWith(color: t.text2)),
              ],
            ),
          ),
          const PhotoAttachTile(),
          if (_error != null)
            Text(_error!,
                style: AppTypography.secondary.copyWith(color: t.danger)),
        ],
      ),
      bottomBar: BottomActionBar(
        filled: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Итого к оплате',
                    style: AppTypography.secondary.copyWith(color: t.text2)),
                Text(MoneyFormatter.sum(_amount),
                    style: AppTypography.money
                        .copyWith(fontSize: 18, color: t.text)),
              ],
            ),
            AppButton(
              label: _submitting ? 'Сохранение…' : 'Завершить',
              enabled: !_submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка с капс-подписью сверху и произвольным содержимым.
class _LabeledCard extends StatelessWidget {
  const _LabeledCard({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Text(label, style: AppTypography.fieldLabel.copyWith(color: t.text2)),
          child,
        ],
      ),
    );
  }
}

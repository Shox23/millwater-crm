import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/idempotency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/search_field.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/driver.dart';
import '../../../data/network/api_envelope.dart';
import '../../../data/repositories/crm_repository.dart';

/// Экран создания маршрута: выбор водителя, даты и заказчиков.
class RouteFormPage extends StatefulWidget {
  const RouteFormPage({super.key});

  @override
  State<RouteFormPage> createState() => _RouteFormPageState();
}

class _RouteFormPageState extends State<RouteFormPage> {
  List<Driver> _drivers = [];
  List<Customer> _customers = [];
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  String? _error;

  String? _driverId;
  DateTime _date = DateTime.now();
  final Set<String> _customerIds = {};

  /// Один ключ на весь экран: повтор после обрыва связи не должен создать
  /// второй такой же маршрут.
  final String _idempotencyKey = newIdempotencyKey('route');

  /// Локальный фильтр по уже загруженному списку: выбирать из сотни
  /// чекбоксов вслепую невозможно.
  String _customerQuery = '';

  List<Customer> get _visibleCustomers {
    final q = _customerQuery.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.address.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q))
        .toList();
  }

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
    final repo = context.read<CrmRepository>();
    try {
      final drivers = await repo.getDrivers();
      final customers = await repo.getCustomers();
      if (!mounted) return;
      setState(() {
        _drivers = drivers;
        _customers = customers;
        _loading = false;
      });
    } catch (_) {
      // Без этого экран навсегда оставался с крутящимся индикатором.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  bool get _valid => _driverId != null && _customerIds.isNotEmpty;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<CrmRepository>().createRoute(
            driverId: _driverId!,
            date: _date,
            customerIds: _customerIds.toList(),
            idempotencyKey: _idempotencyKey,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorMessage(context.l10n, e, fallback: context.l10n.routeFormCreateFailed);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.l10n.routeFormCreateFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return DetailScaffold(
      title: context.l10n.routeFormTitle,
      body: _loading
          ? const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          : _loadFailed
          ? Padding(
              padding: const EdgeInsets.only(top: 60),
              child: ErrorRetryView(
                onRetry: _load,
                message: context.l10n.routeFormLoadFailed,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.lg,
              children: [
                _Section(
                  label: context.l10n.routeFormDate,
                  child: AppCard(
                    onTap: _pickDate,
                    child: Row(
                      spacing: AppSpacing.md,
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 20, color: t.primary),
                        Expanded(
                          child: Text(DateFormat('dd.MM.yyyy').format(_date),
                              style: AppTypography.bodyStrong
                                  .copyWith(color: t.text)),
                        ),
                        Icon(Icons.chevron_right, color: t.text2),
                      ],
                    ),
                  ),
                ),
                _Section(
                  label: context.l10n.routeFormDriver,
                  child: _drivers.isEmpty
                      ? Text(context.l10n.routeFormNoDrivers,
                          style:
                              AppTypography.secondary.copyWith(color: t.text2))
                      : Column(
                          spacing: AppSpacing.sm,
                          children: [
                            for (final d in _drivers)
                              _SelectableRow(
                                selected: _driverId == d.id,
                                leading:
                                    InitialsAvatar(name: d.fullName, size: 40),
                                title: d.fullName,
                                subtitle: d.phone,
                                onTap: () => setState(() => _driverId = d.id),
                              ),
                          ],
                        ),
                ),
                _Section(
                  label: context.l10n.routeFormCustomers,
                  trailing: context.l10n.routeFormSelected(_customerIds.length),
                  child: _customers.isEmpty
                      ? Text(context.l10n.routeFormNoCustomers,
                          style:
                              AppTypography.secondary.copyWith(color: t.text2))
                      : Column(
                          spacing: AppSpacing.sm,
                          children: [
                            SearchField(
                              hint: context.l10n.customerSearch,
                              onChanged: (q) =>
                                  setState(() => _customerQuery = q),
                            ),
                            if (_visibleCustomers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.md),
                                child: Text(context.l10n.commonNothingFound,
                                    style: AppTypography.secondary
                                        .copyWith(color: t.text2)),
                              ),
                            for (final c in _visibleCustomers)
                              _SelectableRow(
                                selected: _customerIds.contains(c.id),
                                multi: true,
                                title: c.name,
                                subtitle: c.address,
                                onTap: () => setState(() {
                                  if (!_customerIds.remove(c.id)) {
                                    _customerIds.add(c.id);
                                  }
                                }),
                              ),
                          ],
                        ),
                ),
                if (_error != null)
                  Text(_error!,
                      style: AppTypography.secondary.copyWith(color: t.danger)),
              ],
            ),
      bottomBar: _loadFailed
          ? null
          : BottomActionBar(
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  Expanded(
                    child: AppButton(
                      label: context.l10n.commonCancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  Expanded(
                    child: AppButton(
                      label: _saving ? context.l10n.commonCreating : context.l10n.commonCreate,
                      enabled: _valid && !_saving,
                      onPressed: (_valid && !_saving) ? _save : null,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Блок формы: капс-подпись, опциональная приписка справа и содержимое.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Row(
          children: [
            Text(label,
                style: AppTypography.fieldLabel.copyWith(color: t.text2)),
            const Spacer(),
            if (trailing != null)
              Text(trailing!,
                  style: AppTypography.secondary.copyWith(color: t.text2)),
          ],
        ),
        child,
      ],
    );
  }
}

/// Строка выбора: радио для водителя, чекбокс для заказчиков.
class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.leading,
    this.multi = false,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? leading;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.softOf(t.primary) : t.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? t.primary : t.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            spacing: AppSpacing.md,
            children: [
              ?leading,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(title,
                        style:
                            AppTypography.bodyStrong.copyWith(color: t.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(subtitle,
                        style:
                            AppTypography.secondary.copyWith(color: t.text2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(
                multi
                    ? (selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank)
                    : (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                color: selected ? t.primary : t.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

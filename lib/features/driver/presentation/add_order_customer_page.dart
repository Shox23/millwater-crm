import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/navigation/overlay_route.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_scaffold.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/load_more_notifier.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/driver_customer.dart';
import '../../../data/models/route_models.dart';
import '../../../data/repositories/driver_repository.dart';
import 'add_order_form_page.dart';

/// Первый шаг нового заказа: кому везти.
///
/// Ищет сервер (`GET /driver/customers`) — по имени, телефонам и адресу,
/// страницы догружаются прокруткой. Заказчик, который уже есть в маршруте,
/// помечен и не выбирается: второй заказ ему в тот же маршрут сервер не
/// примет (409), и узнавать об этом после заполнения формы обидно.
///
/// Закрывается с [AddOrderResult], когда заказ отправлен.
class AddOrderCustomerPage extends StatefulWidget {
  const AddOrderCustomerPage({super.key, required this.route});

  final RouteDetail route;

  @override
  State<AddOrderCustomerPage> createState() => _AddOrderCustomerPageState();
}

class _AddOrderCustomerPageState extends State<AddOrderCustomerPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  /// Пауза после последней буквы, прежде чем спрашивать сервер: запрос на
  /// каждую букву по мобильной связи — это очередь ответов, которые
  /// приходят уже не к тому запросу.
  static const _debounceDelay = Duration(milliseconds: 300);

  List<DriverCustomer> _customers = const [];
  String _query = '';
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _failed = false;

  /// Номер последнего запроса: ответ на устаревший поиск отбрасывается.
  int _requestId = 0;

  /// Заказчики, у которых уже есть заказ в маршруте, в любом статусе: сервер
  /// отвергает и того, чей заказ отменён.
  late final Set<String> _inRoute = {
    for (final stop in widget.route.stops) stop.customerId,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (value.trim() == _query.trim()) return;
      _query = value;
      _load();
    });
  }

  void _clearQuery() {
    _debounce?.cancel();
    _search.clear();
    _query = '';
    _load();
  }

  /// Первая страница по текущему запросу.
  ///
  /// Найденное по прошлому запросу на время загрузки не стирается: список,
  /// мигающий пустотой на каждую букву, читать невозможно.
  Future<void> _load() async {
    final repo = context.read<DriverRepository>();
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _failed = false;
    });
    try {
      final page = await repo.getCustomersPage(search: _query);
      if (!mounted || id != _requestId) return;
      setState(() {
        _customers = page.items;
        _page = page.page;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      // Найденное по прошлому запросу не оставляем: под новым запросом в
      // поле оно выглядело бы ответом на него.
      setState(() {
        _customers = const [];
        _hasMore = false;
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final repo = context.read<DriverRepository>();
    final id = _requestId;
    setState(() => _loadingMore = true);
    try {
      final page = await repo.getCustomersPage(page: _page + 1, search: _query);
      // Пока страница шла, поиск могли поменять — она уже не о том.
      if (!mounted || id != _requestId) return;
      setState(() {
        _customers = [..._customers, ...page.items];
        _page = page.page;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      // Найденное остаётся на месте: следующая прокрутка попробует снова.
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _pick(DriverCustomer customer) async {
    final result = await Navigator.of(context).push<AddOrderResult>(
      OverlayPageRoute(
        builder: (_) => AddOrderFormPage(
          routeId: widget.route.id,
          customer: customer,
        ),
      ),
    );
    // Заказ ушёл — выбирать больше некого, итог несём карточке маршрута.
    if (result != null && mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;

    return DetailScaffold(
      title: l10n.addOrderTitle,
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchField(
            hint: l10n.addOrderSearchHint,
            controller: _search,
            onChanged: _onQueryChanged,
          ),
          // Признак «запрос в пути» поверх старого списка. Высота
          // зарезервирована всегда — иначе список дёргается на каждую букву.
          SizedBox(
            height: AppSpacing.md,
            child: _loading && _customers.isNotEmpty
                ? Center(
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: t.surface2,
                    ),
                  )
                : null,
          ),
          Expanded(child: _list(context)),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    final l10n = context.l10n;

    if (_customers.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_failed) {
        return ErrorRetryView(onRetry: _load, message: l10n.customersLoadFailed);
      }
      if (_query.trim().isNotEmpty) {
        return EmptyStateView.noSearchResults(
          l10n: l10n,
          query: _query.trim(),
          onClear: _clearQuery,
        );
      }
      // Завести заказчика водитель не может — такой ручки у него нет, —
      // поэтому вместо кнопки «добавить» подсказка, к кому идти.
      return EmptyStateView(
        icon: Icons.people_outline_rounded,
        title: l10n.addOrderEmptyTitle,
        hint: l10n.addOrderEmptyHint,
      );
    }

    return LoadMoreNotifier(
      onLoadMore: _loadMore,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        itemCount: _customers.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i == _customers.length) {
            return LoadMoreFooter(loading: _loadingMore);
          }
          final customer = _customers[i];
          final inRoute = _inRoute.contains(customer.id);
          return _CustomerRow(
            customer: customer,
            inRoute: inRoute,
            onTap: inRoute ? null : () => _pick(customer),
          );
        },
      ),
    );
  }
}

/// Строка заказчика: имя, адрес и телефон — то, по чему водитель узнаёт
/// адрес, который ему назвали по телефону.
class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.customer,
    required this.inRoute,
    required this.onTap,
  });

  final DriverCustomer customer;
  final bool inRoute;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final secondary = AppTypography.secondary.copyWith(color: t.text2);

    return AppCard(
      onTap: onTap,
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  customer.name,
                  style: AppTypography.bodyStrong
                      .copyWith(color: inRoute ? t.text2 : t.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (customer.address.isNotEmpty)
                  Text(
                    customer.address,
                    style: secondary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(customer.phone, style: secondary),
              ],
            ),
          ),
          if (inRoute)
            StatusBadge(text: context.l10n.addOrderInRoute)
          else
            Icon(Icons.chevron_right_rounded, size: 20, color: t.text3),
        ],
      ),
    );
  }
}

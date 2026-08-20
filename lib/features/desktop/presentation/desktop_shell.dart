import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

import '../../../app/notifications_scope.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/day.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/driver.dart';
import '../../../data/models/notification_event.dart';
import '../../../data/repositories/crm_repository.dart';
import '../../customers/bloc/customers_bloc.dart';
import '../../drivers/bloc/drivers_bloc.dart';
import '../../reports/bloc/reports_bloc.dart';
import '../bloc/day_deliveries_bloc.dart';
import '../bloc/week_revenue_bloc.dart';
import '../overlays/desktop_modals.dart';
import '../overlays/desktop_overlays.dart';
import '../overlays/drawer_contents.dart';
import '../overlays/entity_form_modal.dart';
import '../theme/desktop_theme.dart';
import 'desktop_header.dart';
import 'desktop_section.dart';
import 'desktop_sidebar.dart';
import 'pages/customers_desktop_page.dart';
import 'pages/drivers_desktop_page.dart';
import 'pages/reports_desktop_page.dart';
import 'pages/routes_desktop_page.dart';

/// Корневая оболочка десктопа: сайдбар, шапка и рабочая область.
///
/// Блоки создаются здесь, а не внутри разделов, как в мобильной версии:
/// сайдбару нужны цифры сразу из двух (должники и водители на линии), а
/// переключение раздела не должно перезагружать то, что уже загружено.
class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CrmRepository>();

    return DesktopTheme(
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => DriversBloc(repository)..add(const DriversRequested()),
          ),
          BlocProvider(
            create: (_) =>
                CustomersBloc(repository)..add(const CustomersRequested()),
          ),
          BlocProvider(
            create: (context) => DayDeliveriesBloc(
              repository,
              notifications: context.notificationEvents,
            )..add(const DayDeliveriesRequested()),
          ),
          BlocProvider(
            create: (context) => ReportsBloc(
              repository,
              notifications: context.notificationEvents,
            )..add(const ReportsRequested()),
          ),
          BlocProvider(
            create: (_) =>
                WeekRevenueBloc(repository)..add(const WeekRevenueRequested()),
          ),
        ],
        child: const _DesktopShellView(),
      ),
    );
  }
}

class _DesktopShellView extends StatefulWidget {
  const _DesktopShellView();

  @override
  State<_DesktopShellView> createState() => _DesktopShellViewState();
}

class _DesktopShellViewState extends State<_DesktopShellView> {
  DesktopSection _section = DesktopSection.routes;
  final _searchController = TextEditingController();
  StreamSubscription<NotificationEvent>? _notifications;

  /// С сервера пришло событие, а пользователь его ещё не забрал.
  bool _freshEvents = false;

  @override
  void initState() {
    super.initState();
    // Списки на десктопе висят открытыми часами. Сами их не перечитываем:
    // сброс скролла и выделения под руками у оператора хуже, чем точка на
    // колокольчике, — но знать о том, что данные устарели, он должен.
    _notifications = context.notificationEvents?.listen((_) {
      if (mounted) setState(() => _freshEvents = true);
    });
  }

  @override
  void dispose() {
    _notifications?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _selectSection(DesktopSection section) {
    if (section == _section) return;
    setState(() {
      _section = section;
      // Поиск принадлежит разделу: запрос по водителям, оставшийся в поле
      // при переходе к заказчикам, показывал бы пустой список без причины.
      _searchController.clear();
    });
    _applySearch('');
  }

  void _applySearch(String query) {
    switch (_section) {
      case DesktopSection.drivers:
        context.read<DriversBloc>().add(DriversSearchChanged(query));
      case DesktopSection.customers:
        context.read<CustomersBloc>().add(CustomersSearchChanged(query));
      case DesktopSection.routes:
        context.read<DayDeliveriesBloc>().add(DayDeliveriesSearchChanged(query));
      case DesktopSection.reports:
        break;
    }
  }

  // ---- Оверлеи ----

  /// Карточка доставки.
  void _openDelivery(DeliveryRow row) {
    showDesktopDrawer<void>(
      context,
      builder: (_) => DeliveryDrawer(row: row),
    );
  }

  /// Карточка водителя: из неё же открываются правка и удаление.
  Future<void> _openDriver(Driver driver) async {
    await showDesktopDrawer<void>(
      context,
      builder: (drawerContext) => DriverDrawer(
        driver: driver,
        onEdit: () {
          Navigator.of(drawerContext).pop();
          _editDriver(driver);
        },
        onDelete: () {
          Navigator.of(drawerContext).pop();
          _deleteDriver(driver);
        },
      ),
    );
  }

  Future<void> _editDriver(Driver? driver) async {
    // Блок берём заранее: диалог живёт в Navigator над провайдерами оболочки,
    // и `context.read` внутри него репозиториев уже не найдёт.
    final bloc = context.read<DriversBloc>();
    final saved = await showDesktopModal<bool>(
      context,
      builder: (_) => DriverFormModal(driver: driver),
    );
    if (saved != true || !mounted) return;

    bloc.add(const DriversRequested());
    showDesktopToast(
      context,
      driver == null ? context.l10n.driverAdded : context.l10n.changesSaved,
    );
  }

  Future<void> _deleteDriver(Driver driver) async {
    final l10n = context.l10n;
    final repo = context.read<CrmRepository>();
    final bloc = context.read<DriversBloc>();

    final confirmed = await showDesktopConfirm(
      context,
      title: l10n.driverDeleteTitle,
      message: l10n.driverDeleteMessage(driver.fullName),
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !mounted) return;

    try {
      await repo.deleteDriver(driver.id);
    } catch (_) {
      if (mounted) showDesktopToast(context, l10n.driverDeleteFailed);
      return;
    }
    if (!mounted) return;
    bloc.add(const DriversRequested());
    showDesktopToast(context, l10n.driverDeleted);
  }

  /// Карточка заказчика.
  Future<void> _openCustomer(Customer customer) async {
    await showDesktopDrawer<void>(
      context,
      builder: (drawerContext) => CustomerDrawer(
        customer: customer,
        onEdit: () {
          Navigator.of(drawerContext).pop();
          _editCustomer(customer);
        },
        onDelete: () {
          Navigator.of(drawerContext).pop();
          _deleteCustomer(customer);
        },
      ),
    );
  }

  Future<void> _editCustomer(Customer? customer) async {
    final bloc = context.read<CustomersBloc>();
    final saved = await showDesktopModal<bool>(
      context,
      builder: (_) => CustomerFormModal(customer: customer),
    );
    if (saved != true || !mounted) return;

    bloc.add(const CustomersRequested());
    showDesktopToast(
      context,
      customer == null ? context.l10n.customerAdded : context.l10n.changesSaved,
    );
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final l10n = context.l10n;
    final repo = context.read<CrmRepository>();
    final bloc = context.read<CustomersBloc>();

    final confirmed = await showDesktopConfirm(
      context,
      title: l10n.customerDeleteTitle,
      message: l10n.customerDeleteMessage(customer.name),
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !mounted) return;

    try {
      await repo.deleteCustomer(customer.id);
    } catch (_) {
      if (mounted) showDesktopToast(context, l10n.customerDeleteFailed);
      return;
    }
    if (!mounted) return;
    bloc.add(const CustomersRequested());
    showDesktopToast(context, l10n.customerDeleted);
  }

  /// Перечитать то, что сейчас на экране.
  void _refresh() {
    setState(() => _freshEvents = false);
    switch (_section) {
      case DesktopSection.drivers:
        context.read<DriversBloc>().add(const DriversRequested());
      case DesktopSection.customers:
        context.read<CustomersBloc>().add(const CustomersRequested());
      case DesktopSection.routes:
        context.read<DayDeliveriesBloc>().add(const DayDeliveriesRequested());
      case DesktopSection.reports:
        break;
    }
  }

  /// Подпись под заголовком раздела.
  String _subtitle(BuildContext context) {
    final l10n = context.l10n;
    return switch (_section) {
      DesktopSection.routes => _routesSubtitle(context),
      DesktopSection.drivers =>
        l10n.driversCount(context.watch<DriversBloc>().state.drivers.length),
      DesktopSection.customers => l10n
          .customersCount(context.watch<CustomersBloc>().state.customers.length),
      DesktopSection.reports => l10n.reportsLabel,
    };
  }

  /// «Сегодня · 18.08 · 5 в работе» — день и сколько в нём ещё не закрыто.
  String _routesSubtitle(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<DayDeliveriesBloc>().state;
    final label = DateFormat('dd.MM').format(state.date);
    final date = state.date == dayOnly(DateTime.now())
        ? l10n.routesHeaderToday(label)
        : l10n.routesHeaderOn(label);
    return l10n.desktopRoutesSubtitle(date, state.pending);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.bg,
      body: Row(
        children: [
          DesktopSidebar(
            section: _section,
            onSectionChanged: _selectSection,
            routesBadge: context.watch<DayDeliveriesBloc>().state.pending,
          ),
          Expanded(
            child: Column(
              children: [
                DesktopHeader(
                  section: _section,
                  subtitle: _subtitle(context),
                  searchController: _searchController,
                  onSearchChanged: _applySearch,
                  onRefresh: _refresh,
                  hasFreshEvents: _freshEvents,
                  onAdd: switch (_section) {
                    DesktopSection.drivers => () => _editDriver(null),
                    DesktopSection.customers => () => _editCustomer(null),
                    _ => null,
                  },
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      // Появление со сдвигом на 8px: смена раздела читается
                      // как движение, а не как мгновенная подмена.
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.02),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_section),
                      child: switch (_section) {
                        DesktopSection.routes =>
                          RoutesDesktopPage(onRowTap: _openDelivery),
                        DesktopSection.drivers => DriversDesktopPage(
                            onOpen: _openDriver,
                            onEdit: _editDriver,
                            onDelete: _deleteDriver,
                          ),
                        DesktopSection.customers => CustomersDesktopPage(
                            onOpen: _openCustomer,
                            onEdit: _editCustomer,
                            onDelete: _deleteCustomer,
                          ),
                        DesktopSection.reports => const ReportsDesktopPage(),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

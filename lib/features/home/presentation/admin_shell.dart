import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

import '../../customers/presentation/customers_page.dart';
import '../../drivers/presentation/drivers_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../routes/presentation/routes_page.dart';
import 'widgets/app_bottom_nav.dart';

/// Корневая оболочка администратора: 4 вкладки с общей нижней навигацией.
///
/// `CrmRepository` в дерево кладёт `app.dart` — и только в этой ветке,
/// поэтому водительская часть до админского API не дотягивается.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  final _pages = const [
    RoutesPage(),
    DriversPage(),
    CustomersPage(),
    ReportsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    // Подписи вкладок строятся в build: при смене языка список должен
    // перерисоваться, а const-поле осталось бы прежним.
    final items = [
      BottomNavItemData(
          icon: Icons.route_outlined, label: context.l10n.navRoute),
      BottomNavItemData(
          icon: Icons.local_shipping_outlined, label: context.l10n.navDrivers),
      BottomNavItemData(
          icon: Icons.storefront_outlined, label: context.l10n.navCustomers),
      BottomNavItemData(
          icon: Icons.insights_outlined, label: context.l10n.navReports),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _index,
        items: items,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

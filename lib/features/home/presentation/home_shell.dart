import 'package:flutter/material.dart';

import '../../customers/presentation/customers_page.dart';
import '../../drivers/presentation/drivers_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../routes/presentation/routes_page.dart';
import 'widgets/app_bottom_nav.dart';

/// Корневая оболочка админа: 4 вкладки с общей нижней навигацией.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _items = [
    BottomNavItemData(icon: Icons.route_outlined, label: 'Маршрут'),
    BottomNavItemData(icon: Icons.local_shipping_outlined, label: 'Водители'),
    BottomNavItemData(icon: Icons.storefront_outlined, label: 'Заказчики'),
    BottomNavItemData(icon: Icons.insights_outlined, label: 'Отчёты'),
  ];

  final _pages = const [
    RoutesPage(),
    DriversPage(),
    CustomersPage(),
    ReportsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _index,
        items: _items,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

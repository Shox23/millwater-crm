import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

import '../../home/presentation/widgets/app_bottom_nav.dart';
import 'driver_profile_page.dart';
import 'my_routes_page.dart';

/// Корневая оболочка водителя: маршруты и профиль.
///
/// Админских разделов здесь нет и быть не может — `CrmRepository` в это
/// поддерево не кладётся (см. `app.dart`).
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  final _pages = const [MyRoutesPage(), DriverProfilePage()];

  @override
  Widget build(BuildContext context) {
    // Подписи строятся в build — иначе смена языка их не обновит.
    final items = [
      BottomNavItemData(
          icon: Icons.route_outlined, label: context.l10n.navRoutes),
      BottomNavItemData(
          icon: Icons.person_outline, label: context.l10n.navProfile),
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

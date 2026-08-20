import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// Разделы десктопной оболочки — те же четыре, что вкладки у админа.
enum DesktopSection {
  routes(Icons.route_outlined),
  drivers(Icons.local_shipping_outlined),
  customers(Icons.storefront_outlined),
  reports(Icons.insights_outlined);

  const DesktopSection(this.icon);

  final IconData icon;

  /// Подпись в боковом меню.
  String label(AppLocalizations l10n) => switch (this) {
        DesktopSection.routes => l10n.navRoutes,
        DesktopSection.drivers => l10n.navDrivers,
        DesktopSection.customers => l10n.navCustomers,
        DesktopSection.reports => l10n.navReports,
      };

  /// Заголовок в шапке. Совпадает с подписью меню, но берётся из своих
  /// ключей: меню и заголовок экрана — разные строки, и однажды разойдутся.
  String title(AppLocalizations l10n) => switch (this) {
        DesktopSection.routes => l10n.routesTitle,
        DesktopSection.drivers => l10n.driversTitle,
        DesktopSection.customers => l10n.customersTitle,
        DesktopSection.reports => l10n.reportsTitle,
      };

  /// Есть ли у раздела поиск. У отчётов искать нечего — там сводные числа.
  bool get hasSearch => this != DesktopSection.reports;
}

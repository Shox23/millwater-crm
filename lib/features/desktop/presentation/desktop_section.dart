import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// Разделы десктопной оболочки.
///
/// Пять повторяют вкладки админского телефона, «Касса» — только
/// десктопная: сводить расходы всех водителей за месяц удобно за столом, а
/// не в дороге. «Цены» на телефоне спрятаны в настройках; здесь это свой
/// раздел — менять прайс за столом, глядя на отчёты, естественнее.
enum DesktopSection {
  routes(Icons.route_outlined),
  orders(Icons.receipt_long_outlined),
  drivers(Icons.local_shipping_outlined),
  customers(Icons.storefront_outlined),
  cash(Icons.account_balance_wallet_outlined),
  reports(Icons.insights_outlined),
  prices(Icons.sell_outlined);

  const DesktopSection(this.icon);

  final IconData icon;

  /// Подпись в боковом меню.
  String label(AppLocalizations l10n) => switch (this) {
        DesktopSection.routes => l10n.navRoutes,
        DesktopSection.orders => l10n.ordersTitle,
        DesktopSection.drivers => l10n.navDrivers,
        DesktopSection.customers => l10n.navCustomers,
        DesktopSection.cash => l10n.navCash,
        DesktopSection.reports => l10n.navReports,
        DesktopSection.prices => l10n.pricesTitle,
      };

  /// Заголовок в шапке. Совпадает с подписью меню, но берётся из своих
  /// ключей: меню и заголовок экрана — разные строки, и однажды разойдутся.
  String title(AppLocalizations l10n) => switch (this) {
        DesktopSection.routes => l10n.routesTitle,
        DesktopSection.orders => l10n.ordersTitle,
        DesktopSection.drivers => l10n.driversTitle,
        DesktopSection.customers => l10n.customersTitle,
        DesktopSection.cash => l10n.cashDesktopTitle,
        DesktopSection.reports => l10n.reportsTitle,
        DesktopSection.prices => l10n.pricesTitle,
      };

  /// Есть ли у раздела поиск. У отчётов, кассы и цен искать нечего — там
  /// сводные числа, отбор чипами и одна форма.
  bool get hasSearch => switch (this) {
        DesktopSection.reports ||
        DesktopSection.cash ||
        DesktopSection.prices =>
          false,
        _ => true,
      };
}

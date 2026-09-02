import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../app/notifications_scope.dart';
import '../../../data/repositories/crm_repository.dart';
import '../bloc/orders_source.dart';
import 'orders_page.dart';

/// Вкладка «Заказы» у администратора.
///
/// Тонкая обёртка, а не отдельный экран: источник данных собирается здесь,
/// внутри админского поддерева, где `CrmRepository` вообще существует. У
/// водителя своя точка входа со своим источником — общий экран о ролях не
/// знает и знать не должен.
class AdminOrdersPage extends StatelessWidget {
  const AdminOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OrdersPage(
      source: AdminOrdersSource(context.read<CrmRepository>()),
      title: context.l10n.ordersTitle,
      notifications: context.notificationEvents,
      // Вкладка, а не оверлей: возвращаться некуда, кнопка «назад» здесь
      // была бы обманом.
      showBack: false,
      // Перенос и правка оплаты — админские ручки; в водительском дереве их
      // и вызвать нечем: `CrmRepository` туда не кладут.
      canManage: true,
    );
  }
}

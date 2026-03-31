import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_fixed.dart';
import 'admin_dashboard_page.dart';
import 'admin_ratings_page.dart';
import 'system_admin_page.dart';
import '../../admin_incidents/presentation/admin_incidents_page.dart';
import '../../admin_payments/presentation/admin_payments_history_page.dart';
import '../../admin_reservations/presentation/admin_reservations_page.dart';
import '../../admin_users/presentation/admin_users_page.dart';
import '../../admin_warehouses/presentation/admin_warehouses_page.dart';
import '../../delivery/presentation/delivery_monitor_page.dart';
import '../../ops_qr/presentation/ops_qr_handoff_page.dart';
import '../../payments/presentation/cash_payments_page.dart';

class AdminShellPage extends StatelessWidget {
  const AdminShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;

    if (currentPath.startsWith('/admin/users')) {
      return AdminUsersPage();
    }
    if (currentPath.startsWith('/admin/warehouses')) {
      return AdminWarehousesPage();
    }
    if (currentPath.startsWith('/admin/reservations')) {
      return AdminReservationsPage();
    }
    if (currentPath.startsWith('/admin/delivery')) {
      return DeliveryMonitorPage(
        title: context.l10n.t('tracking_logistico'),
        currentRoute: '/admin/delivery',
      );
    }
    if (currentPath.startsWith('/admin/incidents')) {
      return AdminIncidentsPage(currentRoute: '/admin/incidents');
    }
    if (currentPath.startsWith('/admin/cash-payments')) {
      return const CashPaymentsPage(
        title: 'cobros_en_caja',
        currentRoute: '/admin/cash-payments',
      );
    }
    if (currentPath.startsWith('/admin/qr-handoff')) {
      return const OpsQrHandoffPage(currentRoute: '/admin/qr-handoff');
    }
    if (currentPath.startsWith('/admin/payments-history')) {
      return AdminPaymentsHistoryPage();
    }
    if (currentPath.startsWith('/admin/ratings')) {
      return AdminRatingsPage();
    }
    if (currentPath.startsWith('/admin/system')) {
      return SystemAdminPage();
    }
    return const AdminDashboardPage();
  }
}

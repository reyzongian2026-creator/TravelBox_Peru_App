import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/layout/responsive_layout.dart';
import 'admin_dashboard_page.dart';
import 'admin_ratings_page.dart';
import 'system_admin_page.dart';
import '../../admin_users/presentation/admin_users_page.dart';
import '../../admin_reservations/presentation/admin_reservations_page.dart';
import '../../admin_payments/presentation/admin_payments_history_page.dart';
import '../../admin_warehouses/presentation/admin_warehouses_page.dart';
import '../../admin_incidents/presentation/admin_incidents_page.dart';
import '../../delivery/presentation/delivery_monitor_page.dart';

final adminTabIndexProvider = StateProvider<int>((ref) {
  final currentRoute = ref.watch(adminCurrentRouteProvider);
  return _routeToTabIndex(currentRoute);
});

final adminCurrentRouteProvider = StateProvider<String>((ref) => '/admin/dashboard');

int _routeToTabIndex(String route) {
  if (route.startsWith('/admin/users')) return 1;
  if (route.startsWith('/admin/warehouses')) return 2;
  if (route.startsWith('/admin/reservations')) return 3;
  if (route.startsWith('/admin/delivery')) return 4;
  if (route.startsWith('/admin/incidents')) return 5;
  if (route.startsWith('/admin/payments')) return 6;
  if (route.startsWith('/admin/ratings')) return 7;
  if (route.startsWith('/admin/system')) return 8;
  return 0;
}

class AdminShellPage extends ConsumerWidget {
  const AdminShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(adminTabIndexProvider);
    final l10n = context.l10n;
    final responsive = context.responsive;

    final tabs = [
      _TabItem(icon: Icons.dashboard, label: l10n.t('dashboard'), route: '/admin/dashboard'),
      _TabItem(icon: Icons.people, label: l10n.t('users'), route: '/admin/users'),
      _TabItem(icon: Icons.store_outlined, label: l10n.t('admin_warehouses_title'), route: '/admin/warehouses'),
      _TabItem(icon: Icons.luggage_outlined, label: l10n.t('reservas'), route: '/admin/reservations'),
      _TabItem(icon: Icons.local_shipping_outlined, label: l10n.t('tracking_logistico'), route: '/admin/delivery'),
      _TabItem(icon: Icons.report_problem_outlined, label: l10n.t('incidencias'), route: '/admin/incidents'),
      _TabItem(icon: Icons.payments, label: l10n.t('payments'), route: '/admin/payments-history'),
      _TabItem(icon: Icons.analytics, label: l10n.t('reports'), route: '/admin/ratings'),
      _TabItem(icon: Icons.settings, label: l10n.t('settings'), route: '/admin/system'),
    ];

    final pages = <Widget>[
      AdminDashboardPage(),
      AdminUsersPage(),
      AdminWarehousesPage(),
      AdminReservationsPage(),
      DeliveryMonitorPage(title: 'tracking_logistico', currentRoute: '/admin/delivery'),
      AdminIncidentsPage(currentRoute: '/admin/incidents'),
      AdminPaymentsHistoryPage(),
      AdminRatingsPage(),
      SystemAdminPage(),
    ];

    return DefaultTabController(
      length: tabs.length,
      initialIndex: currentIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('admin_panel')),
          bottom: TabBar(
            isScrollable: responsive.isMobile,
            tabs: tabs.map((t) => Tab(icon: Icon(t.icon), text: t.label)).toList(),
            onTap: (index) {
              ref.read(adminTabIndexProvider.notifier).state = index;
              context.go(tabs[index].route);
            },
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: pages,
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final String route;

  _TabItem({required this.icon, required this.label, required this.route});
}

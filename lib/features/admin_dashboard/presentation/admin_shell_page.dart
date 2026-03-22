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

final adminTabIndexProvider = StateProvider<int>((ref) => 0);

class AdminShellPage extends ConsumerWidget {
  const AdminShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ignore: unused_local_variable
    final currentIndex = ref.watch(adminTabIndexProvider);
    final l10n = context.l10n;
    final responsive = context.responsive;

    final tabs = [
      _TabItem(icon: Icons.dashboard, label: l10n.t('dashboard'), route: '/admin/dashboard'),
      _TabItem(icon: Icons.people, label: l10n.t('users'), route: '/admin/users'),
      _TabItem(icon: Icons.inventory, label: l10n.t('reservas'), route: '/admin/reservations'),
      _TabItem(icon: Icons.payments, label: l10n.t('payments'), route: '/admin/payments-history'),
      _TabItem(icon: Icons.analytics, label: l10n.t('reports'), route: '/admin/ratings'),
      _TabItem(icon: Icons.settings, label: l10n.t('settings'), route: '/admin/system'),
    ];

    return DefaultTabController(
      length: tabs.length,
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
          children: [
            AdminDashboardPage(),
            AdminUsersPage(),
            AdminReservationsPage(),
            AdminPaymentsHistoryPage(),
            AdminRatingsPage(),
            SystemAdminPage(),
          ],
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

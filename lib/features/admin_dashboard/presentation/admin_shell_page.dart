import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import 'admin_dashboard_page.dart';
import 'admin_ratings_page.dart';
import 'system_admin_page.dart';

final adminTabIndexProvider = StateProvider<int>((ref) => 0);

class AdminShellPage extends ConsumerWidget {
  const AdminShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(adminTabIndexProvider);
    final l10n = context.l10n;
    final responsive = context.responsive;

    final tabs = [
      _TabItem(icon: Icons.dashboard, label: l10n.t('dashboard')),
      _TabItem(icon: Icons.people, label: l10n.t('users')),
      _TabItem(icon: Icons.inventory, label: l10n.t('reservas')),
      _TabItem(icon: Icons.payments, label: l10n.t('payments')),
      _TabItem(icon: Icons.analytics, label: l10n.t('reports')),
      _TabItem(icon: Icons.settings, label: l10n.t('settings')),
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
            },
          ),
        ),
        body: TabBarView(
          children: [
            AdminDashboardPage(),
            _PlaceholderTab(title: l10n.t('users'), icon: Icons.people),
            _PlaceholderTab(title: l10n.t('reservas'), icon: Icons.inventory),
            _PlaceholderTab(title: l10n.t('payments'), icon: Icons.payments),
            _ReportsTabContent(),
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

  _TabItem({required this.icon, required this.label});
}

class _PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderTab({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tab: $title',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _ReportsTabContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.bar_chart),
            title: Text(l10n.t('dashboard_revenue')),
            subtitle: Text(l10n.t('revenue_by_period')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.star),
            title: Text(l10n.t('ratings_management')),
            subtitle: Text(l10n.t('manage_all_ratings')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.health_and_safety),
            title: Text(l10n.t('system_health')),
            subtitle: Text(l10n.t('view_system_status')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.t('audit_log')),
            subtitle: Text(l10n.t('view_audit_trail')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

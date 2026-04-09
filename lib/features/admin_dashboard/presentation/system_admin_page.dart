import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/widgets/state_views.dart';
import '../data/admin_dashboard_repository.dart';

final systemHealthProvider = FutureProvider.autoDispose<SystemHealthInfo>((ref) async {
  return ref.read(adminDashboardRepositoryProvider).getSystemHealth();
});

final auditLogProvider = FutureProvider.autoDispose<List<AuditLogEntry>>((ref) async {
  return ref.read(adminDashboardRepositoryProvider).getAuditLog(limit: 50);
});

final azureResourcesProvider = FutureProvider<AzureResourcesInfo>((ref) async {
  return ref.read(adminDashboardRepositoryProvider).getAzureResources();
});

class SystemAdminPage extends ConsumerWidget {
  const SystemAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.t('system_health')),
              Tab(text: l10n.t('audit_log')),
              Tab(text: 'Azure Resources'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SystemHealthTab(),
                _AuditLogTab(),
                _AzureResourcesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemHealthTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(systemHealthProvider);
    final l10n = context.l10n;
    final responsive = context.responsive;
    
    return healthAsync.when(
      data: (health) {
        return ListView(
          padding: responsive.pageInsets(),
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(responsive.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          health.status == 'UP' ? Icons.check_circle : Icons.error,
                          color: health.status == 'UP' ? Colors.green : Colors.red,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.t('status')}: ${health.status}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: health.status == 'UP' ? Colors.green : Colors.red,
                              ),
                            ),
                            Text(
                              '${health.application} :${health.port}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('dd/MM HH:mm:ss').format(health.timestamp),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: responsive.itemGap),
            Card(
              child: Padding(
                padding: EdgeInsets.all(responsive.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('memory_usage'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: responsive.itemGap),
                    _MemoryBar(
                      usedMB: health.memory.usedMB,
                      maxMB: health.memory.maxMB,
                      freeMB: health.memory.freeMB,
                      usagePercent: health.memory.usagePercent,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _InfoChip(label: l10n.t('used'), value: '${health.memory.usedMB} MB'),
                        _InfoChip(label: l10n.t('free'), value: '${health.memory.freeMB} MB'),
                        _InfoChip(label: l10n.t('total'), value: '${health.memory.maxMB} MB'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: responsive.itemGap),
            Card(
              child: Padding(
                padding: EdgeInsets.all(responsive.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('cpu_info'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: responsive.itemGap),
                    Row(
                      children: [
                        _InfoChip(
                          label: l10n.t('processors'),
                          value: '${health.cpu.availableProcessors}',
                        ),
                        const SizedBox(width: 16),
                        _InfoChip(
                          label: l10n.t('load_average'),
                          value: health.cpu.loadAverage >= 0 
                              ? health.cpu.loadAverage.toStringAsFixed(2) 
                              : 'N/A',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: responsive.itemGap),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(systemHealthProvider),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.t('recargar')),
            ),
          ],
        );
      },
      loading: () => const LoadingStateView(),
      error: (e, _) => ErrorStateView(
        message: '$e',
        onRetry: () => ref.invalidate(systemHealthProvider),
      ),
    );
  }
}

class _MemoryBar extends StatelessWidget {
  final int usedMB;
  final int maxMB;
  final int freeMB;
  final double usagePercent;

  const _MemoryBar({
    required this.usedMB,
    required this.maxMB,
    required this.freeMB,
    required this.usagePercent,
  });

  @override
  Widget build(BuildContext context) {
    final color = usagePercent > 80 ? Colors.red : usagePercent > 60 ? Colors.orange : Colors.green;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: usagePercent / 100,
            minHeight: 24,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${usagePercent.toStringAsFixed(1)}%',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _AuditLogTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(auditLogProvider);
    final l10n = context.l10n;
    final responsive = context.responsive;
    
    return logAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Text(l10n.t('no_audit_entries')),
          );
        }
        return ListView.builder(
          padding: responsive.pageInsets(),
          itemCount: entries.length + 1,
          itemBuilder: (context, index) {
            if (index == entries.length) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () => ref.invalidate(auditLogProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.t('recargar')),
                ),
              );
            }
            final entry = entries[index];
            return Card(
              child: ListTile(
                leading: Icon(_actionIcon(entry.action)),
                title: Text(entry.action),
                subtitle: Text(
                  '${entry.entityType} #${entry.entityId}'
                  '${entry.performedBy != null ? ' - ${entry.performedBy}' : ''}',
                ),
                trailing: Text(
                  DateFormat('dd/MM HH:mm').format(entry.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          },
        );
      },
      loading: () => const LoadingStateView(),
      error: (e, _) => ErrorStateView(
        message: '$e',
        onRetry: () => ref.invalidate(auditLogProvider),
      ),
    );
  }

  IconData _actionIcon(String action) {
    if (action.contains('CREATE') || action.contains('CREATE')) return Icons.add_circle;
    if (action.contains('UPDATE') || action.contains('UPDATE')) return Icons.edit;
    if (action.contains('DELETE') || action.contains('DELETE')) return Icons.delete;
    if (action.contains('LOGIN') || action.contains('LOGIN')) return Icons.login;
    if (action.contains('LOGOUT') || action.contains('LOGOUT')) return Icons.logout;
    return Icons.info;
  }
}

class _AzureResourcesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resourcesAsync = ref.watch(azureResourcesProvider);
    final l10n = context.l10n;
    final responsive = context.responsive;

    return resourcesAsync.when(
      data: (resources) {
        return ListView(
          padding: responsive.pageInsets(),
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(responsive.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud, color: Colors.blue, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Azure Resources',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          'Updated: ${resources.generatedAt}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: responsive.itemGap),
            ...resources.resources.map((resource) => Card(
              child: Padding(
                padding: EdgeInsets.all(responsive.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _ResourceIcon(resource.name),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                resource.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                resource.resourceName,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(resource.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetricChip(label: 'SKU', value: resource.sku),
                        ...resource.metrics.entries.map((e) => _MetricChip(
                          label: e.key,
                          value: e.value.toString(),
                        )),
                      ],
                    ),
                    if (resource.expiresAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            'Expires: ${resource.expiresAt}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            )),
            SizedBox(height: responsive.itemGap),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(responsive.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.attach_money, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Estimated Monthly Cost',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...resources.estimatedCosts.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(item.service)),
                          Text(
                            '\$${item.amount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL (${resources.estimatedCosts.currency})',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${resources.estimatedCosts.totalMonthly.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: responsive.itemGap),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(azureResourcesProvider),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.t('recargar')),
            ),
          ],
        );
      },
      loading: () => const LoadingStateView(),
      error: (e, _) => ErrorStateView(
        message: '$e',
        onRetry: () => ref.invalidate(azureResourcesProvider),
      ),
    );
  }
}

class _ResourceIcon extends StatelessWidget {
  final String name;
  const _ResourceIcon(this.name);

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    if (name.contains('App Service')) {
      icon = Icons.web;
      color = Colors.blue;
    } else if (name.contains('PostgreSQL')) {
      icon = Icons.storage;
      color = Colors.purple;
    } else if (name.contains('AI') || name.contains('Translator')) {
      icon = Icons.translate;
      color = Colors.orange;
    } else if (name.contains('Maps')) {
      icon = Icons.map;
      color = Colors.green;
    } else if (name.contains('Key Vault')) {
      icon = Icons.vpn_key;
      color = Colors.red;
    } else {
      icon = Icons.cloud;
      color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    if (status == 'Running' || status == 'Active') {
      color = Colors.green;
    } else if (status == 'Warning') {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

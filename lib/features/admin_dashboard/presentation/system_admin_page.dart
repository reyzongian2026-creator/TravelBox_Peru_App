import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/widgets/state_views.dart';
import '../data/admin_dashboard_repository.dart';

final systemHealthProvider = FutureProvider<SystemHealthInfo>((ref) async {
  return ref.read(adminDashboardRepositoryProvider).getSystemHealth();
});

final auditLogProvider = FutureProvider<List<AuditLogEntry>>((ref) async {
  return ref.read(adminDashboardRepositoryProvider).getAuditLog(limit: 50);
});

class SystemAdminPage extends ConsumerWidget {
  const SystemAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.t('system_health')),
              Tab(text: l10n.t('audit_log')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SystemHealthTab(),
                _AuditLogTab(),
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

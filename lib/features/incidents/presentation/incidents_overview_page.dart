import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../shared/utils/status_localizer.dart';
import '../data/incidents_repository.dart';

final clientIncidentsPageProvider = StateProvider<int>((ref) => 0);

final clientIncidentsHistoryProvider = FutureProvider<PagedResult<Incident>>((
  ref,
) async {
  final repository = ref.read(incidentsRepositoryProvider);
  final page = ref.watch(clientIncidentsPageProvider);
  return repository.getIncidentsPage(page: page, size: 10);
});

class ClientIncidentsOverviewPage extends ConsumerWidget {
  const ClientIncidentsOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentsAsync = ref.watch(clientIncidentsHistoryProvider);

    return AppShellScaffold(
      title: context.l10n.t('incidencias'),
      currentRoute: '/incidents-history',
      child: incidentsAsync.when(
        data: (pageData) {
          if (pageData.content.isEmpty) {
            return EmptyStateView(
              message: context.l10n.t('incident_admin_empty_for_filter'),
              actionLabel: context.l10n.t('reservations'),
              onAction: () => context.go('/reservations'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pageData.content.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == pageData.content.length) {
                return _ClientIncidentsPagination(pageData: pageData);
              }

              final incident = pageData.content[index];
              return _ClientIncidentHistoryCard(incident: incident);
            },
          );
        },
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: '${context.l10n.t('incident_admin_load_failed')}: $error',
          onRetry: () => ref.invalidate(clientIncidentsHistoryProvider),
        ),
      ),
    );
  }
}

class _ClientIncidentHistoryCard extends StatelessWidget {
  const _ClientIncidentHistoryCard({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incidentLabel = context.l10n.t('incident_ticket');
    final reservationLabel = context.l10n.t('incident_reservation');
    final cleanDescription = incident.description.trim();
    final reservationId = incident.reservationId?.trim();
    final hasReservation = reservationId != null && reservationId.isNotEmpty;
    final chipColor = _statusColor(incident.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$incidentLabel #${incident.id}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PeruTime.formatDateTime(incident.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(_localizedIncidentStatus(context, incident.status)),
                  backgroundColor: chipColor.withValues(alpha: 0.12),
                  side: BorderSide(color: chipColor.withValues(alpha: 0.24)),
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color: chipColor,
                    fontWeight: FontWeight.w700,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (incident.title.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                incident.title.trim(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (cleanDescription.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                cleanDescription,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(incident.type.trim().isEmpty ? 'General' : incident.type),
                  visualDensity: VisualDensity.compact,
                ),
                if (hasReservation)
                  Chip(
                    label: Text('$reservationLabel #$reservationId'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if ((incident.resolution?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${context.l10n.t('incident_resolution')}: ${incident.resolution!.trim()}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasReservation)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/reservation/$reservationId'),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(context.l10n.t('ver_reserva')),
                  ),
                if (hasReservation)
                  FilledButton.icon(
                    onPressed: () =>
                        context.push('/incidents?reservationId=$reservationId'),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(context.l10n.t('incidencias')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientIncidentsPagination extends ConsumerWidget {
  const _ClientIncidentsPagination({required this.pageData});

  final PagedResult<Incident> pageData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPages = pageData.totalPages <= 0 ? 1 : pageData.totalPages;
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${context.l10n.t('my_reservations_page')} ${pageData.page + 1} ${context.l10n.t('my_reservations_of')} $totalPages',
          ),
          OutlinedButton.icon(
            onPressed: pageData.page <= 0
                ? null
                : () {
                    final notifier = ref.read(clientIncidentsPageProvider.notifier);
                    notifier.state = notifier.state - 1;
                  },
            icon: const Icon(Icons.chevron_left),
            label: Text(context.l10n.t('previous')),
          ),
          FilledButton.icon(
            onPressed: pageData.last
                ? null
                : () {
                    final notifier = ref.read(clientIncidentsPageProvider.notifier);
                    notifier.state = notifier.state + 1;
                  },
            icon: const Icon(Icons.chevron_right),
            label: Text(context.l10n.t('next')),
          ),
        ],
      ),
    );
  }
}

String _localizedIncidentStatus(BuildContext context, String rawStatus) {
  final normalized = rawStatus.trim().toUpperCase();
  return switch (normalized) {
    'OPEN' => 'OPEN',
    'RESOLVED' => context.l10n.t('reservation_status_completed'),
    'CLOSED' => context.l10n.t('reservation_status_completed'),
    'PENDING' => paymentStatusLabel(context, 'PENDING'),
    _ => rawStatus,
  };
}

Color _statusColor(String rawStatus) {
  switch (rawStatus.trim().toUpperCase()) {
    case 'RESOLVED':
    case 'CLOSED':
      return const Color(0xFF168F64);
    case 'PENDING':
      return const Color(0xFFF29F05);
    case 'OPEN':
    default:
      return const Color(0xFF2E5BFF);
  }
}

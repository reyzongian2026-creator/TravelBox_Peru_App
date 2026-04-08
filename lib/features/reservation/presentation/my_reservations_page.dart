import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../shared/utils/status_localizer.dart';
import '../domain/reservation_repository.dart';
import 'reservation_providers.dart';

class MyReservationsPage extends ConsumerStatefulWidget {
  const MyReservationsPage({
    super.key,
    this.currentRoute = '/reservations',
    this.trackingOnly = false,
  });

  final String currentRoute;
  final bool trackingOnly;

  @override
  ConsumerState<MyReservationsPage> createState() => _MyReservationsPageState();
}

class _MyReservationsPageState extends ConsumerState<MyReservationsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pageResult = ref.watch(myReservationPageResultProvider);

    final content = pageResult.when(
      data: (result) => _buildPagedBody(context, result),
      loading: () => const LoadingStateView(),
      error: (error, _) => ErrorStateView(
        message: '${l10n.t('my_reservations_load_failed')}: $error',
        onRetry: () {
          ref.read(myReservationPageProvider.notifier).state = 0;
          ref.invalidate(myReservationPageResultProvider);
        },
      ),
    );

    return AppShellScaffold(
      title: l10n.t(
        widget.trackingOnly ? 'tracking_logistico' : 'my_reservations_title',
      ),
      currentRoute: widget.currentRoute,
      child: content,
    );
  }

  Widget _buildPagedBody(BuildContext context, ReservationPagedResult result) {
    final l10n = context.l10n;
    final responsive = context.responsive;
    final items = widget.trackingOnly
        ? result.items.where(_isTrackingCandidate).toList()
        : result.items;

    if (items.isEmpty && result.page == 0) {
      if (widget.trackingOnly) {
        return EmptyStateView(
          message: l10n.t('tracking_no_disponible'),
          actionLabel: l10n.t('go_my_reservations'),
          onAction: () => context.go('/reservations'),
        );
      }
      return EmptyStateView(
        message: l10n.t('my_reservations_empty'),
        actionLabel: l10n.t('my_reservations_browse_warehouses'),
        onAction: () => context.go('/discovery'),
      );
    }

    final latestReservation = items.isNotEmpty ? items.first : null;
    final historyItems = items.length > 1 ? items.sublist(1) : <Reservation>[];

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.read(myReservationPageProvider.notifier).state = 0;
              ref.invalidate(myReservationPageResultProvider);
              await ref.read(myReservationPageResultProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: responsive.pageInsets(
                top: responsive.verticalPadding,
                bottom: 16,
              ),
              children: [
                if (latestReservation != null)
                  _LatestReservationHero(
                    reservation: latestReservation,
                    trackingOnly: widget.trackingOnly,
                  ),
                const SizedBox(height: 18),
                if (historyItems.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.t('my_reservations_history_title'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (result.totalPages > 1)
                        Text(
                          '${l10n.t('my_reservations_page')} ${result.page + 1} ${l10n.t('my_reservations_of')} ${result.totalPages}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...historyItems.map(
                    (reservation) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReservationCard(
                        reservation: reservation,
                        trackingOnly: widget.trackingOnly,
                      ),
                    ),
                  ),
                ] else if (latestReservation != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.t('my_reservations_latest_only'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (result.totalPages > 1)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.horizontalPadding,
              vertical: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: !result.hasPrevious
                      ? null
                      : () {
                          ref.read(myReservationPageProvider.notifier).state =
                              result.page - 1;
                        },
                  icon: const Icon(Icons.chevron_left),
                  label: Text(l10n.t('previous')),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: !result.hasNext
                      ? null
                      : () {
                          ref.read(myReservationPageProvider.notifier).state =
                              result.page + 1;
                        },
                  icon: const Icon(Icons.chevron_right),
                  label: Text(l10n.t('next')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LatestReservationHero extends StatelessWidget {
  const _LatestReservationHero({
    required this.reservation,
    required this.trackingOnly,
  });

  final Reservation reservation;
  final bool trackingOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173B56), Color(0xFF1F6E8C)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('my_reservations_latest_title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reservation.warehouse.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reservation.code,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(label: reservation.status.localizedLabel(context)),
              _HeroChip(
                label:
                    '${reservation.bagCount} ${l10n.t('my_reservations_bags')}',
              ),
              _HeroChip(
                label: PeruTime.formatDateRange(
                  reservation.startAt,
                  reservation.endAt,
                ),
              ),
              _HeroChip(
                label:
                    '${l10n.t('my_reservations_total_prefix')} S/${reservation.totalPrice.toStringAsFixed(2)}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF173B56),
            ),
            onPressed: () => context.push(
              _primaryReservationRoute(reservation, trackingOnly: trackingOnly),
            ),
            icon: Icon(
              trackingOnly
                  ? Icons.local_shipping_outlined
                  : Icons.receipt_long_outlined,
            ),
            label: Text(
              trackingOnly
                  ? _trackingActionLabel(context, reservation)
                  : l10n.t('view_detail'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.trackingOnly,
  });

  final Reservation reservation;
  final bool trackingOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          _primaryReservationRoute(reservation, trackingOnly: trackingOnly),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reservation.warehouse.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(reservation.status.localizedLabel(context)),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: reservation.status.color),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${l10n.t('my_reservations_code_prefix')} ${reservation.code}',
              ),
              Text(
                '${PeruTime.formatDateTime(reservation.startAt)} -> ${PeruTime.formatDateTime(reservation.endAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${l10n.t('my_reservations_total_prefix')} S/${reservation.totalPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (trackingOnly) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _trackingActionLabel(context, reservation),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

bool _isTrackingCandidate(Reservation reservation) {
  if (reservation.pickupRequested || reservation.dropoffRequested) {
    return true;
  }
  switch (reservation.status) {
    case ReservationStatus.checkinPending:
    case ReservationStatus.stored:
    case ReservationStatus.outForDelivery:
    case ReservationStatus.readyForPickup:
    case ReservationStatus.completed:
      return true;
    case ReservationStatus.draft:
    case ReservationStatus.pendingPayment:
    case ReservationStatus.confirmed:
    case ReservationStatus.cancelled:
    case ReservationStatus.incident:
    case ReservationStatus.expired:
      return false;
  }
}

String _primaryReservationRoute(
  Reservation reservation, {
  required bool trackingOnly,
}) {
  if (trackingOnly) {
    return '/tracking/${reservation.id}';
  }
  return '/reservation/${reservation.id}';
}

String _trackingActionLabel(BuildContext context, Reservation reservation) {
  if (reservation.status == ReservationStatus.checkinPending) {
    return context.l10n.t('reservation_tracking_pickup');
  }
  if (reservation.status == ReservationStatus.outForDelivery ||
      reservation.dropoffRequested) {
    return context.l10n.t('reservation_tracking_delivery');
  }
  return context.l10n.t('tracking');
}

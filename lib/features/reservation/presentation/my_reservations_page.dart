import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/utils/peru_time.dart';
import 'reservation_providers.dart';

class MyReservationsPage extends ConsumerStatefulWidget {
  const MyReservationsPage({super.key});

  @override
  ConsumerState<MyReservationsPage> createState() => _MyReservationsPageState();
}

class _MyReservationsPageState extends ConsumerState<MyReservationsPage> {
  static const int _historyPageSize = 4;
  int _historyPage = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final syncState = ref.watch(myReservationsProvider);
    ref.watch(myReservationIdsSignatureProvider);
    final reservationIds = ref.read(myReservationIdsProvider);

    final content = _buildBody(
      context,
      syncState: syncState,
      reservationIds: reservationIds,
    );

    return AppShellScaffold(
      title: l10n.t('my_reservations_title'),
      currentRoute: '/reservations',
      child: content,
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required AsyncValue<List<Reservation>> syncState,
    required List<String> reservationIds,
  }) {
    final l10n = context.l10n;
    if (syncState.isLoading && reservationIds.isEmpty) {
      return const LoadingStateView();
    }
    if (syncState.hasError && reservationIds.isEmpty) {
      return ErrorStateView(
        message: '${l10n.t('my_reservations_load_failed')}: ${syncState.error}',
        onRetry: () => ref.invalidate(myReservationsProvider),
      );
    }
    if (reservationIds.isEmpty) {
      return EmptyStateView(
        message: l10n.t('my_reservations_empty'),
        actionLabel: l10n.t('my_reservations_browse_warehouses'),
        onAction: () => context.go('/discovery'),
      );
    }

    final latestReservationId = reservationIds.first;
    final historyReservationIds = reservationIds.skip(1).toList();
    final totalHistoryPages = historyReservationIds.isEmpty
        ? 0
        : ((historyReservationIds.length - 1) ~/ _historyPageSize) + 1;
    final effectiveHistoryPage = totalHistoryPages == 0
        ? 0
        : _historyPage.clamp(0, totalHistoryPages - 1);
    final visibleHistoryIds = totalHistoryPages == 0
        ? const <String>[]
        : historyReservationIds
              .skip(effectiveHistoryPage * _historyPageSize)
              .take(_historyPageSize)
              .toList();

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _historyPage = 0);
        ref.invalidate(myReservationsProvider);
        await ref.read(myReservationsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _LatestReservationHeroById(reservationId: latestReservationId),
          const SizedBox(height: 18),
          if (historyReservationIds.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.t('my_reservations_history_title'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (totalHistoryPages > 1)
                  Text(
                    '${l10n.t('my_reservations_page')} ${effectiveHistoryPage + 1} ${l10n.t('my_reservations_of')} $totalHistoryPages',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ...visibleHistoryIds.map(
              (reservationId) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReservationCardById(reservationId: reservationId),
              ),
            ),
            if (totalHistoryPages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: effectiveHistoryPage == 0
                          ? null
                          : () => setState(() => _historyPage -= 1),
                      icon: const Icon(Icons.chevron_left),
                      label: Text(l10n.t('previous')),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: effectiveHistoryPage >= totalHistoryPages - 1
                          ? null
                          : () => setState(() => _historyPage += 1),
                      icon: const Icon(Icons.chevron_right),
                      label: Text(l10n.t('next')),
                    ),
                  ],
                ),
              ),
          ] else
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
    );
  }
}

class _LatestReservationHeroById extends ConsumerWidget {
  const _LatestReservationHeroById({required this.reservationId});

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservation = ref.watch(
      reservationInStoreByIdProvider(reservationId),
    );
    if (reservation == null) {
      return const SizedBox.shrink();
    }
    return _LatestReservationHero(reservation: reservation);
  }
}

class _ReservationCardById extends ConsumerWidget {
  const _ReservationCardById({required this.reservationId});

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservation = ref.watch(
      reservationInStoreByIdProvider(reservationId),
    );
    if (reservation == null) {
      return const SizedBox.shrink();
    }
    return _ReservationCard(reservation: reservation);
  }
}

class _LatestReservationHero extends StatelessWidget {
  const _LatestReservationHero({required this.reservation});

  final Reservation reservation;

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
              _HeroChip(label: reservation.status.label),
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
            onPressed: () => context.push('/reservation/${reservation.id}'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(l10n.t('view_detail')),
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
  const _ReservationCard({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/reservation/${reservation.id}'),
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
                    label: Text(reservation.status.label),
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
            ],
          ),
        ),
      ),
    );
  }
}

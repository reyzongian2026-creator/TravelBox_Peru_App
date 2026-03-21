import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/status_localizer.dart';
import '../../reservation/data/reservation_repository_impl.dart';
import '../../reservation/presentation/reservation_providers.dart';

class AdminReservationsPage extends ConsumerStatefulWidget {
  AdminReservationsPage({
    super.key,
    this.title = 'admin_reservations_title',
    this.currentRoute = '/admin/reservations',
  });

  final String title;
  final String currentRoute;

  @override
  ConsumerState<AdminReservationsPage> createState() =>
      _AdminReservationsPageState();
}

class _AdminReservationsPageState extends ConsumerState<AdminReservationsPage> {
  late final TextEditingController _searchController;
  String? _busyReservationId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(adminReservationSearchProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final itemGap = responsive.itemGap;
    final sectionGap = responsive.sectionGap;
    final cardPadding = responsive.cardPadding;
    final selectedStatus = ref.watch(adminReservationStatusFilterProvider);
    final reservations = ref.watch(adminReservationPageResultProvider);
    return AppShellScaffold(
      title: context.l10n.t(widget.title),
      currentRoute: widget.currentRoute,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.horizontalPadding,
              responsive.verticalPadding,
              responsive.horizontalPadding,
              0,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    ref.read(adminReservationPageProvider.notifier).state = 0;
                    ref.read(adminReservationSearchProvider.notifier).state =
                        value;
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: context.l10n.t('admin_reservation_search_label'),
                    hintText: context.l10n.t('admin_reservation_search_hint'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                SizedBox(height: itemGap),
                _StatusFilterBar(
                  selectedStatus: selectedStatus,
                  itemGap: itemGap,
                  mobile: responsive.isMobile,
                  onStatusSelected: (status) {
                    ref.read(adminReservationPageProvider.notifier).state = 0;
                    ref
                            .read(adminReservationStatusFilterProvider.notifier)
                            .state =
                        status;
                  },
                ),
                SizedBox(height: itemGap),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _refreshReservations,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.t('recargar')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: itemGap),
          Expanded(
            child: reservations.when(
              data: (pageResult) {
                final items = pageResult.items;
                if (items.isEmpty) {
                  return EmptyStateView(
                    message: _searchController.text.trim().isEmpty
                        ? context.l10n.t('admin_reservation_empty_default')
                        : '${context.l10n.t('admin_reservation_empty_query')}: "${_searchController.text.trim()}".',
                  );
                }
                return ListView.separated(
                  padding: responsive.pageInsets(top: 0, bottom: sectionGap),
                  itemCount: items.length + 1,
                  separatorBuilder: (context, index) =>
                      SizedBox(height: itemGap),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      final totalPages = pageResult.totalPages <= 0
                          ? 1
                          : pageResult.totalPages;
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: itemGap,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${context.l10n.t('my_reservations_page')} ${pageResult.page + 1} ${context.l10n.t('my_reservations_of')} $totalPages',
                            ),
                            OutlinedButton.icon(
                              onPressed: pageResult.hasPrevious
                                  ? _goToPreviousPage
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                              label: Text(context.l10n.t('previous')),
                            ),
                            FilledButton.icon(
                              onPressed: pageResult.hasNext
                                  ? _goToNextPage
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                              label: Text(context.l10n.t('next')),
                            ),
                          ],
                        ),
                      );
                    }
                    final item = items[index];
                    final isBusy = _busyReservationId == item.id;
                    return Card(
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: itemGap,
                              runSpacing: itemGap,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  item.warehouse.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Chip(
                                  label: Text(
                                    item.status.localizedLabel(context),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (isBusy)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: itemGap / 1.5),
                            SelectableText(
                              '${context.l10n.t('admin_reservation_code')} ${item.code}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: itemGap / 2),
                            Text(
                              '${item.warehouse.city}, ${item.warehouse.district}\n${_formatDate(item.startAt)} -> ${_formatDate(item.endAt)}\n${context.l10n.t('admin_reservation_total')} S/${item.totalPrice.toStringAsFixed(2)}',
                            ),
                            SizedBox(height: sectionGap),
                            Wrap(
                              spacing: itemGap,
                              runSpacing: itemGap,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: isBusy
                                      ? null
                                      : () => context.go(
                                          '/reservation/${item.id}',
                                        ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 40),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: Text(context.l10n.t('ver_reserva')),
                                ),
                                if (item.status ==
                                        ReservationStatus.confirmed &&
                                    item.pickupRequested)
                                  FilledButton.tonalIcon(
                                    onPressed: isBusy
                                        ? null
                                        : () => _openDeliveryRequest(
                                            item,
                                            type: 'PICKUP',
                                          ),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: Icon(Icons.home_work_outlined),
                                    label: Text(
                                      context.l10n.t('solicitar_recojo'),
                                    ),
                                  ),
                                if (item.status ==
                                        ReservationStatus.confirmed ||
                                    item.status ==
                                        ReservationStatus.checkinPending)
                                  FilledButton.tonalIcon(
                                    onPressed: isBusy
                                        ? null
                                        : () => context.push('/ops/qr-handoff'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: Icon(Icons.inventory_2_outlined),
                                    label: Text(
                                      context.l10n.t('registrar_ingreso_qr'),
                                    ),
                                  ),
                                if (item.status == ReservationStatus.stored)
                                  FilledButton.tonalIcon(
                                    onPressed: isBusy
                                        ? null
                                        : () => _changeStatus(
                                            item: item,
                                            status: ReservationStatus
                                                .readyForPickup,
                                            message: context.l10n.t(
                                              'admin_reservation_ready_pickup_msg',
                                            ),
                                          ),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: Icon(Icons.shopping_bag_outlined),
                                    label: Text(
                                      context.l10n.t('lista_para_recojo'),
                                    ),
                                  ),
                                if ((item.status == ReservationStatus.stored ||
                                        item.status ==
                                            ReservationStatus.readyForPickup) &&
                                    item.dropoffRequested)
                                  FilledButton.tonalIcon(
                                    onPressed: isBusy
                                        ? null
                                        : () => _openDeliveryRequest(
                                            item,
                                            type: 'DELIVERY',
                                          ),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: Icon(Icons.local_shipping_outlined),
                                    label: Text(
                                      context.l10n.t('solicitar_delivery'),
                                    ),
                                  ),
                                if (item.status ==
                                        ReservationStatus.readyForPickup ||
                                    item.status ==
                                        ReservationStatus.outForDelivery)
                                  FilledButton.icon(
                                    onPressed: isBusy
                                        ? null
                                        : () => _changeStatus(
                                            item: item,
                                            status: ReservationStatus.completed,
                                            message: context.l10n.t(
                                              'admin_reservation_completed_from_panel_msg',
                                            ),
                                          ),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: Icon(Icons.check_circle_outline),
                                    label: Text(context.l10n.t('finalizar')),
                                  ),
                                if (_isCancelableStatus(item.status))
                                  OutlinedButton.icon(
                                    onPressed: isBusy
                                        ? null
                                        : () => _cancelOrRefund(item),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: Icon(Icons.cancel_outlined),
                                    label: Text(
                                      context.l10n.t('cancelar__reembolsar'),
                                    ),
                                  ),
                                if (item.status ==
                                    ReservationStatus.outForDelivery)
                                  OutlinedButton.icon(
                                    onPressed: isBusy
                                        ? null
                                        : () => context.go(
                                            _trackingRoute(item.id),
                                          ),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 40),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: Icon(Icons.route_outlined),
                                    label: Text(context.l10n.t('tracking')),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: isBusy
                                      ? null
                                      : () => context.go(
                                          '/incidents?reservationId=${item.id}',
                                        ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 40),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(
                                    Icons.report_problem_outlined,
                                  ),
                                  label: Text(
                                    context.l10n.t(
                                      'reservation_report_incident',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingStateView(),
              error: (error, _) => ErrorStateView(
                message:
                    '${context.l10n.t('admin_reservation_load_failed')}: $error',
                onRetry: _refreshReservations,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeStatus({
    required Reservation item,
    required ReservationStatus status,
    required String message,
  }) async {
    setState(() => _busyReservationId = item.id);
    try {
      await ref
          .read(reservationRepositoryProvider)
          .updateStatus(
            reservationId: item.id,
            status: status,
            message: message,
          );
      _refreshReservations();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('admin_reservation_status_updated')}: '
            '${item.code} -> ${status.localizedLabel(context)}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('admin_reservation_status_update_failed')}: ${AppErrorFormatter.readable(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyReservationId = null);
      }
    }
  }

  Future<void> _cancelOrRefund(Reservation item) async {
    setState(() => _busyReservationId = item.id);
    try {
      await ref
          .read(reservationRepositoryProvider)
          .refundAndCancelReservation(
            reservationId: item.id,
            reason: context.l10n.t('admin_reservation_cancel_requested_msg'),
          );
      _refreshReservations();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('admin_reservation_refund_done')}: ${item.code}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('admin_reservation_refund_failed')}: ${AppErrorFormatter.readable(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyReservationId = null);
      }
    }
  }

  bool _isCancelableStatus(ReservationStatus status) {
    return status == ReservationStatus.draft ||
        status == ReservationStatus.pendingPayment ||
        status == ReservationStatus.confirmed ||
        status == ReservationStatus.checkinPending ||
        status == ReservationStatus.incident;
  }

  Future<void> _openDeliveryRequest(
    Reservation item, {
    required String type,
  }) async {
    final back = Uri.encodeComponent(widget.currentRoute);
    await context.push('/delivery/${item.id}?type=$type&back=$back');
    _refreshReservations();
  }

  void _refreshReservations() {
    ref.invalidate(adminReservationPageResultProvider);
    ref.invalidate(adminReservationsProvider);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(adminReservationPageProvider.notifier).state = 0;
    ref.read(adminReservationSearchProvider.notifier).state = '';
    _refreshReservations();
    setState(() {});
  }

  void _goToPreviousPage() {
    final notifier = ref.read(adminReservationPageProvider.notifier);
    if (notifier.state <= 0) {
      return;
    }
    notifier.state = notifier.state - 1;
  }

  void _goToNextPage() {
    final notifier = ref.read(adminReservationPageProvider.notifier);
    notifier.state = notifier.state + 1;
  }

  String _trackingRoute(String reservationId) {
    if (widget.currentRoute.startsWith('/operator')) {
      return '/operator/tracking/$reservationId';
    }
    return '/admin/tracking/$reservationId';
  }

  String _formatDate(DateTime value) {
    return PeruTime.formatDateTime(value);
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.selectedStatus,
    required this.itemGap,
    required this.mobile,
    required this.onStatusSelected,
  });

  final ReservationStatus? selectedStatus;
  final double itemGap;
  final bool mobile;
  final ValueChanged<ReservationStatus?> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      FilterChip(
        selected: selectedStatus == null,
        visualDensity: VisualDensity.compact,
        label: Text(context.l10n.t('todas')),
        onSelected: (_) => onStatusSelected(null),
      ),
      ...ReservationStatus.values.map(
        (status) => FilterChip(
          selected: selectedStatus == status,
          visualDensity: VisualDensity.compact,
          label: Text(status.localizedLabel(context)),
          onSelected: (_) => onStatusSelected(status),
        ),
      ),
    ];

    if (!mobile) {
      return Wrap(spacing: itemGap, runSpacing: itemGap, children: chips);
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => SizedBox(width: itemGap),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }
}

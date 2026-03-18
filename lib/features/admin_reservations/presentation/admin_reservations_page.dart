import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../reservation/data/reservation_repository_impl.dart';
import '../../reservation/presentation/reservation_providers.dart';

class AdminReservationsPage extends ConsumerStatefulWidget {
  AdminReservationsPage({
    super.key,
    this.title = 'Admin reservas',
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
    final selectedStatus = ref.watch(adminReservationStatusFilterProvider);
    final reservations = ref.watch(adminReservationListProvider);
    return AppShellScaffold(
      title: widget.title,
      currentRoute: widget.currentRoute,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    ref.read(adminReservationSearchProvider.notifier).state =
                        value;
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: 'Buscar por codigo, almacen o ciudad',
                    hintText: 'Ej. TRAVELBOX-ABC123 o Miraflores',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      selected: selectedStatus == null,
                      label: Text(context.l10n.t('todas')),
                      onSelected: (_) {
                        ref
                            .read(adminReservationStatusFilterProvider.notifier)
                            .state = null;
                      },
                    ),
                    ...ReservationStatus.values.map(
                      (status) => FilterChip(
                        selected: selectedStatus == status,
                        label: Text(status.label),
                        onSelected: (_) {
                          ref
                                  .read(
                                    adminReservationStatusFilterProvider
                                        .notifier,
                                  )
                                  .state =
                              status;
                        },
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _refreshReservations,
                      icon: Icon(Icons.refresh),
                      label: Text(context.l10n.t('recargar')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: reservations.when(
              data: (items) {
                if (items.isEmpty) {
                  return EmptyStateView(
                    message: _searchController.text.trim().isEmpty
                        ? 'No hay reservas con ese criterio.'
                        : 'No se encontro ninguna reserva para "${_searchController.text.trim()}".',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isBusy = _busyReservationId == item.id;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  item.warehouse.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Chip(label: Text(item.status.label)),
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
                            const SizedBox(height: 6),
                            SelectableText(
                              'Codigo ${item.code}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.warehouse.city}, ${item.warehouse.district}\n${_formatDate(item.startAt)} -> ${_formatDate(item.endAt)}\nTotal S/${item.totalPrice.toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: isBusy
                                      ? null
                                      : () =>
                                            context.go('/reservation/${item.id}'),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: Text(context.l10n.t('ver_reserva')),
                                ),
                                if (item.status == ReservationStatus.confirmed &&
                                    item.pickupRequested)
                                  FilledButton.tonalIcon(
                                    onPressed: isBusy
                                        ? null
                                        : () => _openDeliveryRequest(
                                              item,
                                              type: 'PICKUP',
                                            ),
                                    icon: Icon(Icons.home_work_outlined),
                                    label: Text(context.l10n.t('solicitar_recojo')),
                                  ),
                                if (item.status == ReservationStatus.confirmed ||
                                    item.status ==
                                        ReservationStatus.checkinPending)
                                  FilledButton.tonalIcon(
                                    onPressed: isBusy
                                        ? null
                                        : () => context.push('/ops/qr-handoff'),
                                    icon: Icon(Icons.inventory_2_outlined),
                                    label: Text(context.l10n.t('registrar_ingreso_qr')),
                                  ),
                                if (item.status == ReservationStatus.stored)
                                  FilledButton.tonalIcon(
                                    onPressed: isBusy
                                        ? null
                                        : () => _changeStatus(
                                              item: item,
                                              status:
                                                  ReservationStatus.readyForPickup,
                                              message:
                                                  'Reserva lista para recojo en almacen.',
                                            ),
                                    icon: Icon(Icons.shopping_bag_outlined),
                                    label: Text(context.l10n.t('lista_para_recojo')),
                                  ),
                                if ((item.status == ReservationStatus.stored ||
                                        item.status == ReservationStatus.readyForPickup) &&
                                    item.dropoffRequested)
                                  FilledButton.tonalIcon(
                                    onPressed: isBusy
                                        ? null
                                        : () => _openDeliveryRequest(
                                              item,
                                              type: 'DELIVERY',
                                            ),
                                    icon: Icon(Icons.local_shipping_outlined),
                                    label: Text(context.l10n.t('solicitar_delivery')),
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
                                              status:
                                                  ReservationStatus.completed,
                                              message:
                                                  'Reserva finalizada desde el panel operativo.',
                                            ),
                                    icon: Icon(Icons.check_circle_outline),
                                    label: Text(context.l10n.t('finalizar')),
                                  ),
                                if (_isCancelableStatus(item.status))
                                  OutlinedButton.icon(
                                    onPressed: isBusy
                                        ? null
                                        : () => _cancelOrRefund(item),
                                    icon: Icon(Icons.cancel_outlined),
                                    label: Text(context.l10n.t('cancelar__reembolsar')),
                                  ),
                                if (item.status ==
                                    ReservationStatus.outForDelivery)
                                  OutlinedButton.icon(
                                    onPressed: isBusy
                                        ? null
                                        : () =>
                                              context.go(_trackingRoute(item.id)),
                                    icon: Icon(Icons.route_outlined),
                                    label: Text(context.l10n.t('tracking')),
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
                message: 'No se pudo cargar reservas admin: $error',
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
        SnackBar(content: Text('Reserva ${item.code} actualizada a ${status.label}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo actualizar la reserva: ${AppErrorFormatter.readable(error)}',
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
            reason: 'Cancelacion solicitada desde panel operativo/admin.',
          );
      _refreshReservations();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se ejecuto cancelacion/reembolso para la reserva ${item.code}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cancelar/reembolsar: ${AppErrorFormatter.readable(error)}',
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
    ref.invalidate(adminReservationListProvider);
    ref.invalidate(adminReservationsProvider);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(adminReservationSearchProvider.notifier).state = '';
    _refreshReservations();
    setState(() {});
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


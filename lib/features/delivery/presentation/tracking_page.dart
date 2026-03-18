import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../shared/models/delivery_tracking.dart';
import '../../../shared/models/geo_route.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/state/geo_route_provider.dart';
import '../../../shared/utils/peru_time.dart';
import '../../reservation/presentation/reservation_providers.dart';

class TrackingPage extends ConsumerStatefulWidget {
  TrackingPage({
    super.key,
    required this.reservationId,
    this.title = 'Tracking',
    this.currentRoute = '/tracking',
    this.backofficeMode = false,
  });

  final String reservationId;
  final String title;
  final String currentRoute;
  final bool backofficeMode;

  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage> {
  DeliveryTrackingModel? _tracking;
  bool _loading = true;
  String? _error;
  bool _deliveryMissing = false;
  int _mockTick = 0;
  int _lastRealtimeCursor = -1;

  @override
  void initState() {
    super.initState();
    _loadTracking();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final realtimeCursor = ref.watch(reservationRealtimeEventCursorProvider);
    if (_lastRealtimeCursor != realtimeCursor) {
      final shouldReload = _lastRealtimeCursor >= 0;
      _lastRealtimeCursor = realtimeCursor;
      if (shouldReload) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _loadTracking();
        });
      }
    }
    final reservationAsync = ref.watch(
      reservationByIdProvider(widget.reservationId),
    );

    return AppShellScaffold(
      title: widget.title,
      currentRoute: widget.currentRoute,
      child: reservationAsync.when(
        data: (reservation) {
          if (_loading && _tracking == null && !_deliveryMissing) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_deliveryMissing) {
            return _MissingDeliveryState(
              reservation: reservation,
              onRefresh: _loadTracking,
              backofficeMode: widget.backofficeMode,
              currentRoute: widget.currentRoute,
            );
          }
          if (_error != null && _tracking == null) {
            return Center(child: Text(_error!));
          }
          if (_tracking == null) {
            return Center(child: Text(context.l10n.t('tracking_no_disponible')));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.backofficeMode && reservation != null) ...[
                _reservationContextCard(context, reservation),
                SizedBox(height: 12),
              ],
              _mapCard(context),
              const SizedBox(height: 12),
              _summaryCard(),
              const SizedBox(height: 12),
              _eventsCard(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('No se pudo cargar reserva para tracking: $error'),
        ),
      ),
    );
  }

  Widget _mapCard(BuildContext context) {
    final tracking = _tracking!;
    final current = LatLng(tracking.currentLatitude, tracking.currentLongitude);
    final destination = LatLng(
      tracking.destinationLatitude,
      tracking.destinationLongitude,
    );
    final routeAsync = ref.watch(
      geoRouteProvider(_routeRequestForTracking(tracking)),
    );
    final routePoints = _resolveRoutePoints(
      routeAsync,
      tracking,
      current,
      destination,
    );
    final route = routeAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );

    return Card(
      child: SizedBox(
        height: 320,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: current,
            initialZoom: 13,
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(routePoints),
              padding: const EdgeInsets.all(40),
              maxZoom: 15,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'travelbox.peru.app',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 4,
                  color: route?.fallbackUsed == true
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFF0B8B8C),
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: current,
                  width: 44,
                  height: 44,
                  child: const Icon(Icons.local_shipping, color: Colors.red),
                ),
                Marker(
                  point: destination,
                  width: 44,
                  height: 44,
                  child: const Icon(Icons.flag, color: Colors.blue),
                ),
              ],
            ),
            if (route != null)
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    route.fallbackUsed
                        ? 'Ruta simulada'
                        : 'Ruta vial ${route.provider.toUpperCase()}',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final tracking = _tracking!;
    final routeSummary = ref.watch(
      geoRouteProvider(_routeRequestForTracking(tracking)),
    );
    final route = routeSummary.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final etaNote = route == null
        ? 'ETA estimado por tracking logistico.'
        : route.fallbackUsed
        ? 'ETA estimado sin trafico en vivo.'
        : 'ETA estimado por ruta vial. No incluye trafico en tiempo real.';
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.route_outlined),
            title: Text('Estado: ${_statusLabel(tracking.status)}'),
            subtitle: Text(
              'ETA: ${tracking.etaMinutes} min\n$etaNote',
            ),
            trailing: IconButton(
              onPressed: _loadTracking,
              icon: const Icon(Icons.refresh),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(tracking.driverName),
            subtitle: Text(
              '${tracking.vehicleType} ${tracking.vehiclePlate}\n${tracking.driverPhone}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _reservationContextCard(
    BuildContext context,
    Reservation reservation,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reserva ${reservation.code}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${reservation.warehouse.name} - ${reservation.warehouse.city}',
            ),
            Text('Estado reserva: ${reservation.status.label}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/reservation/${reservation.id}'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(context.l10n.t('ver_reserva')),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go(_monitorRoute()),
                  icon: Icon(Icons.radar_outlined),
                  label: Text(context.l10n.t('volver_al_monitor')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventsCard() {
    final tracking = _tracking!;
    return Card(
      child: Column(
        children: tracking.events
            .map(
              (event) => ListTile(
                leading: CircleAvatar(child: Text('${event.sequence}')),
                title: Text(_statusLabel(event.status)),
                subtitle: Text(
                  '${event.message}\n${_formatDate(event.createdAt)}',
                ),
                trailing: Text('${event.etaMinutes} min'),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _loadTracking() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get<Map<String, dynamic>>(
        '/delivery-orders/reservation/${widget.reservationId}/tracking',
      );
      if (!mounted) return;
      setState(() {
        _tracking = DeliveryTrackingModel.fromJson(
          response.data ?? <String, dynamic>{},
        );
        _error = null;
        _deliveryMissing = false;
        _loading = false;
      });
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      if (statusCode == 404) {
        if (!mounted) return;
        setState(() {
          _tracking = null;
          _deliveryMissing = true;
          _loading = false;
          _error = null;
        });
        return;
      }
      if (!AppEnv.useMockFallback) {
        if (!mounted) return;
        setState(() {
          _error = 'No se pudo cargar tracking.';
          _loading = false;
          _deliveryMissing = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _mockTick = (_mockTick + 1).clamp(0, 3);
        _tracking = _mockTracking(_mockTick);
        _loading = false;
        _error = null;
        _deliveryMissing = false;
      });
    } catch (_) {
      if (!AppEnv.useMockFallback) {
        if (!mounted) return;
        setState(() {
          _error = 'No se pudo cargar tracking.';
          _loading = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _mockTick = (_mockTick + 1).clamp(0, 3);
        _tracking = _mockTracking(_mockTick);
        _loading = false;
        _error = null;
        _deliveryMissing = false;
      });
    }
  }

  DeliveryTrackingModel _mockTracking(int tick) {
    const origin = LatLng(-12.122, -77.031);
    const destination = LatLng(-12.11, -77.02);
    final curvedRoute = _buildCurvedMockRoute(origin, destination);
    final current = curvedRoute[_routeIndexForTick(tick, curvedRoute.length)];
    final statuses = ['REQUESTED', 'ASSIGNED', 'IN_TRANSIT', 'DELIVERED'];
    final status = statuses[tick];
    final events = List.generate(tick + 1, (index) {
      final point = curvedRoute[_routeIndexForTick(index, curvedRoute.length)];
      return DeliveryTrackingEventModel(
        sequence: index,
        status: statuses[index],
        latitude: point.latitude,
        longitude: point.longitude,
        etaMinutes: index == 3 ? 0 : 15 - (index * 5),
        message: 'Evento $index en modo mock.',
        createdAt: DateTime.now().subtract(Duration(minutes: 10 - (index * 2))),
      );
    });

    return DeliveryTrackingModel(
      deliveryOrderId: 'mock-order-${widget.reservationId}',
      reservationId: widget.reservationId,
      status: status,
      driverName: 'Unidad mock TravelBox',
      driverPhone: '+51999888777',
      vehicleType: 'MOTO',
      vehiclePlate: 'TBX-100',
      currentLatitude: current.latitude,
      currentLongitude: current.longitude,
      destinationLatitude: destination.latitude,
      destinationLongitude: destination.longitude,
      etaMinutes: tick == 3 ? 0 : 15 - (tick * 5),
      trackingMode: 'mock-local',
      reconnectSuggested: tick != 3,
      lastUpdatedAt: DateTime.now(),
      events: events,
    );
  }

  List<LatLng> _buildCurvedMockRoute(LatLng origin, LatLng destination) {
    final deltaLat = destination.latitude - origin.latitude;
    final deltaLng = destination.longitude - origin.longitude;
    final control = LatLng(
      ((origin.latitude + destination.latitude) / 2) + (-deltaLng * 0.22),
      ((origin.longitude + destination.longitude) / 2) + (deltaLat * 0.22),
    );
    return List.generate(11, (step) {
      final t = step / 10;
      final inverse = 1 - t;
      return LatLng(
        (inverse * inverse * origin.latitude) +
            (2 * inverse * t * control.latitude) +
            (t * t * destination.latitude),
        (inverse * inverse * origin.longitude) +
            (2 * inverse * t * control.longitude) +
            (t * t * destination.longitude),
      );
    });
  }

  int _routeIndexForTick(int tick, int totalPoints) {
    final progress = switch (tick) {
      0 => 0.15,
      1 => 0.45,
      2 => 0.78,
      _ => 1.0,
    };
    final lastIndex = totalPoints - 1;
    return (lastIndex * progress).round().clamp(0, lastIndex);
  }

  String _statusLabel(String raw) {
    switch (raw.toUpperCase()) {
      case 'REQUESTED':
        return 'Solicitado';
      case 'ASSIGNED':
        return 'Asignado';
      case 'IN_TRANSIT':
        return 'En transito';
      case 'DELIVERED':
        return 'Entregado';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return raw;
    }
  }

  String _formatDate(DateTime value) {
    return PeruTime.formatDateTime(value);
  }

  String _monitorRoute() {
    if (widget.currentRoute.startsWith('/admin')) {
      return '/admin/tracking';
    }
    if (widget.currentRoute.startsWith('/operator')) {
      return '/operator/tracking';
    }
    if (widget.currentRoute.startsWith('/courier')) {
      return '/courier/services';
    }
    return '/reservations';
  }

  GeoRouteRequest _routeRequestForTracking(DeliveryTrackingModel tracking) {
    final originEvent = tracking.events.isNotEmpty
        ? tracking.events.first
        : null;
    return GeoRouteRequest(
      originLat: originEvent?.latitude ?? tracking.currentLatitude,
      originLng: originEvent?.longitude ?? tracking.currentLongitude,
      destinationLat: tracking.destinationLatitude,
      destinationLng: tracking.destinationLongitude,
    );
  }

  List<LatLng> _resolveRoutePoints(
    AsyncValue<GeoRouteModel> routeAsync,
    DeliveryTrackingModel tracking,
    LatLng current,
    LatLng destination,
  ) {
    final providerPoints = routeAsync.maybeWhen(
      data: (route) => route.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList(),
      orElse: () => <LatLng>[],
    );
    if (providerPoints.length >= 2) {
      return providerPoints;
    }
    final eventPoints = tracking.events
        .map((event) => LatLng(event.latitude, event.longitude))
        .toList();
    if (eventPoints.isNotEmpty) {
      if (eventPoints.last.latitude != destination.latitude ||
          eventPoints.last.longitude != destination.longitude) {
        eventPoints.add(destination);
      }
      if (eventPoints.length >= 2) {
        return eventPoints;
      }
    }
    return [current, destination];
  }
}

class _MissingDeliveryState extends StatelessWidget {
  _MissingDeliveryState({
    required this.reservation,
    required this.onRefresh,
    required this.backofficeMode,
    required this.currentRoute,
  });

  final Reservation? reservation;
  final Future<void> Function() onRefresh;
  final bool backofficeMode;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final status = reservation?.status;
    final canRequestDelivery =
        status == ReservationStatus.stored ||
        status == ReservationStatus.readyForPickup;
    final canRequestPickup =
        status == ReservationStatus.confirmed ||
        status == ReservationStatus.checkinPending;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route_outlined, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    'Aun no hay tracking disponible',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canRequestDelivery || canRequestPickup
                        ? 'La reserva todavia no tiene una orden logistica creada. Puedes solicitar delivery o recojo segun el estado de la reserva.'
                        : 'Esta reserva no tiene una orden de delivery asociada o ya no requiere seguimiento en vivo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (canRequestPickup)
                        FilledButton(
                          onPressed: reservation == null
                              ? null
                              : () => context.go(
                                  '/delivery/${reservation!.id}?type=PICKUP',
                                ),
                          child: Text(context.l10n.t('solicitar_recojo')),
                        ),
                      if (canRequestDelivery)
                        FilledButton(
                          onPressed: reservation == null
                              ? null
                              : () =>
                                    context.go('/delivery/${reservation!.id}'),
                          child: Text(context.l10n.t('solicitar_delivery')),
                        ),
                      if (backofficeMode)
                        OutlinedButton.icon(
                          onPressed: () => context.go(
                            currentRoute.startsWith('/admin')
                                ? '/admin/tracking'
                                : currentRoute.startsWith('/operator')
                                ? '/operator/tracking'
                                : '/courier/services',
                          ),
                          icon: Icon(Icons.radar_outlined),
                          label: Text(context.l10n.t('volver_al_monitor')),
                        ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.go('/reservation/${reservation?.id ?? ''}'),
                        icon: Icon(Icons.receipt_long_outlined),
                        label: Text(context.l10n.t('ver_reserva')),
                      ),
                      OutlinedButton.icon(
                        onPressed: onRefresh,
                        icon: Icon(Icons.refresh),
                        label: Text(context.l10n.t('reintentar')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


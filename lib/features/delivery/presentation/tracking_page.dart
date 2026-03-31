import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as latlong_pkg;

import '../../../core/env/app_env.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../shared/models/delivery_tracking.dart';
import '../../../shared/models/geo_route.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/state/geo_route_provider.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../shared/utils/status_localizer.dart';
import '../../reservation/presentation/reservation_providers.dart';

class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({
    super.key,
    required this.reservationId,
    this.title = 'tracking',
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
  int _lastRealtimeCursor = -1;
  Timer? _pollTimer;

  /// Whether the delivery is still active and should be polled.
  bool get _shouldPoll {
    final status = _tracking?.status;
    return status != null &&
        status != 'DELIVERED' &&
        status != 'CANCELLED';
  }

  @override
  void initState() {
    super.initState();
    _loadTracking();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_shouldPoll && mounted) {
        _loadTracking();
      } else {
        _pollTimer?.cancel();
      }
    });
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
      title: context.l10n.t(widget.title),
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
            return Center(
              child: Text(context.l10n.t('tracking_no_disponible')),
            );
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
          child: Text(
            '${context.l10n.t('tracking_reservation_load_failed')}: $error',
          ),
        ),
      ),
    );
  }

  Widget _mapCard(BuildContext context) {
    final responsive = context.responsive;
    final tracking = _tracking!;
    final current = latlong_pkg.LatLng(tracking.currentLatitude, tracking.currentLongitude);
    final destination = latlong_pkg.LatLng(
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

    if (kIsWeb) {
      return _buildFlutterMapCard(context, responsive, current, destination, routePoints, route);
    }
    return _buildGoogleMapCard(context, responsive, current, destination, routePoints, route);
  }

  Widget _buildFlutterMapCard(
    BuildContext context,
    var responsive,
    latlong_pkg.LatLng current,
    latlong_pkg.LatLng destination,
    List<latlong_pkg.LatLng> routePoints,
    var route,
  ) {
    final markers = <flutter_map.Marker>[
      flutter_map.Marker(
        point: current,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      ),
      flutter_map.Marker(
        point: destination,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
      ),
    ];

    final polyline = routePoints.isNotEmpty
        ? flutter_map.Polyline(
            points: routePoints,
            color: route?.fallbackUsed == true
                ? const Color(0xFF3B82F6)
                : const Color(0xFF0B8B8C),
            strokeWidth: 4,
          )
        : null;

    return Card(
      child: SizedBox(
        height: responsive.mapHeight(max: 460),
        child: flutter_map.FlutterMap(
          options: flutter_map.MapOptions(
            initialCenter: current,
            initialZoom: 13,
          ),
          children: [
            flutter_map.TileLayer(
              urlTemplate: AppEnv.azureMapsApiKey.trim().isNotEmpty
                  ? 'https://atlas.microsoft.com/map/tile?api-version=2022-12-01&tilesetId=microsoft.basemaps&zoom={z}&x={x}&y={y}&subscription-key=${AppEnv.azureMapsApiKey}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.travelbox.peru.travelbox_peru_app',
            ),
            if (polyline != null) flutter_map.PolylineLayer(polylines: [polyline]),
            flutter_map.MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleMapCard(
    BuildContext context,
    var responsive,
    latlong_pkg.LatLng current,
    latlong_pkg.LatLng destination,
    List<latlong_pkg.LatLng> routePoints,
    var route,
  ) {
    final markers = <flutter_map.Marker>[
      flutter_map.Marker(
        point: current,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      ),
      flutter_map.Marker(
        point: destination,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
      ),
    ];

    final polyline = routePoints.isNotEmpty
        ? flutter_map.Polyline(
            points: routePoints,
            color: route?.fallbackUsed == true
                ? const Color(0xFF3B82F6)
                : const Color(0xFF0B8B8C),
            strokeWidth: 4,
          )
        : null;

    return Card(
      child: SizedBox(
        height: responsive.mapHeight(max: 460),
        child: flutter_map.FlutterMap(
          options: flutter_map.MapOptions(
            initialCenter: current,
            initialZoom: 13,
          ),
          children: [
            flutter_map.TileLayer(
              urlTemplate: AppEnv.azureMapsApiKey.trim().isNotEmpty
                  ? 'https://atlas.microsoft.com/map/tile?api-version=2022-12-01&tilesetId=microsoft.basemaps&zoom={z}&x={x}&y={y}&subscription-key=${AppEnv.azureMapsApiKey}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.travelbox.peru.travelbox_peru_app',
            ),
            if (polyline != null) flutter_map.PolylineLayer(polylines: [polyline]),
            flutter_map.MarkerLayer(markers: markers),
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
        ? context.l10n.t('tracking_eta_note_logistics')
        : route.fallbackUsed
        ? context.l10n.t('tracking_eta_note_no_live_traffic')
        : context.l10n.t('tracking_eta_note_provider_no_realtime');
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.route_outlined),
            title: Text(
              '${context.l10n.t('reservation_current_status')}: '
              '${deliveryStatusLabel(context, tracking.status)}',
            ),
            subtitle: Text(
              '${context.l10n.t('tracking_eta_prefix')}: '
              '${tracking.etaMinutes} ${context.l10n.t('min')}\n$etaNote',
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
              '${context.l10n.t('tracking_reservation_prefix')} ${reservation.code}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${reservation.warehouse.name} - ${reservation.warehouse.city}',
            ),
            Text(
              '${context.l10n.t('reservation_status')}: '
              '${reservation.status.localizedLabel(context)}',
            ),
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
                title: Text(deliveryStatusLabel(context, event.status)),
                subtitle: Text(
                  '${timelineMessageLabel(context, event.message)}\n'
                  '${_formatDate(event.createdAt)}',
                ),
                trailing: Text('${event.etaMinutes} ${context.l10n.t('min')}'),
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
      if (!_shouldPoll) {
        _pollTimer?.cancel();
      }
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
      if (!mounted) return;
      setState(() {
        _error = context.l10n.t('tracking_load_failed');
        _tracking = null;
        _deliveryMissing = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.t('tracking_load_failed');
        _tracking = null;
        _deliveryMissing = false;
        _loading = false;
      });
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

  List<latlong_pkg.LatLng> _resolveRoutePoints(
    AsyncValue<GeoRouteModel> routeAsync,
    DeliveryTrackingModel tracking,
    latlong_pkg.LatLng current,
    latlong_pkg.LatLng destination,
  ) {
    final providerPoints = routeAsync.maybeWhen(
      data: (route) => route.points
          .map((point) => latlong_pkg.LatLng(point.latitude, point.longitude))
          .toList(),
      orElse: () => <latlong_pkg.LatLng>[],
    );
    if (providerPoints.length >= 2) {
      return providerPoints;
    }
    final eventPoints = tracking.events
        .map((event) => latlong_pkg.LatLng(event.latitude, event.longitude))
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
  const _MissingDeliveryState({
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
                    context.l10n.t('tracking_missing_title'),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canRequestDelivery || canRequestPickup
                        ? context.l10n.t('tracking_missing_can_request')
                        : context.l10n.t('tracking_missing_not_required'),
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

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/delivery_tracking.dart';
import '../../../shared/models/geo_route.dart';
import '../../../shared/state/geo_route_provider.dart';
import '../../../shared/utils/peru_time.dart';
import '../../reservation/presentation/reservation_providers.dart';

final deliveryMonitorSearchProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final deliveryMonitorActiveOnlyProvider = StateProvider.autoDispose<bool>(
  (ref) => true,
);

final deliveryMonitorProvider =
    FutureProvider.autoDispose<List<DeliveryMonitorItem>>((ref) async {
      ref.watch(reservationRealtimeEventCursorProvider);
      final dio = ref.read(dioProvider);
      final query = ref.watch(deliveryMonitorSearchProvider).trim();
      final activeOnly = ref.watch(deliveryMonitorActiveOnlyProvider);
      final response = await dio.get<List<dynamic>>(
        '/delivery-orders',
        queryParameters: {
          'activeOnly': activeOnly,
          if (query.isNotEmpty) 'query': query,
        },
      );
      return (response.data ?? const [])
          .map(
            (item) =>
                DeliveryMonitorItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    });

final deliveryMonitorTrackingProvider = FutureProvider.autoDispose
    .family<DeliveryTrackingModel?, String>((ref, reservationId) async {
      ref.watch(reservationRealtimeEventCursorProvider);
      final dio = ref.read(dioProvider);
      try {
        final response = await dio.get<Map<String, dynamic>>(
          '/delivery-orders/reservation/$reservationId/tracking',
        );
        return DeliveryTrackingModel.fromJson(
          response.data ?? <String, dynamic>{},
        );
      } on DioException catch (error) {
        if (error.response?.statusCode == 404) {
          return null;
        }
        rethrow;
      }
    });

class DeliveryMonitorPage extends ConsumerStatefulWidget {
  DeliveryMonitorPage({
    super.key,
    required this.title,
    required this.currentRoute,
  });

  final String title;
  final String currentRoute;

  @override
  ConsumerState<DeliveryMonitorPage> createState() =>
      _DeliveryMonitorPageState();
}

class _DeliveryMonitorPageState extends ConsumerState<DeliveryMonitorPage> {
  final _searchController = TextEditingController();
  String? _selectedReservationId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deliveriesAsync = ref.watch(deliveryMonitorProvider);
    final activeOnly = ref.watch(deliveryMonitorActiveOnlyProvider);

    return AppShellScaffold(
      title: widget.title,
      currentRoute: widget.currentRoute,
      actions: [
        IconButton(
          tooltip: 'Recargar',
          onPressed: () => ref.invalidate(deliveryMonitorProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: deliveriesAsync.when(
        data: (items) => _buildContent(context, items, activeOnly),
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message:
              'No se pudo cargar monitoreo logistico: ${_errorMessage(error)}',
          onRetry: () => ref.invalidate(deliveryMonitorProvider),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<DeliveryMonitorItem> items,
    bool activeOnly,
  ) {
    final responsive = context.responsive;
    final selected = _resolveSelection(items);
    final width = MediaQuery.of(context).size.width;
    final searchFieldWidth = (width - 72).clamp(220.0, 360.0).toDouble();
    final list = _buildList(context, items, selected);
    final detail = _buildDetail(context, selected, items.length, activeOnly);

    final content = width >= 1180
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 420, child: SingleChildScrollView(child: list)),
                const SizedBox(width: 16),
                Expanded(child: SingleChildScrollView(child: detail)),
              ],
            ),
          )
        : ListView(
            padding: responsive.pageInsets(
              top: responsive.verticalPadding,
              bottom: 24,
            ),
            children: [list, const SizedBox(height: 16), detail],
          );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF173B56), Color(0xFF0B8B8C)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitoreo logistico en vivo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Actualizacion automatica por eventos. Selecciona una orden para ver mapa, ruta y eventos dentro del mismo panel.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.92)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: searchFieldWidth,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          ref
                                  .read(deliveryMonitorSearchProvider.notifier)
                                  .state =
                              value;
                        },
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.search),
                          hintText:
                              'Buscar por reserva, cliente, ciudad o chofer',
                        ),
                      ),
                    ),
                    FilterChip(
                      selected: activeOnly,
                      label: Text(context.l10n.t('solo_activas')),
                      onSelected: (_) {
                        ref
                                .read(
                                  deliveryMonitorActiveOnlyProvider.notifier,
                                )
                                .state =
                            true;
                      },
                    ),
                    FilterChip(
                      selected: !activeOnly,
                      label: Text(context.l10n.t('recientes')),
                      onSelected: (_) {
                        ref
                                .read(
                                  deliveryMonitorActiveOnlyProvider.notifier,
                                )
                                .state =
                            false;
                      },
                    ),
                    Chip(
                      label: Text('${items.length} ordenes'),
                      backgroundColor: Colors.white.withValues(alpha: 0.92),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  DeliveryMonitorItem? _resolveSelection(List<DeliveryMonitorItem> items) {
    if (items.isEmpty) {
      _selectedReservationId = null;
      return null;
    }
    final selected = items.where(
      (item) => item.reservationId == _selectedReservationId,
    );
    if (selected.isNotEmpty) {
      return selected.first;
    }
    _selectedReservationId = items.first.reservationId;
    return items.first;
  }

  Widget _buildList(
    BuildContext context,
    List<DeliveryMonitorItem> items,
    DeliveryMonitorItem? selected,
  ) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: EmptyStateView(
            message: 'No hay ordenes de delivery para el filtro actual.',
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: items
            .map(
              (item) => InkWell(
                onTap: () =>
                    setState(() => _selectedReservationId = item.reservationId),
                child: Container(
                  decoration: BoxDecoration(
                    color: item.reservationId == selected?.reservationId
                        ? const Color(0xFFEDF7FA)
                        : Colors.transparent,
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
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
                            item.warehouseName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Chip(
                            label: Text(item.deliveryStatusLabel),
                            backgroundColor: item.statusColor.withValues(
                              alpha: 0.12,
                            ),
                            side: BorderSide(color: item.statusColor),
                            labelStyle: TextStyle(color: item.statusColor),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${item.customerName} - ${item.customerEmail}'),
                      Text(
                        '${item.cityName} | ETA ${item.etaLabel} | Reserva ${item.reservationCode}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    DeliveryMonitorItem? item,
    int totalCount,
    bool activeOnly,
  ) {
    if (item == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyStateView(
            message: activeOnly
                ? 'No hay deliveries activos para monitorear ahora.'
                : 'No hay deliveries recientes disponibles.',
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Reserva ${item.reservationCode}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Chip(
                  label: Text(item.deliveryStatusLabel),
                  backgroundColor: item.statusColor.withValues(alpha: 0.12),
                  side: BorderSide(color: item.statusColor),
                  labelStyle: TextStyle(color: item.statusColor),
                ),
                Chip(
                  label: Text('ETA ${item.etaLabel}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Panel monitoreando $totalCount ordenes ${activeOnly ? 'activas' : 'recientes'}.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InfoBlock(title: 'Almacen', value: item.warehouseName),
                _InfoBlock(title: 'Ciudad', value: item.cityName),
                _InfoBlock(title: 'Cliente', value: item.customerName),
                _InfoBlock(title: 'Correo', value: item.customerEmail),
                _InfoBlock(title: 'Direccion', value: item.address),
                _InfoBlock(title: 'Zona', value: item.zone),
                _InfoBlock(title: 'Chofer', value: item.driverName),
                _InfoBlock(title: 'Telefono', value: item.driverPhone),
                _InfoBlock(
                  title: 'Unidad',
                  value: '${item.vehicleType} ${item.vehiclePlate}',
                ),
                _InfoBlock(
                  title: 'Reserva',
                  value: item.reservationStatusLabel,
                ),
                _InfoBlock(
                  title: 'Actualizado',
                  value: _formatDate(item.updatedAt),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _EmbeddedTrackingSection(reservationId: item.reservationId),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => context.go(
                    '${widget.currentRoute}/${item.reservationId}',
                  ),
                  icon: const Icon(Icons.route_outlined),
                  label: Text(context.l10n.t('pantalla_completa')),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/reservation/${item.reservationId}'),
                  icon: Icon(Icons.receipt_long_outlined),
                  label: Text(context.l10n.t('ver_reserva')),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go(
                    widget.currentRoute.startsWith('/operator')
                        ? '/operator/incidents'
                        : '/admin/incidents',
                  ),
                  icon: Icon(Icons.support_agent_outlined),
                  label: Text(context.l10n.t('ir_a_soporte')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    return PeruTime.formatDateTime(value);
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!.trim();
      }
    }
    return error.toString();
  }
}

class _EmbeddedTrackingSection extends ConsumerWidget {
  _EmbeddedTrackingSection({required this.reservationId});

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingAsync = ref.watch(
      deliveryMonitorTrackingProvider(reservationId),
    );

    return trackingAsync.when(
      data: (tracking) {
        if (tracking == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ListTile(
                leading: const Icon(Icons.route_outlined),
                title: Text(context.l10n.t('no_hay_tracking_disponible')),
                subtitle: const Text(
                  'La reserva todavia no tiene una orden de delivery asociada.',
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tracking embebido',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 10),
            _EmbeddedTrackingMap(tracking: tracking),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: tracking.events.reversed
                    .map(
                      (event) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFDBEEF3),
                          child: Text('${event.sequence}'),
                        ),
                        title: Text(_statusLabel(event.status)),
                        subtitle: Text(
                          '${event.message}\n${_formatDate(event.createdAt)}',
                        ),
                        trailing: Text('${event.etaMinutes} min'),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: LoadingStateView(message: 'Cargando tracking embebido...'),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ListTile(
            leading: const Icon(Icons.warning_amber_outlined),
            title: Text(
              context.l10n.t('no_se_pudo_cargar_el_tracking_embebido'),
            ),
            subtitle: Text(error.toString()),
            trailing: OutlinedButton(
              onPressed: () => ref.invalidate(
                deliveryMonitorTrackingProvider(reservationId),
              ),
              child: Text(context.l10n.t('reintentar')),
            ),
          ),
        ),
      ),
    );
  }

  static String _statusLabel(String raw) {
    switch (raw.toUpperCase()) {
      case 'REQUESTED':
        return 'Solicitado';
      case 'ASSIGNED':
        return 'Asignado';
      case 'IN_TRANSIT':
        return 'En tránsito';
      case 'DELIVERED':
        return 'Entregado';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return raw;
    }
  }

  static String _formatDate(DateTime value) {
    return PeruTime.formatDateTime(value);
  }
}

class _EmbeddedTrackingMap extends ConsumerWidget {
  const _EmbeddedTrackingMap({required this.tracking});

  final DeliveryTrackingModel tracking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = context.responsive;
    final current = LatLng(tracking.currentLatitude, tracking.currentLongitude);
    final destination = LatLng(
      tracking.destinationLatitude,
      tracking.destinationLongitude,
    );
    final routeAsync = ref.watch(
      geoRouteProvider(_routeRequestForTracking(tracking)),
    );
    final route = routeAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final routePoints = _resolveRoutePoints(
      routeAsync,
      tracking,
      current,
      destination,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        height: responsive.mapHeight(max: 440),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: current,
            initialZoom: 13,
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(routePoints),
              padding: const EdgeInsets.all(36),
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

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value),
        ],
      ),
    );
  }
}

class DeliveryMonitorItem {
  const DeliveryMonitorItem({
    required this.deliveryOrderId,
    required this.reservationId,
    required this.reservationCode,
    required this.reservationStatus,
    required this.deliveryStatus,
    required this.warehouseName,
    required this.cityName,
    required this.customerName,
    required this.customerEmail,
    required this.address,
    required this.zone,
    required this.driverName,
    required this.driverPhone,
    required this.vehicleType,
    required this.vehiclePlate,
    required this.etaMinutes,
    required this.updatedAt,
  });

  final String deliveryOrderId;
  final String reservationId;
  final String reservationCode;
  final String reservationStatus;
  final String deliveryStatus;
  final String warehouseName;
  final String cityName;
  final String customerName;
  final String customerEmail;
  final String address;
  final String zone;
  final String driverName;
  final String driverPhone;
  final String vehicleType;
  final String vehiclePlate;
  final int etaMinutes;
  final DateTime updatedAt;

  String get etaLabel => etaMinutes <= 0 ? '0 min' : '$etaMinutes min';

  String get reservationStatusLabel {
    switch (reservationStatus.toUpperCase()) {
      case 'PENDING_PAYMENT':
        return 'Pendiente pago';
      case 'CONFIRMED':
        return 'Confirmada';
      case 'CHECKIN_PENDING':
        return 'Check-in pendiente';
      case 'STORED':
        return 'Almacenada';
      case 'OUT_FOR_DELIVERY':
        return 'En delivery';
      case 'READY_FOR_PICKUP':
        return 'Lista para recojo';
      case 'COMPLETED':
        return 'Completada';
      case 'CANCELLED':
        return 'Cancelada';
      case 'INCIDENT':
        return 'Incidencia';
      default:
        return reservationStatus;
    }
  }

  String get deliveryStatusLabel {
    switch (deliveryStatus.toUpperCase()) {
      case 'REQUESTED':
        return 'Solicitado';
      case 'ASSIGNED':
        return 'Asignado';
      case 'IN_TRANSIT':
        return 'En tránsito';
      case 'DELIVERED':
        return 'Entregado';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return deliveryStatus;
    }
  }

  Color get statusColor {
    switch (deliveryStatus.toUpperCase()) {
      case 'ASSIGNED':
        return const Color(0xFF1D4ED8);
      case 'IN_TRANSIT':
        return const Color(0xFF0B8B8C);
      case 'DELIVERED':
        return const Color(0xFF168F64);
      case 'CANCELLED':
        return const Color(0xFFC43D3D);
      default:
        return const Color(0xFFF29F05);
    }
  }

  factory DeliveryMonitorItem.fromJson(Map<String, dynamic> json) {
    return DeliveryMonitorItem(
      deliveryOrderId: json['deliveryOrderId']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      reservationCode: json['reservationCode']?.toString() ?? '-',
      reservationStatus: json['reservationStatus']?.toString() ?? '-',
      deliveryStatus: json['deliveryStatus']?.toString() ?? '-',
      warehouseName: json['warehouseName']?.toString() ?? 'Sin almacen',
      cityName: json['cityName']?.toString() ?? '-',
      customerName: json['customerName']?.toString() ?? 'Cliente',
      customerEmail: json['customerEmail']?.toString() ?? '-',
      address: json['address']?.toString() ?? '-',
      zone: json['zone']?.toString() ?? '-',
      driverName: json['driverName']?.toString() ?? 'Sin asignar',
      driverPhone: json['driverPhone']?.toString() ?? '-',
      vehicleType: json['vehicleType']?.toString() ?? '-',
      vehiclePlate: json['vehiclePlate']?.toString() ?? '-',
      etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

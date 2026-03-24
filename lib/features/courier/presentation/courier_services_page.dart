import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong_pkg;

import '../../../core/layout/responsive_layout.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/state/geo_route_provider.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/status_localizer.dart';
import '../../reservation/presentation/reservation_providers.dart';

class CourierServicesPage extends ConsumerStatefulWidget {
  const CourierServicesPage({super.key});

  @override
  ConsumerState<CourierServicesPage> createState() =>
      _CourierServicesPageState();
}

class _CourierServicesPageState extends ConsumerState<CourierServicesPage> {
  final _searchController = TextEditingController();
  bool _loading = true;
  bool _activeOnly = true;
  String _query = '';
  String? _error;
  String? _busyOrderId;
  List<CourierDeliveryItem> _availableItems = const [];
  List<CourierDeliveryItem> _myItems = const [];
  int _lastRealtimeCursor = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final realtimeCursor = ref.watch(reservationRealtimeEventCursorProvider);
    if (_lastRealtimeCursor != realtimeCursor) {
      final shouldReload = _lastRealtimeCursor >= 0;
      _lastRealtimeCursor = realtimeCursor;
      if (shouldReload) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _loadData();
        });
      }
    }
    return AppShellScaffold(
      title: context.l10n.t('courier_services_title'),
      currentRoute: '/courier/services',
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _query = value.trim());
                      _loadData();
                    },
                    decoration: InputDecoration(
                      labelText: context.l10n.t(
                        'courier_services_search_label',
                      ),
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (responsive.width < 920)
                    Column(
                      children: [
                        TabBar(
                          tabs: [
                            Tab(
                              text: context.l10n.t(
                                'courier_services_tab_available',
                              ),
                            ),
                            Tab(
                              text: context.l10n.t('courier_services_tab_mine'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              selected: _activeOnly,
                              label: Text(context.l10n.t('solo_activos')),
                              onSelected: (value) {
                                setState(() => _activeOnly = value);
                                _loadData();
                              },
                            ),
                            OutlinedButton.icon(
                              onPressed: _loadData,
                              icon: const Icon(Icons.refresh),
                              label: Text(context.l10n.t('recargar')),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => context.go('/ops/qr-handoff'),
                              icon: const Icon(Icons.qr_code_scanner_outlined),
                              label: Text(context.l10n.t('qrpin')),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TabBar(
                            tabs: [
                              Tab(
                                text: context.l10n.t(
                                  'courier_services_tab_available',
                                ),
                              ),
                              Tab(
                                text: context.l10n.t(
                                  'courier_services_tab_mine',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilterChip(
                          selected: _activeOnly,
                          label: Text(context.l10n.t('solo_activos')),
                          onSelected: (value) {
                            setState(() => _activeOnly = value);
                            _loadData();
                          },
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: Text(context.l10n.t('recargar')),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => context.go('/ops/qr-handoff'),
                          icon: const Icon(Icons.qr_code_scanner_outlined),
                          label: Text(context.l10n.t('qrpin')),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const LoadingStateView()
                  : _error != null
                  ? ErrorStateView(message: _error!, onRetry: _loadData)
                  : TabBarView(
                      children: [
                        _buildList(
                          context,
                          items: _availableItems,
                          emptyMessage: context.l10n.t(
                            'courier_services_empty_available',
                          ),
                          showClaimAction: true,
                        ),
                        _buildList(
                          context,
                          items: _myItems,
                          emptyMessage: context.l10n.t(
                            'courier_services_empty_mine',
                          ),
                          showClaimAction: false,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context, {
    required List<CourierDeliveryItem> items,
    required String emptyMessage,
    required bool showClaimAction,
  }) {
    if (items.isEmpty) {
      return EmptyStateView(message: emptyMessage);
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          final busy = _busyOrderId == item.deliveryOrderId;
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
                        item.reservationCode,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Chip(
                        label: Text(
                          deliveryStatusLabel(context, item.deliveryStatus),
                        ),
                        side: BorderSide(color: item.statusColor),
                      ),
                      if (busy)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.customerName} - ${item.cityName}\n${item.warehouseName}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${context.l10n.t('courier_services_service_prefix')}: '
                    '${_deliveryTypeLabel(context, item.deliveryType)}',
                  ),
                  Text(
                    item.deliveryType.toUpperCase() == 'PICKUP'
                        ? '${context.l10n.t('courier_services_pickup_point_prefix')}: '
                              '${item.address}'
                        : '${context.l10n.t('courier_services_destination_prefix')}: '
                              '${item.address}',
                  ),
                  Text(
                    '${context.l10n.t('courier_services_eta_prefix')}: '
                    '${item.etaMinutes} ${context.l10n.t('min')}',
                  ),
                  if (!showClaimAction)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${context.l10n.t('courier_services_vehicle_prefix')}: '
                        '${item.vehicleType} ${item.vehiclePlate}',
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (showClaimAction)
                        FilledButton.icon(
                          onPressed: busy ? null : () => _claimOrder(item),
                          icon: const Icon(Icons.assignment_turned_in_outlined),
                          label: Text(context.l10n.t('tomar_servicio')),
                        ),
                      if (!showClaimAction && item.canAdvanceToInTransit)
                        FilledButton.tonalIcon(
                          onPressed: busy
                              ? null
                              : () => _updateProgress(
                                  item,
                                  defaultStatus: 'IN_TRANSIT',
                                ),
                          icon: Icon(Icons.local_shipping_outlined),
                          label: Text(context.l10n.t('salir_a_ruta')),
                        ),
                      if (!showClaimAction && item.canComplete)
                        FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => _updateProgress(
                                  item,
                                  defaultStatus: 'DELIVERED',
                                ),
                          icon: Icon(Icons.check_circle_outline),
                          label: Text(
                            item.deliveryType.toUpperCase() == 'PICKUP'
                                ? context.l10n.t('courier_confirm_pickup')
                                : context.l10n.t('courier_confirm_delivery'),
                          ),
                        ),
                      if (!showClaimAction && item.canOperate)
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => _updateProgress(
                                  item,
                                  defaultStatus: item.deliveryStatus,
                                ),
                          icon: const Icon(Icons.edit_location_alt_outlined),
                          label: Text(context.l10n.t('actualizar_tracking')),
                        ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => context.go(
                                '/courier/tracking/${item.reservationId}',
                              ),
                        icon: Icon(Icons.route_outlined),
                        label: Text(context.l10n.t('ver_tracking')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      final dio = ref.read(dioProvider);
      final responses = await Future.wait([
        dio.get<List<dynamic>>(
          '/delivery-orders',
          queryParameters: {
            'activeOnly': _activeOnly,
            'query': _query,
            'scope': 'available',
          },
        ),
        dio.get<List<dynamic>>(
          '/delivery-orders',
          queryParameters: {
            'activeOnly': _activeOnly,
            'query': _query,
            'scope': 'mine',
          },
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _availableItems = (responses[0].data ?? const [])
            .map(
              (item) =>
                  CourierDeliveryItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        _myItems = (responses[1].data ?? const [])
            .map(
              (item) =>
                  CourierDeliveryItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            '${context.l10n.t('courier_services_load_failed_prefix')}: '
            '${AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key))}';
      });
    }
  }

  Future<void> _claimOrder(CourierDeliveryItem item) async {
    final claim = await showDialog<_CourierClaimPayload>(
      context: context,
      builder: (context) => _CourierClaimDialog(),
    );
    if (claim == null) return;
    await _runBusy(item.deliveryOrderId, () async {
      await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>(
            '/delivery-orders/${item.deliveryOrderId}/claim',
            data: claim.toJson(),
          );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('courier_services_claim_success_prefix')} '
            '${item.reservationCode}.',
          ),
        ),
      );
    });
  }

  Future<void> _updateProgress(
    CourierDeliveryItem item, {
    required String defaultStatus,
  }) async {
    final payload = await showDialog<_CourierProgressPayload>(
      context: context,
      builder: (context) =>
          _CourierProgressDialog(item: item, defaultStatus: defaultStatus),
    );
    if (payload == null) return;
    await _runBusy(item.deliveryOrderId, () async {
      await ref
          .read(dioProvider)
          .patch<Map<String, dynamic>>(
            '/delivery-orders/${item.deliveryOrderId}/progress',
            data: payload.toJson(),
          );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('courier_services_tracking_updated_prefix')} '
            '${item.reservationCode}.',
          ),
        ),
      );
    });
  }

  Future<void> _runBusy(String orderId, Future<void> Function() action) async {
    setState(() => _busyOrderId = orderId);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key)))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyOrderId = null);
      }
    }
  }

  String _deliveryTypeLabel(BuildContext context, String rawType) {
    switch (rawType.trim().toUpperCase()) {
      case 'PICKUP':
        return context.l10n.t('request_pickup');
      case 'DELIVERY':
        return context.l10n.t('request_delivery');
      default:
        return rawType;
    }
  }
}

class CourierDeliveryItem {
  const CourierDeliveryItem({
    required this.deliveryOrderId,
    required this.reservationId,
    required this.reservationCode,
    required this.deliveryType,
    required this.deliveryStatus,
    required this.warehouseName,
    required this.cityName,
    required this.customerName,
    required this.address,
    required this.vehicleType,
    required this.vehiclePlate,
    required this.etaMinutes,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });

  final String deliveryOrderId;
  final String reservationId;
  final String reservationCode;
  final String deliveryType;
  final String deliveryStatus;
  final String warehouseName;
  final String cityName;
  final String customerName;
  final String address;
  final String vehicleType;
  final String vehiclePlate;
  final int etaMinutes;
  final double currentLatitude;
  final double currentLongitude;
  final double destinationLatitude;
  final double destinationLongitude;

  bool get canAdvanceToInTransit =>
      deliveryStatus.toUpperCase() == 'ASSIGNED' ||
      deliveryStatus.toUpperCase() == 'REQUESTED';

  bool get canComplete => deliveryStatus.toUpperCase() == 'IN_TRANSIT';

  bool get canOperate =>
      deliveryStatus.toUpperCase() != 'DELIVERED' &&
      deliveryStatus.toUpperCase() != 'CANCELLED';

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

  String get deliveryTypeLabel {
    switch (deliveryType.toUpperCase()) {
      case 'PICKUP':
        return 'Recojo';
      case 'DELIVERY':
        return 'Entrega';
      default:
        return deliveryType;
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

  factory CourierDeliveryItem.fromJson(Map<String, dynamic> json) {
    return CourierDeliveryItem(
      deliveryOrderId: json['deliveryOrderId']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      reservationCode: json['reservationCode']?.toString() ?? '-',
      deliveryType: json['deliveryType']?.toString() ?? 'DELIVERY',
      deliveryStatus: json['deliveryStatus']?.toString() ?? 'REQUESTED',
      warehouseName: json['warehouseName']?.toString() ?? 'Warehouse',
      cityName: json['cityName']?.toString() ?? '-',
      customerName: json['customerName']?.toString() ?? 'Customer',
      address: json['address']?.toString() ?? '-',
      vehicleType: json['vehicleType']?.toString() ?? '-',
      vehiclePlate: json['vehiclePlate']?.toString() ?? '-',
      etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
      currentLatitude: (json['currentLatitude'] as num?)?.toDouble() ?? 0,
      currentLongitude: (json['currentLongitude'] as num?)?.toDouble() ?? 0,
      destinationLatitude:
          (json['destinationLatitude'] as num?)?.toDouble() ?? 0,
      destinationLongitude:
          (json['destinationLongitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _CourierClaimPayload {
  const _CourierClaimPayload({
    required this.vehicleType,
    required this.vehiclePlate,
  });

  final String vehicleType;
  final String vehiclePlate;

  Map<String, dynamic> toJson() {
    return {'vehicleType': vehicleType, 'vehiclePlate': vehiclePlate};
  }
}

class _CourierClaimDialog extends StatefulWidget {
  const _CourierClaimDialog();

  @override
  State<_CourierClaimDialog> createState() => _CourierClaimDialogState();
}

class _CourierClaimDialogState extends State<_CourierClaimDialog> {
  final _vehicleTypeController = TextEditingController(text: 'MOTO');
  final _vehiclePlateController = TextEditingController(text: 'TBX-001');

  @override
  void dispose() {
    _vehicleTypeController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.t('tomar_servicio')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _vehicleTypeController,
            decoration: InputDecoration(
              labelText: context.l10n.t('courier_services_vehicle_type_label'),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _vehiclePlateController,
            decoration: InputDecoration(
              labelText: context.l10n.t('courier_services_plate_or_code_label'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.t('cancelar')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _CourierClaimPayload(
              vehicleType: _vehicleTypeController.text.trim(),
              vehiclePlate: _vehiclePlateController.text.trim(),
            ),
          ),
          child: Text(context.l10n.t('aceptar_servicio')),
        ),
      ],
    );
  }
}

class _CourierProgressPayload {
  _CourierProgressPayload({
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.etaMinutes,
    required this.message,
    required this.vehicleType,
    required this.vehiclePlate,
  });

  final String status;
  final double? latitude;
  final double? longitude;
  final int? etaMinutes;
  final String message;
  final String vehicleType;
  final String vehiclePlate;

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'etaMinutes': etaMinutes,
      'message': message,
      'vehicleType': vehicleType,
      'vehiclePlate': vehiclePlate,
    };
  }
}

class _CourierProgressDialog extends ConsumerStatefulWidget {
  const _CourierProgressDialog({
    required this.item,
    required this.defaultStatus,
  });

  final CourierDeliveryItem item;
  final String defaultStatus;

  @override
  ConsumerState<_CourierProgressDialog> createState() =>
      _CourierProgressDialogState();
}

class _CourierProgressDialogState
    extends ConsumerState<_CourierProgressDialog> {
  late String _status;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _etaController;
  late final TextEditingController _messageController;
  late final TextEditingController _vehicleTypeController;
  late final TextEditingController _vehiclePlateController;
  bool _gettingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _status = widget.defaultStatus.toUpperCase();
    _latitudeController = TextEditingController(
      text: widget.item.currentLatitude.toStringAsFixed(6),
    );
    _longitudeController = TextEditingController(
      text: widget.item.currentLongitude.toStringAsFixed(6),
    );
    _etaController = TextEditingController(text: '${widget.item.etaMinutes}');
    _messageController = TextEditingController();
    _vehicleTypeController = TextEditingController(
      text: widget.item.vehicleType == '-' ? 'MOTO' : widget.item.vehicleType,
    );
    _vehiclePlateController = TextEditingController(
      text: widget.item.vehiclePlate == '-' ? '' : widget.item.vehiclePlate,
    );
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _etaController.dispose();
    _messageController.dispose();
    _vehicleTypeController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _statusOptions(widget.item.deliveryStatus);
    final media = MediaQuery.of(context);
    final maxDialogWidth = media.size.width >= 860
        ? 520.0
        : media.size.width * 0.94;
    final maxDialogHeight = media.size.height * 0.78;
    final routeAsync = ref.watch(
      geoRouteProvider(
        GeoRouteRequest(
          originLat: widget.item.currentLatitude,
          originLng: widget.item.currentLongitude,
          destinationLat: widget.item.destinationLatitude,
          destinationLng: widget.item.destinationLongitude,
        ),
      ),
    );
    final route = routeAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final routePoints = routeAsync.maybeWhen(
      data: (value) => value.points
          .map((point) => latlong_pkg.LatLng(point.latitude, point.longitude))
          .toList(),
      orElse: () => <latlong_pkg.LatLng>[
        latlong_pkg.LatLng(widget.item.currentLatitude, widget.item.currentLongitude),
        latlong_pkg.LatLng(
          widget.item.destinationLatitude,
          widget.item.destinationLongitude,
        ),
      ],
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      title: Text(context.l10n.t('actualizar_tracking')),
      content: SizedBox(
        width: maxDialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDialogHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 220,
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: kIsWeb
                        ? _buildFlutterMap(widget.item, routePoints, route)
                        : _buildGoogleMap(widget.item, routePoints, route),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    route == null
                        ? context.l10n.t('courier_services_loading_route')
                        : '${context.l10n.t('courier_services_route_prefix')} '
                              '${route.fallbackUsed ? context.l10n.t('courier_services_route_simulated') : route.provider.toUpperCase()} '
                              '- '
                              '${(route.distanceMeters / 1000).toStringAsFixed(1)} km',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: statuses.contains(_status)
                      ? _status
                      : statuses.first,
                  decoration: InputDecoration(
                    labelText: context.l10n.t('courier_services_status_new'),
                  ),
                  items: statuses
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.t(
                            'courier_services_latitude',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _longitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.t(
                            'courier_services_longitude',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _gettingLocation
                            ? null
                            : _useBrowserLocation,
                        icon: const Icon(Icons.my_location_outlined),
                        label: Text(
                          _gettingLocation
                              ? context.l10n.t('courier_services_reading_gps')
                              : context.l10n.t('courier_services_use_my_gps'),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          _latitudeController.text = widget.item.currentLatitude
                              .toStringAsFixed(6);
                          _longitudeController.text = widget
                              .item
                              .currentLongitude
                              .toStringAsFixed(6);
                        },
                        icon: const Icon(Icons.restart_alt_outlined),
                        label: Text(context.l10n.t('usar_ultimo_punto')),
                      ),
                    ],
                  ),
                ),
                if (_locationError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _locationError!,
                      style: TextStyle(color: Color(0xFFC43D3D)),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _etaController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.t(
                      'courier_services_eta_minutes_label',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _vehicleTypeController,
                  decoration: InputDecoration(
                    labelText: context.l10n.t(
                      'courier_services_vehicle_type_label',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _vehiclePlateController,
                  decoration: InputDecoration(
                    labelText: context.l10n.t(
                      'courier_services_plate_or_code_label',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.l10n.t(
                      'courier_services_operational_message_label',
                    ),
                    hintText: context.l10n.t(
                      'courier_services_operational_message_hint',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.t('cancelar')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _CourierProgressPayload(
              status: _status,
              latitude: double.tryParse(
                _latitudeController.text.trim().replaceAll(',', '.'),
              ),
              longitude: double.tryParse(
                _longitudeController.text.trim().replaceAll(',', '.'),
              ),
              etaMinutes: int.tryParse(_etaController.text.trim()),
              message: _messageController.text.trim(),
              vehicleType: _vehicleTypeController.text.trim(),
              vehiclePlate: _vehiclePlateController.text.trim(),
            ),
          ),
          child: Text(context.l10n.t('guardar_avance')),
        ),
      ],
    );
  }

  List<String> _statusOptions(String currentStatus) {
    switch (currentStatus.toUpperCase()) {
      case 'REQUESTED':
        return const ['ASSIGNED', 'CANCELLED'];
      case 'ASSIGNED':
        return const ['ASSIGNED', 'IN_TRANSIT', 'CANCELLED'];
      case 'IN_TRANSIT':
        return const ['IN_TRANSIT', 'DELIVERED', 'CANCELLED'];
      default:
        return [currentStatus.toUpperCase()];
    }
  }

  Future<void> _useBrowserLocation() async {
    setState(() {
      _gettingLocation = true;
      _locationError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = context.l10n.t(
            'courier_services_location_permission_denied',
          );
          _gettingLocation = false;
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        _gettingLocation = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locationError = AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key));
        _gettingLocation = false;
      });
    }
  }

  Widget _buildFlutterMap(CourierDeliveryItem item, List<latlong_pkg.LatLng> routePoints, var route) {
    final current = latlong_pkg.LatLng(item.currentLatitude, item.currentLongitude);
    final destination = latlong_pkg.LatLng(item.destinationLatitude, item.destinationLongitude);

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
        child: Icon(
          Icons.location_on,
          color: item.deliveryType.toUpperCase() == 'PICKUP' ? Colors.cyan : Colors.blue,
          size: 40,
        ),
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

    return flutter_map.FlutterMap(
      options: flutter_map.MapOptions(
        initialCenter: current,
        initialZoom: 13,
      ),
      children: [
        flutter_map.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.travelbox.peru.app',
        ),
        if (polyline != null) flutter_map.PolylineLayer(polylines: [polyline]),
        flutter_map.MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildGoogleMap(CourierDeliveryItem item, List<latlong_pkg.LatLng> routePoints, var route) {
    final current = latlong_pkg.LatLng(item.currentLatitude, item.currentLongitude);
    final destination = latlong_pkg.LatLng(item.destinationLatitude, item.destinationLongitude);

    LatLng toGoogleLatLng(latlong_pkg.LatLng latLng) {
      return LatLng(latLng.latitude, latLng.longitude);
    }

    final googleRoutePoints = routePoints.map(toGoogleLatLng).toList();

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: toGoogleLatLng(current),
        zoom: 13,
      ),
      polylines: {
        Polyline(
          polylineId: const PolylineId('route'),
          points: googleRoutePoints,
          color: route?.fallbackUsed == true
              ? const Color(0xFF3B82F6)
              : const Color(0xFF0B8B8C),
          width: 4,
        ),
      },
      markers: {
        Marker(
          markerId: const MarkerId('current'),
          position: toGoogleLatLng(current),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: toGoogleLatLng(destination),
          icon: item.deliveryType.toUpperCase() == 'PICKUP'
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}

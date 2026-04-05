import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as latlong_pkg;
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/maps/app_map_tiles.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/status_localizer.dart';
import '../../reservation/data/reservation_repository_impl.dart';
import '../../reservation/presentation/reservation_providers.dart';

enum DeliveryRequestType { delivery, pickup }

extension DeliveryRequestTypeX on DeliveryRequestType {
  String get code => this == DeliveryRequestType.pickup ? 'PICKUP' : 'DELIVERY';

  String get titleKey => this == DeliveryRequestType.pickup
      ? 'delivery_request_pickup_title'
      : 'delivery_request_dropoff_title';

  String get addressLabelKey => this == DeliveryRequestType.pickup
      ? 'delivery_address_pickup_label'
      : 'delivery_address_dropoff_label';

  String get addressHintKey => this == DeliveryRequestType.pickup
      ? 'delivery_address_pickup_hint'
      : 'delivery_address_dropoff_hint';

  String get windowLabelKey => this == DeliveryRequestType.pickup
      ? 'delivery_window_pickup_label'
      : 'delivery_window_dropoff_label';

  String get priceLabelKey => this == DeliveryRequestType.pickup
      ? 'delivery_price_pickup_label'
      : 'delivery_price_dropoff_label';

  String get actionLabelKey => this == DeliveryRequestType.pickup
      ? 'delivery_confirm_pickup'
      : 'delivery_confirm_dropoff';

  String get successMessageKey => this == DeliveryRequestType.pickup
      ? 'delivery_pickup_success'
      : 'delivery_dropoff_success';
}

enum DeliveryLocationMode { currentLocation, mapPoint }

extension DeliveryLocationModeX on DeliveryLocationMode {
  String get labelKey {
    switch (this) {
      case DeliveryLocationMode.currentLocation:
        return 'delivery_location_current';
      case DeliveryLocationMode.mapPoint:
        return 'delivery_location_map';
    }
  }
}

class DeliveryRequestPage extends ConsumerStatefulWidget {
  const DeliveryRequestPage({
    super.key,
    required this.reservationId,
    this.initialType = DeliveryRequestType.delivery,
    this.backRoute,
  });

  final String reservationId;
  final DeliveryRequestType initialType;
  final String? backRoute;

  @override
  ConsumerState<DeliveryRequestPage> createState() =>
      _DeliveryRequestPageState();
}

class _DeliveryRequestPageState extends ConsumerState<DeliveryRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _windowController = TextEditingController(text: '18:00 - 20:00');
  final _zoneController = TextEditingController();
  bool _loading = false;
  bool _resolvingCurrentLocation = false;
  late DeliveryRequestType _type;
  DeliveryLocationMode _locationMode = DeliveryLocationMode.currentLocation;
  latlong_pkg.LatLng? _selectedPoint;
  String? _seededReservationKey;
  bool _addressAutofilled = true;
  bool _zoneAutofilled = true;
  bool _programmaticFieldChange = false;
  bool _currentLocationCaptured = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _addressController.addListener(() {
      if (_programmaticFieldChange) {
        return;
      }
      _addressAutofilled = false;
    });
    _zoneController.addListener(() {
      if (_programmaticFieldChange) {
        return;
      }
      _zoneAutofilled = false;
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _windowController.dispose();
    _zoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reservationAsync = ref.watch(
      reservationByIdProvider(widget.reservationId),
    );

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(fallbackRoute: _resolvedBackRoute()),
        title: Text(l10n.t(_type.titleKey)),
      ),
      body: reservationAsync.when(
        data: (reservation) {
          if (reservation == null) {
            return EmptyStateView(message: l10n.t('reservation_not_found'));
          }
          final allowedTypes = _allowedTypesForReservation(reservation);
          if (allowedTypes.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: Text(
                      '${l10n.t('admin_reservation_code')}: ${reservation.code}',
                    ),
                    subtitle: Text(
                      '${reservation.warehouse.name}\n'
                      '${l10n.t('reservation_current_status')}: '
                      '${reservation.status.localizedLabel(context)}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.block_outlined),
                    title: Text(context.l10n.t('solicitud_no_disponible')),
                    subtitle: Text(
                      l10n.t('delivery_reservation_not_available_subtitle'),
                    ),
                  ),
                ),
              ],
            );
          }
          if (!allowedTypes.contains(_type)) {
            _type = allowedTypes.first;
          }
          _seedReservationContext(reservation);
          final servicePoint =
              _selectedPoint ?? _defaultServicePoint(reservation);
          return Form(
            key: _formKey,
            child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text(
                    '${l10n.t('admin_reservation_code')}: ${reservation.code}',
                  ),
                  subtitle: Text(
                    '${reservation.warehouse.name}\n'
                    '${l10n.t('reservation_current_status')}: '
                    '${reservation.status.localizedLabel(context)}',
                  ),
                ),
              ),
              SizedBox(height: 12),
              SegmentedButton<DeliveryRequestType>(
                segments: [
                  ButtonSegment(
                    value: DeliveryRequestType.pickup,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(context.l10n.t('recojo')),
                  ),
                  ButtonSegment(
                    value: DeliveryRequestType.delivery,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(context.l10n.t('entrega')),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) {
                  final next = selection.first;
                  if (!allowedTypes.contains(next)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          next == DeliveryRequestType.pickup
                              ? l10n.t('delivery_status_not_allowed_pickup')
                              : l10n.t('delivery_status_not_allowed_dropoff'),
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _type = next;
                    _seededReservationKey = null;
                  });
                },
              ),
              SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.t('ubicacion_del_servicio')),
                      SizedBox(height: 10),
                      SegmentedButton<DeliveryLocationMode>(
                        segments: [
                          ButtonSegment(
                            value: DeliveryLocationMode.currentLocation,
                            icon: const Icon(Icons.my_location_outlined),
                            label: Text(context.l10n.t('actual')),
                          ),
                          ButtonSegment(
                            value: DeliveryLocationMode.mapPoint,
                            icon: const Icon(Icons.map_outlined),
                            label: Text(context.l10n.t('mapa')),
                          ),
                        ],
                        selected: {_locationMode},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _locationMode = selection.first;
                          });
                        },
                      ),
                      SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.warehouse_outlined),
                        title: Text(
                          '${l10n.t('delivery_base_point')}: ${reservation.warehouse.name}',
                        ),
                        subtitle: Text(
                          '${reservation.warehouse.address}\n${_defaultZone(reservation)}',
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_locationMode == DeliveryLocationMode.currentLocation)
                        FilledButton.tonalIcon(
                          onPressed: _resolvingCurrentLocation
                              ? null
                              : () => _captureCurrentLocation(reservation),
                          icon: const Icon(Icons.gps_fixed_outlined),
                          label: Text(
                            _resolvingCurrentLocation
                                ? l10n.t('delivery_detecting_location')
                                : l10n.t('delivery_use_current_location'),
                          ),
                        )
                      else
                        FilledButton.tonalIcon(
                          onPressed: () => _pickOnMap(reservation),
                          icon: const Icon(Icons.place_outlined),
                          label: Text(context.l10n.t('elegir_punto_en_mapa')),
                        ),
                      if (_hasValidPoint(servicePoint)) ...[
                        SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _CoordinatePill(
                              label: context.l10n.t(
                                'courier_services_latitude',
                              ),
                              value: servicePoint.latitude.toStringAsFixed(6),
                            ),
                            _CoordinatePill(
                              label: context.l10n.t(
                                'courier_services_longitude',
                              ),
                              value: servicePoint.longitude.toStringAsFixed(6),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: l10n.t(_type.addressLabelKey),
                  hintText: l10n.t(_type.addressHintKey),
                ),
                maxLines: 2,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? '${l10n.t('delivery_enter_field')} ${l10n.t(_type.addressLabelKey).toLowerCase()}'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _windowController,
                decoration: InputDecoration(
                  labelText: l10n.t(_type.windowLabelKey),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _zoneController,
                decoration: InputDecoration(
                  labelText: l10n.t('delivery_zone_city_label'),
                  hintText: l10n.t('delivery_zone_city_hint'),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.t('ingresa_la_zona_o_ciudad_del_servicio')
                    : null,
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: Text(l10n.t(_type.priceLabelKey)),
                  subtitle: Text(
                    _type == DeliveryRequestType.pickup
                        ? l10n.t('delivery_pickup_info_subtitle')
                        : l10n.t('delivery_dropoff_info_subtitle'),
                  ),
                  trailing: Text(context.l10n.t('s1500')),
                ),
              ),
              if (_type == DeliveryRequestType.pickup) ...[
                SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text(context.l10n.t('como_funciona_el_recojo')),
                    subtitle: Text(l10n.t('delivery_pickup_steps')),
                  ),
                ),
              ],
              SizedBox(height: 24),
              FilledButton(
                onPressed: _loading
                    ? null
                    : () => _submitRequest(context, reservation),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text(
                  _loading
                      ? l10n.t('delivery_processing')
                      : l10n.t(_type.actionLabelKey),
                ),
              ),
            ],
          ),
          );
        },
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: '${l10n.t('delivery_prepare_failed')}: $error',
          onRetry: () =>
              ref.invalidate(reservationByIdProvider(widget.reservationId)),
        ),
      ),
    );
  }

  List<DeliveryRequestType> _allowedTypesForReservation(
    Reservation reservation,
  ) {
    switch (reservation.status) {
      case ReservationStatus.confirmed:
        if (reservation.pickupRequested) {
          return const [DeliveryRequestType.pickup];
        }
        return const [];
      case ReservationStatus.stored:
      case ReservationStatus.readyForPickup:
        if (reservation.dropoffRequested) {
          return const [DeliveryRequestType.delivery];
        }
        return const [];
      default:
        return const [];
    }
  }

  void _seedReservationContext(Reservation reservation) {
    final seedKey = '${reservation.id}:${_type.code}';
    if (_seededReservationKey == seedKey) {
      return;
    }
    _seededReservationKey = seedKey;
    _selectedPoint ??= _defaultServicePoint(reservation);
    if (_zoneController.text.trim().isEmpty || _zoneAutofilled) {
      _setZoneText(_defaultZone(reservation));
    }
    if ((_addressController.text.trim().isEmpty || _addressAutofilled) &&
        _selectedPoint != null) {
      _prefillAddressFromPoint(
        _selectedPoint!,
        reservation,
        currentLocation: false,
      );
    }
  }

  latlong_pkg.LatLng _defaultServicePoint(Reservation reservation) {
    final latitude = reservation.warehouse.latitude;
    final longitude = reservation.warehouse.longitude;
    if (_isValidCoordinate(latitude, longitude)) {
      return latlong_pkg.LatLng(latitude, longitude);
    }
    return const latlong_pkg.LatLng(-12.046374, -77.042793);
  }

  bool _hasValidPoint(latlong_pkg.LatLng? point) {
    if (point == null) {
      return false;
    }
    return _isValidCoordinate(point.latitude, point.longitude);
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    final latValid = latitude >= -90 && latitude <= 90;
    final lngValid = longitude >= -180 && longitude <= 180;
    return latValid && lngValid && !(latitude == 0 && longitude == 0);
  }

  String _defaultZone(Reservation reservation) {
    final district = reservation.warehouse.district.trim();
    final city = reservation.warehouse.city.trim();
    if (district.isNotEmpty && city.isNotEmpty) {
      return '$district, $city'.toUpperCase();
    }
    if (district.isNotEmpty) {
      return district.toUpperCase();
    }
    if (city.isNotEmpty) {
      return city.toUpperCase();
    }
    return 'PERU';
  }

  Future<void> _captureCurrentLocation(Reservation reservation) async {
    final l10n = context.l10n;
    setState(() => _resolvingCurrentLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage(l10n.t('delivery_enable_gps'));
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showMessage(l10n.t('delivery_location_permission_denied'));
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          l10n.t('delivery_location_permission_denied_forever'),
        );
        return;
      }

      final position = await _resolveBestPosition();
      if (position == null) {
        throw StateError(
          kIsWeb
              ? l10n.t('delivery_browser_location_invalid')
              : l10n.t('delivery_device_location_invalid'),
        );
      }
      final point = latlong_pkg.LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _selectedPoint = point;
        _currentLocationCaptured = true;
      });
      _prefillAddressFromPoint(point, reservation, currentLocation: true);
      _showMessage(
        '${l10n.t('delivery_location_captured')} '
        '(~${position.accuracy.toStringAsFixed(0)} m).',
      );
    } catch (error) {
      _showMessage(
        '${l10n.t('delivery_location_failed')}: '
        '${AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => l10n.t(key))}. '
        '${l10n.t('elegir_punto_en_mapa')}.',
      );
    } finally {
      if (mounted) {
        setState(() => _resolvingCurrentLocation = false);
      }
    }
  }

  Future<void> _pickOnMap(Reservation reservation) async {
    final initialPoint = _selectedPoint ?? _defaultServicePoint(reservation);
    final selected = await showDialog<latlong_pkg.LatLng>(
      context: context,
      builder: (context) =>
          _DeliveryLocationPickerDialog(initialPoint: initialPoint),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedPoint = selected;
      _currentLocationCaptured = false;
    });
    _prefillAddressFromPoint(selected, reservation, currentLocation: false);
    _showMessage(context.l10n.t('delivery_location_pick_success'));
  }

  void _prefillAddressFromPoint(
    latlong_pkg.LatLng point,
    Reservation reservation, {
    required bool currentLocation,
  }) {
    final locationLabel =
        '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
    final baseArea = _defaultZone(reservation);
    final prefix = currentLocation
        ? context.l10n.t('delivery_my_current_location_prefix')
        : _type == DeliveryRequestType.pickup
        ? context.l10n.t('delivery_pickup_point_prefix')
        : context.l10n.t('delivery_dropoff_point_prefix');
    _setAddressText('$prefix - $baseArea ($locationLabel)');
    if (_zoneController.text.trim().isEmpty || _zoneAutofilled) {
      _setZoneText(baseArea);
    }
  }

  Future<void> _submitRequest(
    BuildContext context,
    Reservation reservation,
  ) async {
    final allowedTypes = _allowedTypesForReservation(reservation);
    if (!allowedTypes.contains(_type)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('delivery_status_changed_retry')),
        ),
      );
      return;
    }

    final address = _addressController.text.trim();
    final zone = _zoneController.text.trim();
    final window = _windowController.text.trim();
    final point = _selectedPoint ?? _defaultServicePoint(reservation);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_locationMode == DeliveryLocationMode.currentLocation &&
        !_currentLocationCaptured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t('delivery_share_current_location_required'),
          ),
        ),
      );
      return;
    }
    if (!_hasValidPoint(point)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('delivery_service_location_required')),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(reservationRepositoryProvider)
          .requestLogisticsOrder(
            reservationId: widget.reservationId,
            type: _type.code,
            address: address,
            zone: zone,
            latitude: point.latitude,
            longitude: point.longitude,
            message:
                '${context.l10n.t(_type.titleKey)} '
                'hacia $address '
                '(${window.isEmpty ? context.l10n.t('delivery_no_window') : window}) '
                '[${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}].',
          );
      ref.invalidate(reservationByIdProvider(widget.reservationId));
      ref.invalidate(myReservationsProvider);
      ref.invalidate(adminReservationsProvider);
      ref.invalidate(adminReservationListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t(_type.successMessageKey))),
      );
      context.push(_resolveTrackingRoute(reservation.id));
    } catch (error) {
      if (!context.mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('delivery_request_failed')}: '
            '${AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key))}',
          ),
        ),
      );
    }
  }

  String _resolvedBackRoute() {
    final back = widget.backRoute?.trim();
    if (back != null && back.isNotEmpty) {
      return back;
    }
    return '/reservation/${widget.reservationId}';
  }

  String _resolveTrackingRoute(String reservationId) {
    final back = widget.backRoute?.trim();
    if (back != null && back.startsWith('/operator')) {
      return '/operator/tracking/$reservationId';
    }
    if (back != null && back.startsWith('/admin')) {
      return '/admin/tracking/$reservationId';
    }
    return '/tracking/$reservationId';
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _setAddressText(String value) {
    _programmaticFieldChange = true;
    _addressController.text = value;
    _addressController.selection = TextSelection.collapsed(
      offset: _addressController.text.length,
    );
    _programmaticFieldChange = false;
    _addressAutofilled = true;
  }

  void _setZoneText(String value) {
    _programmaticFieldChange = true;
    _zoneController.text = value;
    _zoneController.selection = TextSelection.collapsed(
      offset: _zoneController.text.length,
    );
    _programmaticFieldChange = false;
    _zoneAutofilled = true;
  }

  Future<Position?> _resolveBestPosition() async {
    Position? bestPosition;

    try {
      bestPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {}

    if (bestPosition != null && bestPosition.accuracy <= 120) {
      return bestPosition;
    }

    try {
      final streamed =
          await Geolocator.getPositionStream(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 0,
                ),
              )
              .where(
                (position) =>
                    _isValidCoordinate(position.latitude, position.longitude),
              )
              .first
              .timeout(const Duration(seconds: 8));
      if (bestPosition == null || streamed.accuracy < bestPosition.accuracy) {
        bestPosition = streamed;
      }
    } on TimeoutException {
      // Se mantiene el mejor valor previo.
    } catch (_) {}

    if (bestPosition != null && _isPositionFresh(bestPosition)) {
      return bestPosition;
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null &&
        _isPositionFresh(lastKnown, maxAge: const Duration(minutes: 15))) {
      return lastKnown;
    }
    return bestPosition;
  }

  bool _isPositionFresh(
    Position position, {
    Duration maxAge = const Duration(minutes: 2),
  }) {
    final timestamp = position.timestamp;
    return DateTime.now().difference(timestamp) <= maxAge;
  }
}

class _DeliveryLocationPickerDialog extends StatefulWidget {
  const _DeliveryLocationPickerDialog({required this.initialPoint});

  final latlong_pkg.LatLng initialPoint;

  @override
  State<_DeliveryLocationPickerDialog> createState() =>
      _DeliveryLocationPickerDialogState();
}

class _DeliveryLocationPickerDialogState
    extends State<_DeliveryLocationPickerDialog> {
  late latlong_pkg.LatLng _selectedPoint;
  final flutter_map.MapController _mapController = flutter_map.MapController();

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.t('delivery_map_pick_title'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(context.l10n.t('delivery_map_pick_subtitle')),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: flutter_map.FlutterMap(
                    mapController: _mapController,
                    options: flutter_map.MapOptions(
                      initialCenter: _selectedPoint,
                      initialZoom: 14,
                      onTap: (tapPosition, point) {
                        setState(() => _selectedPoint = point);
                      },
                    ),
                    children: [
                      flutter_map.TileLayer(
                        urlTemplate: AppMapTiles.rasterUrlTemplate,
                        userAgentPackageName: 'com.travelbox.peru.travelbox_peru_app',
                      ),
                      flutter_map.MarkerLayer(
                        markers: [
                          flutter_map.Marker(
                            point: _selectedPoint,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFFE5242D),
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _CoordinatePill(
                    label: context.l10n.t('courier_services_latitude'),
                    value: _selectedPoint.latitude.toStringAsFixed(6),
                  ),
                  _CoordinatePill(
                    label: context.l10n.t('courier_services_longitude'),
                    value: _selectedPoint.longitude.toStringAsFixed(6),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.t('cancelar')),
                  ),
                  SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(_selectedPoint),
                    icon: const Icon(Icons.check),
                    label: Text(context.l10n.t('usar_este_punto')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoordinatePill extends StatelessWidget {
  const _CoordinatePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final composedLabel = '$label: $value';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(composedLabel),
    );
  }
}

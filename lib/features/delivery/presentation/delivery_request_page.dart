import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../reservation/data/reservation_repository_impl.dart';
import '../../reservation/presentation/reservation_providers.dart';

enum DeliveryRequestType { delivery, pickup }

extension DeliveryRequestTypeX on DeliveryRequestType {
  String get code => this == DeliveryRequestType.pickup ? 'PICKUP' : 'DELIVERY';

  String get title => this == DeliveryRequestType.pickup
      ? 'Solicitar recojo'
      : 'Solicitar delivery';

  String get addressLabel => this == DeliveryRequestType.pickup
      ? 'Direccion de recojo'
      : 'Direccion de entrega';

  String get addressHint => this == DeliveryRequestType.pickup
      ? 'Hotel, casa o punto donde retiraremos el equipaje'
      : 'Hotel, terminal o direccion exacta de entrega';

  String get windowLabel => this == DeliveryRequestType.pickup
      ? 'Franja de recojo'
      : 'Franja de entrega';

  String get priceLabel => this == DeliveryRequestType.pickup
      ? 'Costo base recojo'
      : 'Costo base delivery';

  String get actionLabel => this == DeliveryRequestType.pickup
      ? 'Confirmar recojo'
      : 'Confirmar delivery';

  String get successMessage => this == DeliveryRequestType.pickup
      ? 'Recojo solicitado. Ahora podras seguir el courier en vivo.'
      : 'Delivery solicitado. Ahora podras seguir el courier en vivo.';
}

enum DeliveryLocationMode { currentLocation, mapPoint }

extension DeliveryLocationModeX on DeliveryLocationMode {
  String get label {
    switch (this) {
      case DeliveryLocationMode.currentLocation:
        return 'Ubicacion actual';
      case DeliveryLocationMode.mapPoint:
        return 'Elegir en mapa';
    }
  }
}

class DeliveryRequestPage extends ConsumerStatefulWidget {
  DeliveryRequestPage({
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
  final _addressController = TextEditingController();
  final _windowController = TextEditingController(text: '18:00 - 20:00');
  final _zoneController = TextEditingController();
  bool _loading = false;
  bool _resolvingCurrentLocation = false;
  late DeliveryRequestType _type;
  DeliveryLocationMode _locationMode = DeliveryLocationMode.currentLocation;
  LatLng? _selectedPoint;
  String? _seededReservationKey;
  bool _addressAutofilled = true;
  bool _zoneAutofilled = true;
  bool _programmaticFieldChange = false;

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
    final reservationAsync = ref.watch(
      reservationByIdProvider(widget.reservationId),
    );

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(
          fallbackRoute: _resolvedBackRoute(),
        ),
        title: Text(_type.title),
      ),
      body: reservationAsync.when(
        data: (reservation) {
          if (reservation == null) {
            return const EmptyStateView(message: 'Reserva no encontrada.');
          }
          final allowedTypes = _allowedTypesForReservation(reservation);
          if (allowedTypes.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: Text('Reserva ${reservation.code}'),
                    subtitle: Text(
                      '${reservation.warehouse.name}\nEstado actual: ${reservation.status.label}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.block_outlined),
                    title: Text(context.l10n.t('solicitud_no_disponible')),
                    subtitle: Text(
                      'En el estado actual no se puede crear recojo ni delivery. Si abriste una ventana antigua, vuelve al detalle y recarga la reserva.',
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
          final servicePoint = _selectedPoint ?? _defaultServicePoint(reservation);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text('Reserva ${reservation.code}'),
                  subtitle: Text(
                    '${reservation.warehouse.name}\nEstado actual: ${reservation.status.label}',
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
                              ? 'Este estado de reserva aun no permite solicitar recojo.'
                              : 'Este estado de reserva aun no permite solicitar delivery.',
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
                          setState(() => _locationMode = selection.first);
                        },
                      ),
                      SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.warehouse_outlined),
                        title: Text(
                          'Punto base: ${reservation.warehouse.name}',
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
                                ? 'Detectando ubicacion...'
                                : 'Usar mi ubicacion actual',
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
                              label: 'Lat',
                              value: servicePoint.latitude.toStringAsFixed(6),
                            ),
                            _CoordinatePill(
                              label: 'Lng',
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
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: _type.addressLabel,
                  hintText: _type.addressHint,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _windowController,
                decoration: InputDecoration(labelText: _type.windowLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _zoneController,
                decoration: const InputDecoration(
                  labelText: 'Zona o ciudad',
                  hintText: 'LIMA, CUSCO, MIRAFLORES, etc.',
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: Text(_type.priceLabel),
                  subtitle: Text(
                    _type == DeliveryRequestType.pickup
                        ? 'El equipaje sera recogido y trasladado al almacen.'
                        : 'El equipaje sera entregado en el destino indicado.',
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
                    subtitle: Text(
                      '1. Solicitas la movilidad.\n'
                      '2. Un courier toma el servicio.\n'
                      '3. Sigue el tracking en vivo.\n'
                      '4. Cuando el equipaje llega al almacen, tu reserva pasa a almacenada.',
                    ),
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
                child: Text(_loading ? 'Procesando...' : _type.actionLabel),
              ),
            ],
          );
        },
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: 'No se pudo preparar la solicitud: $error',
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

  LatLng _defaultServicePoint(Reservation reservation) {
    final latitude = reservation.warehouse.latitude;
    final longitude = reservation.warehouse.longitude;
    if (_isValidCoordinate(latitude, longitude)) {
      return LatLng(latitude, longitude);
    }
    return const LatLng(-12.046374, -77.042793);
  }

  bool _hasValidPoint(LatLng? point) {
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
    setState(() => _resolvingCurrentLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Activa el GPS para usar tu ubicacion actual.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('No hay permisos de ubicacion para continuar.');
        return;
      }

      final position = await _resolveBestPosition();
      if (position == null) {
        throw StateError(
          kIsWeb
              ? 'El navegador no entrego una ubicacion valida.'
              : 'El dispositivo no devolvio coordenadas validas.',
        );
      }
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _selectedPoint = point);
      _prefillAddressFromPoint(point, reservation, currentLocation: true);
      _showMessage(
        'Ubicacion actual capturada (precision ~${position.accuracy.toStringAsFixed(0)} m).',
      );
    } catch (error) {
      _showMessage(
        'No se pudo obtener ubicacion actual: ${AppErrorFormatter.readable(error)}. Puedes ajustar el punto manualmente en el mapa.',
      );
    } finally {
      if (mounted) {
        setState(() => _resolvingCurrentLocation = false);
      }
    }
  }

  Future<void> _pickOnMap(Reservation reservation) async {
    final initialPoint = _selectedPoint ?? _defaultServicePoint(reservation);
    final selected = await showDialog<LatLng>(
      context: context,
      builder: (context) => _DeliveryLocationPickerDialog(
        initialPoint: initialPoint,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedPoint = selected);
    _prefillAddressFromPoint(selected, reservation, currentLocation: false);
    _showMessage('Ubicacion seleccionada en mapa.');
  }

  void _prefillAddressFromPoint(
    LatLng point,
    Reservation reservation, {
    required bool currentLocation,
  }) {
    final locationLabel =
        '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
    final baseArea = _defaultZone(reservation);
    final prefix = currentLocation
        ? 'Mi ubicacion actual'
        : _type == DeliveryRequestType.pickup
        ? 'Punto de recojo'
        : 'Punto de entrega';
    _setAddressText('$prefix en $baseArea ($locationLabel)');
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
        const SnackBar(
          content: Text(
            'Esta reserva cambio de estado. Actualiza y vuelve a intentar la solicitud.',
          ),
        ),
      );
      return;
    }

    final address = _addressController.text.trim();
    final zone = _zoneController.text.trim();
    final window = _windowController.text.trim();
    final point = _selectedPoint ?? _defaultServicePoint(reservation);

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ingresa ${_type.addressLabel.toLowerCase()}.')),
      );
      return;
    }
    if (zone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('ingresa_la_zona_o_ciudad_del_servicio'))),
      );
      return;
    }
    if (!_hasValidPoint(point)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Debes fijar ubicacion del servicio (actual o mapa) antes de confirmar.',
          ),
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
                '${_type.title} solicitado hacia $address (${window.isEmpty ? 'sin franja' : window}) [${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}].',
          );
      ref.invalidate(reservationByIdProvider(widget.reservationId));
      ref.invalidate(myReservationsProvider);
      ref.invalidate(adminReservationsProvider);
      ref.invalidate(adminReservationListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_type.successMessage)));
      context.push(_resolveTrackingRoute(reservation.id));
    } catch (error) {
      if (!context.mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo registrar la solicitud: ${AppErrorFormatter.readable(error)}',
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
      final streamed = await Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).where((position) => _isValidCoordinate(position.latitude, position.longitude)).first.timeout(
            const Duration(seconds: 8),
          );
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
    if (lastKnown != null && _isPositionFresh(lastKnown, maxAge: const Duration(minutes: 15))) {
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

  final LatLng initialPoint;

  @override
  State<_DeliveryLocationPickerDialog> createState() =>
      _DeliveryLocationPickerDialogState();
}

class _DeliveryLocationPickerDialogState
    extends State<_DeliveryLocationPickerDialog> {
  late LatLng _selectedPoint;

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
                'Elegir punto en mapa',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Toca el mapa para fijar la ubicacion de recojo o entrega.',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _selectedPoint,
                      initialZoom: 14,
                      interactionOptions: const InteractionOptions(
                        flags:
                            InteractiveFlag.drag |
                            InteractiveFlag.pinchZoom |
                            InteractiveFlag.doubleTapZoom |
                            InteractiveFlag.scrollWheelZoom,
                      ),
                      onTap: (_, point) {
                        setState(() => _selectedPoint = point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.travelbox.peru.travelbox_peru_app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPoint,
                            width: 44,
                            height: 44,
                            child: const Icon(
                              Icons.location_pin,
                              color: Color(0xFFC43D3D),
                              size: 38,
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
                    label: 'Lat',
                    value: _selectedPoint.latitude.toStringAsFixed(6),
                  ),
                  _CoordinatePill(
                    label: 'Lng',
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}


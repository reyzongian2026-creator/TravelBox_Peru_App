import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/data/peru_tourism_catalog.dart';
import '../../../shared/models/warehouse.dart';
import '../../../shared/state/realtime_app_event_cursor_provider.dart';
import '../../../shared/state/warehouse_catalog_sync.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../../shared/widgets/peru_flat_scene.dart';
import '../../../shared/widgets/travelbox_logo.dart';
import '../data/discovery_repository_impl.dart';

enum DiscoveryViewMode { list, map }

final discoveryQueryProvider = StateProvider<String>((ref) => '');
final discoveryViewModeProvider = StateProvider<DiscoveryViewMode>(
  (ref) => DiscoveryViewMode.list,
);
final currentPositionProvider = StateProvider<Position?>((ref) => null);
final discoveryFeaturedCityProvider = StateProvider<String?>((ref) => null);

final discoveryWarehousesProvider = FutureProvider<List<Warehouse>>((ref) {
  ref.watch(realtimeAppEventCursorProvider);
  final query = ref.watch(discoveryQueryProvider);
  final position = ref.watch(currentPositionProvider);
  ref.watch(warehouseCatalogVersionProvider);
  return ref
      .read(discoveryRepositoryProvider)
      .searchWarehouses(
        query: query,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
});

class HomeDiscoveryPage extends ConsumerStatefulWidget {
  HomeDiscoveryPage({super.key});

  @override
  ConsumerState<HomeDiscoveryPage> createState() => _HomeDiscoveryPageState();
}

class _HomeDiscoveryPageState extends ConsumerState<HomeDiscoveryPage> {
  final _searchController = TextEditingController();
  bool _showHighlightsStrip = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewMode = ref.watch(discoveryViewModeProvider);
    final warehousesAsync = ref.watch(discoveryWarehousesProvider);
    final currentPosition = ref.watch(currentPositionProvider);
    final selectedCity = ref.watch(discoveryFeaturedCityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controlSurface = isDark ? const Color(0xFF111827) : Colors.white;
    final controlBorder = isDark
        ? const Color(0xFF273449)
        : const Color(0xFFDCEAF0);

    return AppShellScaffold(
      title: l10n.t('discover_title_nearby'),
      currentRoute: '/discovery',
      actions: [
        IconButton(
          tooltip: l10n.t('share_location'),
          onPressed: () => _locateUser(context),
          icon: const Icon(Icons.my_location_outlined),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: Column(
          children: [
            _DiscoveryHero(),
            const SizedBox(height: 14),
            if (currentPosition == null) ...[
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _showHighlightsStrip
                    ? Column(
                        children: [
                          _TourismHighlightsStrip(
                            selectedCity: selectedCity,
                            onCitySelected: (city) {
                              final current = ref.read(
                                discoveryFeaturedCityProvider,
                              );
                              final next = current == city ? null : city;
                              ref
                                      .read(
                                        discoveryFeaturedCityProvider.notifier,
                                      )
                                      .state =
                                  next;
                              _searchController.text = next ?? '';
                              ref.read(discoveryQueryProvider.notifier).state =
                                  next ?? '';
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: controlSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: controlBorder),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      ref.read(discoveryQueryProvider.notifier).state = value;
                      final pickedCity = ref.read(
                        discoveryFeaturedCityProvider,
                      );
                      if (pickedCity != null &&
                          value.trim().toLowerCase() !=
                              pickedCity.trim().toLowerCase()) {
                        ref.read(discoveryFeaturedCityProvider.notifier).state =
                            null;
                      }
                    },
                    decoration: InputDecoration(
                      hintText: l10n.t('search_discovery_hint'),
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(discoveryQueryProvider.notifier).state = '';
                          ref
                                  .read(discoveryFeaturedCityProvider.notifier)
                                  .state =
                              null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.t('list')),
                        selected: viewMode == DiscoveryViewMode.list,
                        onSelected: (_) {
                          ref.read(discoveryViewModeProvider.notifier).state =
                              DiscoveryViewMode.list;
                        },
                      ),
                      ChoiceChip(
                        label: Text(l10n.t('map')),
                        selected: viewMode == DiscoveryViewMode.map,
                        onSelected: (_) {
                          ref.read(discoveryViewModeProvider.notifier).state =
                              DiscoveryViewMode.map;
                        },
                      ),
                      FilterChip(
                        label: Text(l10n.t('without_gps')),
                        selected: currentPosition == null,
                        onSelected: (_) {
                          ref.read(currentPositionProvider.notifier).state =
                              null;
                          ref.invalidate(discoveryWarehousesProvider);
                          if (!_showHighlightsStrip) {
                            setState(() => _showHighlightsStrip = true);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _locateUser(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0B8B8C),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.my_location_outlined),
                      label: Text(l10n.t('share_location')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(discoveryWarehousesProvider),
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.t('reload')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: warehousesAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyStateView(
                      message: 'No hay almacenes para esta zona.',
                      actionLabel: 'Expandir busqueda',
                      onAction: () {
                        _searchController.clear();
                        ref.read(discoveryQueryProvider.notifier).state = '';
                        ref.read(discoveryFeaturedCityProvider.notifier).state =
                            null;
                      },
                    );
                  }

                  final nearest = _resolveNearestWarehouse(
                    warehouses: items,
                    userPosition: currentPosition,
                  );

                  final visibleItems = nearest != null
                      ? _sortWarehousesByDistance(
                          warehouses: items,
                          userPosition: currentPosition,
                        )
                      : _filterWarehousesByCity(
                          warehouses: items,
                          selectedCity: selectedCity,
                        );

                  if (visibleItems.isEmpty) {
                    return EmptyStateView(
                      message: selectedCity == null
                          ? 'No hay almacenes para esta zona.'
                          : 'No hay almacenes en $selectedCity.',
                      actionLabel: selectedCity == null
                          ? 'Expandir busqueda'
                          : 'Ver todas las ciudades',
                      onAction: () {
                        _searchController.clear();
                        ref.read(discoveryQueryProvider.notifier).state = '';
                        ref.read(discoveryFeaturedCityProvider.notifier).state =
                            null;
                      },
                    );
                  }

                  if (viewMode == DiscoveryViewMode.map) {
                    return Column(
                      children: [
                        if (nearest != null) ...[
                          _NearestWarehouseCard(info: nearest),
                          const SizedBox(height: 10),
                        ],
                        Expanded(
                          child: _MapView(
                            warehouses: visibleItems,
                            userPosition: currentPosition,
                            nearestWarehouseId: nearest?.warehouse.id,
                          ),
                        ),
                      ],
                    );
                  }

                  final listItems = nearest == null
                      ? visibleItems
                      : visibleItems
                            .where((item) => item.id != nearest.warehouse.id)
                            .toList();

                  return NotificationListener<UserScrollNotification>(
                    onNotification: (notification) {
                      if (currentPosition != null) return false;
                      if (notification.direction == ScrollDirection.reverse &&
                          _showHighlightsStrip) {
                        setState(() => _showHighlightsStrip = false);
                      } else if ((notification.direction ==
                                  ScrollDirection.forward ||
                              notification.metrics.pixels <= 8) &&
                          !_showHighlightsStrip) {
                        setState(() => _showHighlightsStrip = true);
                      }
                      return false;
                    },
                    child: ListView(
                      children: [
                        if (nearest != null) ...[
                          _NearestWarehouseCard(info: nearest),
                          const SizedBox(height: 10),
                        ],
                        ...listItems.map((warehouse) {
                          final distanceKm = _distanceKmToWarehouse(
                            userPosition: currentPosition,
                            warehouse: warehouse,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _WarehouseCard(
                              warehouse: warehouse,
                              distanceKm: currentPosition == null
                                  ? null
                                  : distanceKm,
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
                loading: () => const LoadingStateView(),
                error: (error, _) => ErrorStateView(
                  message: 'No se pudo cargar almacenes: $error',
                  onRetry: () => ref.invalidate(discoveryWarehousesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _locateUser(BuildContext context) async {
    final permission = await Geolocator.checkPermission();
    var finalPermission = permission;
    if (permission == LocationPermission.denied) {
      finalPermission = await Geolocator.requestPermission();
    }
    if (finalPermission == LocationPermission.denied ||
        finalPermission == LocationPermission.deniedForever) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('gps_disabled_manual'))),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    ref.read(currentPositionProvider.notifier).state = position;
    ref.read(discoveryFeaturedCityProvider.notifier).state = null;
    _searchController.clear();
    ref.read(discoveryQueryProvider.notifier).state = '';
    ref.invalidate(discoveryWarehousesProvider);
  }
}

class _DiscoveryHero extends StatelessWidget {
  _DiscoveryHero();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 840;
        final heroHeight = compact ? 132.0 : 112.0;
        final previewWidth = compact ? 156.0 : 236.0;
        return SizedBox(
          height: heroHeight,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0E8E8E), Color(0xFF38A7D1)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(child: _HeroTextBlock(compact: compact)),
                const SizedBox(width: 10),
                SizedBox(
                  width: previewWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const PeruFlatScene(
                          city: 'Cusco',
                          height: 46,
                          showLabel: false,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TourismHighlightsStrip extends StatefulWidget {
  const _TourismHighlightsStrip({
    required this.selectedCity,
    required this.onCitySelected,
  });

  final String? selectedCity;
  final ValueChanged<String> onCitySelected;

  @override
  State<_TourismHighlightsStrip> createState() =>
      _TourismHighlightsStripState();
}

class _TourismHighlightsStripState extends State<_TourismHighlightsStrip> {
  final _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _autoScrollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _autoScrollStep(),
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _autoScrollStep() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    const step = 220.0;
    var nextOffset = _scrollController.offset + (_forward ? step : -step);
    if (nextOffset >= maxExtent) {
      nextOffset = maxExtent;
      _forward = false;
    } else if (nextOffset <= 0) {
      nextOffset = 0;
      _forward = true;
    }
    _scrollController.animateTo(
      nextOffset,
      duration: const Duration(milliseconds: 680),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final featured = PeruTourismCatalog.featured.take(6).toList();
    return SizedBox(
      height: 132,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: featured.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final item = featured[index];
          final selected =
              widget.selectedCity?.toLowerCase() == item.city.toLowerCase();
          return _CityCarouselCard(
            item: item,
            selected: selected,
            onTap: () => widget.onCitySelected(item.city),
          );
        },
      ),
    );
  }
}

class _CityCarouselCard extends StatelessWidget {
  const _CityCarouselCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PeruTourismInfo item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 206,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF7FB) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF0B8B8C)
                  : const Color(0xFFD9E8EF),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PeruFlatScene(city: item.city, height: 52),
              const SizedBox(height: 6),
              Text(
                item.city,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                item.heroLandmark,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroTextBlock extends StatelessWidget {
  const _HeroTextBlock({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TravelBoxLogo(
          darkBackground: true,
          compact: true,
          showSubtitle: !compact,
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          'Descubre almacenes cercanos',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 2),
          Text(
            'Reserva por horas o dias, con QR y seguimiento en tiempo real.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92)),
          ),
        ],
      ],
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({
    required this.warehouses,
    required this.userPosition,
    required this.nearestWarehouseId,
  });

  final List<Warehouse> warehouses;
  final Position? userPosition;
  final String? nearestWarehouseId;

  @override
  Widget build(BuildContext context) {
    final allPoints = [
      ...warehouses.map(
        (warehouse) => LatLng(warehouse.latitude, warehouse.longitude),
      ),
      if (userPosition != null)
        LatLng(userPosition!.latitude, userPosition!.longitude),
    ];
    final center = allPoints.isNotEmpty
        ? allPoints.first
        : const LatLng(-12.0464, -77.0428);

    final markers = <Marker>[
      ...warehouses.map(
        (warehouse) => Marker(
          width: 124,
          height: 52,
          point: LatLng(warehouse.latitude, warehouse.longitude),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/warehouse/${warehouse.id}'),
              child: Card(
                color: Colors.white.withValues(alpha: 0.96),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: warehouse.id == nearestWarehouseId
                        ? const Color(0xFF0B8B8C)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Color(0xFF0B8B8C),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'S/${warehouse.priceFromPerHour.toStringAsFixed(0)} ${warehouse.name}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ];

    if (userPosition != null) {
      markers.add(
        Marker(
          width: 22,
          height: 22,
          point: LatLng(userPosition!.latitude, userPosition!.longitude),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 12,
          initialCameraFit: allPoints.length > 1
              ? CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(allPoints),
                  padding: const EdgeInsets.all(42),
                  maxZoom: 13.5,
                  minZoom: 4,
                )
              : null,
          interactionOptions: const InteractionOptions(
            flags:
                InteractiveFlag.pinchZoom |
                InteractiveFlag.drag |
                InteractiveFlag.doubleTapZoom |
                InteractiveFlag.scrollWheelZoom,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.travelbox.peru.travelbox_peru_app',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}

class _NearestWarehouseCard extends StatelessWidget {
  const _NearestWarehouseCard({required this.info});

  final _NearestWarehouseInfo info;

  @override
  Widget build(BuildContext context) {
    final tourism = PeruTourismCatalog.forCity(info.warehouse.city);
    return Card(
      color: const Color(0xFFE8F7F5),
      child: ListTile(
        leading: const Icon(Icons.near_me_outlined, color: Color(0xFF0B8B8C)),
        title: Text(context.l10n.t('almacen_mas_cercano')),
        subtitle: Text(
          '${info.warehouse.name}\nA ${info.distanceKm.toStringAsFixed(2)} km de tu ubicacion\nTurismo cercano: ${tourism.heroLandmark}',
        ),
        isThreeLine: true,
        trailing: FilledButton.tonal(
          onPressed: () => context.push('/warehouse/${info.warehouse.id}'),
          child: Text(context.l10n.t('ver')),
        ),
      ),
    );
  }
}

class _NearestWarehouseInfo {
  _NearestWarehouseInfo({
    required this.warehouse,
    required this.distanceKm,
  });

  final Warehouse warehouse;
  final double distanceKm;
}

_NearestWarehouseInfo? _resolveNearestWarehouse({
  required List<Warehouse> warehouses,
  required Position? userPosition,
}) {
  if (userPosition == null || warehouses.isEmpty) {
    return null;
  }
  _NearestWarehouseInfo? nearest;
  for (final warehouse in warehouses) {
    final distanceMeters = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      warehouse.latitude,
      warehouse.longitude,
    );
    final distanceKm = distanceMeters / 1000;
    if (nearest == null || distanceKm < nearest.distanceKm) {
      nearest = _NearestWarehouseInfo(
        warehouse: warehouse,
        distanceKm: distanceKm,
      );
    }
  }
  return nearest;
}

List<Warehouse> _filterWarehousesByCity({
  required List<Warehouse> warehouses,
  required String? selectedCity,
}) {
  if (selectedCity == null || selectedCity.trim().isEmpty) {
    return warehouses;
  }
  final normalizedCity = selectedCity.trim().toLowerCase();
  return warehouses.where((warehouse) {
    final city = warehouse.city.trim().toLowerCase();
    final district = warehouse.district.trim().toLowerCase();
    return city == normalizedCity || district.contains(normalizedCity);
  }).toList();
}

List<Warehouse> _sortWarehousesByDistance({
  required List<Warehouse> warehouses,
  required Position? userPosition,
}) {
  if (userPosition == null) {
    return warehouses;
  }
  final ordered = [...warehouses];
  ordered.sort((left, right) {
    final leftDistance = _distanceKmToWarehouse(
      userPosition: userPosition,
      warehouse: left,
    );
    final rightDistance = _distanceKmToWarehouse(
      userPosition: userPosition,
      warehouse: right,
    );
    return leftDistance.compareTo(rightDistance);
  });
  return ordered;
}

double _distanceKmToWarehouse({
  required Position? userPosition,
  required Warehouse warehouse,
}) {
  if (userPosition == null) {
    return double.infinity;
  }
  final distanceMeters = Geolocator.distanceBetween(
    userPosition.latitude,
    userPosition.longitude,
    warehouse.latitude,
    warehouse.longitude,
  );
  return distanceMeters / 1000;
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({required this.warehouse, this.distanceKm});

  final Warehouse warehouse;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final tourism = PeruTourismCatalog.forCity(warehouse.city);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSmartImage(
              source: warehouse.imageUrl,
              height: 146,
              width: double.infinity,
              borderRadius: BorderRadius.circular(14),
              fallback: PeruFlatScene(city: warehouse.city, height: 146),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    warehouse.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.star_rounded, size: 16),
                  label: Text(warehouse.score.toStringAsFixed(1)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text('${warehouse.address}, ${warehouse.district}'),
            if (distanceKm != null) ...[
              const SizedBox(height: 2),
              Text(
                'A ${distanceKm!.toStringAsFixed(2)} km de tu ubicacion',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF0B8B8C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${tourism.city}: ${tourism.heroLandmark}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF486581)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...warehouse.extraServices.map(
                  (service) => Chip(label: Text(service)),
                ),
                ...tourism.highlights
                    .take(2)
                    .map((item) => Chip(label: Text(item))),
              ].toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Desde S/${warehouse.priceFromPerHour.toStringAsFixed(2)}/hora',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => context.push('/warehouse/${warehouse.id}'),
                  child: Text(context.l10n.t('ver_detalle')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


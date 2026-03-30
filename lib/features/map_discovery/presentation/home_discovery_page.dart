import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;

import 'package:latlong2/latlong.dart' as latlong_pkg;

import '../../../core/env/app_env.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/data/peru_tourism_catalog.dart';
import '../../../shared/models/warehouse.dart';
import '../../../shared/state/realtime_app_event_cursor_provider.dart';
import '../../../shared/state/warehouse_catalog_sync.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../../shared/widgets/peru_flat_scene.dart';
import '../../../shared/state/currency_preference.dart';
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
  const HomeDiscoveryPage({super.key});

  @override
  ConsumerState<HomeDiscoveryPage> createState() => _HomeDiscoveryPageState();
}

class _HomeDiscoveryPageState extends ConsumerState<HomeDiscoveryPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _showHighlightsStrip = true;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final responsive = context.responsive;
    final viewMode = ref.watch(discoveryViewModeProvider);
    final warehousesAsync = ref.watch(discoveryWarehousesProvider);
    final currentPosition = ref.watch(currentPositionProvider);
    final selectedCity = ref.watch(discoveryFeaturedCityProvider);
    final mediaQuery = MediaQuery.of(context);
    final mapMode = viewMode == DiscoveryViewMode.map;
    final baseMapHeight = responsive.mapHeight(max: 560);
    final immersiveMapHeight =
        (mediaQuery.size.height * (responsive.isMobile ? 0.86 : 0.72))
            .clamp(baseMapHeight + (responsive.isMobile ? 36 : 0), 860)
            .toDouble();
    final mapHeight = mapMode ? immersiveMapHeight : baseMapHeight;
    final sectionGap = responsive.sectionGap;
    final itemGap = responsive.itemGap;
    final cardPadding = responsive.cardPadding;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controlSurface = isDark ? const Color(0xFF1B1718) : Colors.white;
    final controlBorder = isDark
        ? const Color(0xFF4A3934)
        : TravelBoxBrand.border;

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
      child: warehousesAsync.when(
        data: (items) {
          final contentChildren = <Widget>[
            if (!mapMode) _DiscoveryHero(),
            if (!mapMode) SizedBox(height: sectionGap),
            if (currentPosition == null && !mapMode)
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
                          SizedBox(height: itemGap),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            Container(
              padding: EdgeInsets.all(cardPadding),
              decoration: BoxDecoration(
                color: controlSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: controlBorder),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: const Color(0x164C2512),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: l10n.t('search_discovery_hint'),
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearDiscoveryFilters,
                      ),
                    ),
                  ),
                  SizedBox(height: itemGap),
                  Wrap(
                    spacing: itemGap,
                    runSpacing: itemGap,
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
                  SizedBox(height: itemGap),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 320) {
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.tonalIcon(
                                onPressed: () => _locateUser(context),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 42),
                                  backgroundColor: TravelBoxBrand.primaryBlue,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.my_location_outlined),
                                label: Text(l10n.t('share_location')),
                              ),
                            ),
                            SizedBox(height: itemGap),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    ref.invalidate(discoveryWarehousesProvider),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 42),
                                ),
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.t('reload')),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () => _locateUser(context),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 42),
                                backgroundColor: TravelBoxBrand.primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.my_location_outlined),
                              label: Text(l10n.t('share_location')),
                            ),
                          ),
                          SizedBox(width: itemGap),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  ref.invalidate(discoveryWarehousesProvider),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 42),
                              ),
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.t('reload')),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: sectionGap),
          ];

          if (items.isEmpty) {
            contentChildren.add(
              EmptyStateView(
                message: l10n.t('discovery_empty_zone'),
                actionLabel: l10n.t('discovery_expand_search'),
                onAction: _clearDiscoveryFilters,
              ),
            );
            contentChildren.add(SizedBox(height: sectionGap));
            return ListView(
              padding: responsive.pageInsets(
                top: responsive.verticalPadding,
                bottom: sectionGap,
              ),
              children: contentChildren,
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
            contentChildren.add(
              EmptyStateView(
                message: selectedCity == null
                    ? l10n.t('discovery_empty_zone')
                    : '${l10n.t('discovery_empty_city_prefix')} $selectedCity.',
                actionLabel: selectedCity == null
                    ? l10n.t('discovery_expand_search')
                    : l10n.t('discovery_view_all_cities'),
                onAction: _clearDiscoveryFilters,
              ),
            );
            contentChildren.add(SizedBox(height: sectionGap));
            return ListView(
              padding: responsive.pageInsets(
                top: responsive.verticalPadding,
                bottom: sectionGap,
              ),
              children: contentChildren,
            );
          }

          if (viewMode == DiscoveryViewMode.map) {
            if (nearest != null) {
              contentChildren.add(_NearestWarehouseCard(info: nearest));
              contentChildren.add(SizedBox(height: itemGap));
            }
            contentChildren.add(
              SizedBox(
                height: mapHeight,
                child: _MapView(
                  warehouses: visibleItems,
                  userPosition: currentPosition,
                  nearestWarehouseId: nearest?.warehouse.id,
                ),
              ),
            );
            return ListView(
              padding: responsive.pageInsets(
                top: responsive.verticalPadding,
                bottom: 0,
              ),
              children: contentChildren,
            );
          }

          final listItems = nearest == null
              ? visibleItems
              : visibleItems
                    .where((item) => item.id != nearest.warehouse.id)
                    .toList();

          if (nearest != null) {
            contentChildren.add(_NearestWarehouseCard(info: nearest));
            contentChildren.add(SizedBox(height: itemGap));
          }

          for (final warehouse in listItems) {
            final distanceKm = _distanceKmToWarehouse(
              userPosition: currentPosition,
              warehouse: warehouse,
            );
            contentChildren.add(
              Padding(
                padding: EdgeInsets.only(bottom: itemGap),
                child: _WarehouseCard(
                  warehouse: warehouse,
                  distanceKm: currentPosition == null ? null : distanceKm,
                ),
              ),
            );
          }
          contentChildren.add(SizedBox(height: sectionGap));

          final list = ListView(
            padding: responsive.pageInsets(
              top: responsive.verticalPadding,
              bottom: sectionGap,
            ),
            children: contentChildren,
          );

          if (currentPosition != null) {
            return list;
          }

          return NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.reverse &&
                  _showHighlightsStrip) {
                setState(() => _showHighlightsStrip = false);
              } else if ((notification.direction == ScrollDirection.forward ||
                      notification.metrics.pixels <= 8) &&
                  !_showHighlightsStrip) {
                setState(() => _showHighlightsStrip = true);
              }
              return false;
            },
            child: list,
          );
        },
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: AppErrorFormatter.readable(
            error,
            (String key, {Map<String, dynamic>? params}) =>
                l10n.t(key),
          ),
          onRetry: () => ref.invalidate(discoveryWarehousesProvider),
        ),
      ),
    );
  }

  void _clearDiscoveryFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(discoveryQueryProvider.notifier).state = '';
    ref.read(discoveryFeaturedCityProvider.notifier).state = null;
    if (!_showHighlightsStrip) {
      setState(() => _showHighlightsStrip = true);
    }
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
    _searchDebounce?.cancel();
    ref.read(currentPositionProvider.notifier).state = position;
    ref.read(discoveryFeaturedCityProvider.notifier).state = null;
    _searchController.clear();
    ref.read(discoveryQueryProvider.notifier).state = '';
    ref.invalidate(discoveryWarehousesProvider);
  }

  void _onSearchChanged(String value) {
    final pickedCity = ref.read(discoveryFeaturedCityProvider);
    if (pickedCity != null &&
        value.trim().toLowerCase() != pickedCity.trim().toLowerCase()) {
      ref.read(discoveryFeaturedCityProvider.notifier).state = null;
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final nextQuery = value.trim();
      final currentQuery = ref.read(discoveryQueryProvider);
      if (currentQuery == nextQuery) {
        return;
      }
      ref.read(discoveryQueryProvider.notifier).state = nextQuery;
    });
  }
}

class _DiscoveryHero extends StatelessWidget {
  const _DiscoveryHero();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hidePreview = constraints.maxWidth < 390;
        final compact = constraints.maxWidth < 840;
        final heroHeight = hidePreview ? 102.0 : (compact ? 120.0 : 112.0);
        final previewWidth = compact ? 148.0 : 220.0;
        return SizedBox(
          height: heroHeight,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: TravelBoxBrand.discoveryGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(child: _HeroTextBlock(compact: compact)),
                if (!hidePreview) ...[
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
    final responsive = context.responsive;
    return SizedBox(
      height: responsive.isMobile ? 120 : 132,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: featured.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = selected
        ? (isDark ? const Color(0xFF3A2621) : const Color(0xFFF3E4D2))
        : (isDark ? const Color(0xFF1B1718) : Colors.white);
    final borderColor = selected
        ? TravelBoxBrand.copper
        : (isDark ? const Color(0xFF4A3934) : TravelBoxBrand.border);
    final titleColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF17212F);
    final subtitleColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF4B6476);

    return SizedBox(
      width: 188,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: const Color(0x124C2512),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PeruFlatScene(city: item.city, height: 52),
              const SizedBox(height: 6),
              Text(
                item.city,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              Text(
                item.heroLandmark,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: subtitleColor),
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
          context.l10n.t('discover_title_nearby'),
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
            context.l10n.t('discover_hero_subtitle'),
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
        (warehouse) => latlong_pkg.LatLng(warehouse.latitude, warehouse.longitude),
      ),
      if (userPosition != null)
        latlong_pkg.LatLng(userPosition!.latitude, userPosition!.longitude),
    ];
    final center = allPoints.isNotEmpty
        ? allPoints.first
        : const latlong_pkg.LatLng(-12.0464, -77.0428);

    if (kIsWeb) {
      return _buildFlutterMap(context, center);
    }
    return _buildGoogleMap(context, center);
  }

  Widget _buildFlutterMap(BuildContext context, latlong_pkg.LatLng center) {
    final warehouseMarkers = warehouses.map((warehouse) => flutter_map.Marker(
      point: latlong_pkg.LatLng(warehouse.latitude, warehouse.longitude),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => context.push('/warehouse/${warehouse.id}'),
        child: const Icon(
          Icons.location_on,
          color: Color(0xFF0B8B8C),
          size: 40,
        ),
      ),
    )).toList();

    if (userPosition != null) {
      warehouseMarkers.add(flutter_map.Marker(
        point: latlong_pkg.LatLng(userPosition!.latitude, userPosition!.longitude),
        width: 40,
        height: 40,
        child: const Icon(
          Icons.my_location,
          color: Color(0xFF3B82F6),
          size: 40,
        ),
      ));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: flutter_map.FlutterMap(
        options: flutter_map.MapOptions(
          initialCenter: center,
          initialZoom: 12,
        ),
        children: [
          flutter_map.TileLayer(
            urlTemplate: AppEnv.azureMapsApiKey.trim().isNotEmpty
                ? 'https://atlas.microsoft.com/map/tile?api-version=2022-12-01&tilesetId=microsoft.basemaps&zoom={z}&x={x}&y={y}&subscription-key=${AppEnv.azureMapsApiKey}'
                : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.travelbox.peru.travelbox_peru_app',
          ),
          flutter_map.MarkerLayer(markers: warehouseMarkers),
        ],
      ),
    );
  }

  Widget _buildGoogleMap(BuildContext context, latlong_pkg.LatLng center) {
    final warehouseMarkers = warehouses.map((warehouse) => flutter_map.Marker(
      point: latlong_pkg.LatLng(warehouse.latitude, warehouse.longitude),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => context.push('/warehouse/${warehouse.id}'),
        child: const Icon(
          Icons.location_on,
          color: Color(0xFF0B8B8C),
          size: 40,
        ),
      ),
    )).toList();

    if (userPosition != null) {
      warehouseMarkers.add(flutter_map.Marker(
        point: latlong_pkg.LatLng(userPosition!.latitude, userPosition!.longitude),
        width: 40,
        height: 40,
        child: const Icon(
          Icons.my_location,
          color: Color(0xFF3B82F6),
          size: 40,
        ),
      ));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: flutter_map.FlutterMap(
        options: flutter_map.MapOptions(
          initialCenter: center,
          initialZoom: 12,
        ),
        children: [
          flutter_map.TileLayer(
            urlTemplate: AppEnv.azureMapsApiKey.trim().isNotEmpty
                ? 'https://atlas.microsoft.com/map/tile?api-version=2022-12-01&tilesetId=microsoft.basemaps&zoom={z}&x={x}&y={y}&subscription-key=${AppEnv.azureMapsApiKey}'
                : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.travelbox.peru.travelbox_peru_app',
          ),
          flutter_map.MarkerLayer(markers: warehouseMarkers),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final subtitleColor = isDark
        ? const Color(0xFFD1D9E6)
        : const Color(0xFF334155);
    final tourism = PeruTourismCatalog.forCity(info.warehouse.city);
    return Card(
      color: isDark ? const Color(0xFF2B201D) : const Color(0xFFF4E7D9),
      child: ListTile(
        leading: Icon(
          Icons.near_me_outlined,
          color: TravelBoxBrand.terracotta,
        ),
        title: Text(
          context.l10n.t('almacen_mas_cercano'),
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${info.warehouse.name}\n'
          '${context.l10n.t('discovery_distance_to_you_prefix')} '
          '${info.distanceKm.toStringAsFixed(2)} '
          '${context.l10n.t('km_de_tu_ubicacion')}\n'
          '${context.l10n.t('discovery_tourism_nearby')}: '
          '${tourism.heroLandmark}',
          style: TextStyle(color: subtitleColor),
        ),
        isThreeLine: true,
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 92, maxWidth: 124),
          child: FilledButton.tonal(
            onPressed: () => context.push('/warehouse/${info.warehouse.id}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              backgroundColor: TravelBoxBrand.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(context.l10n.t('ver')),
          ),
        ),
      ),
    );
  }
}

class _NearestWarehouseInfo {
  _NearestWarehouseInfo({required this.warehouse, required this.distanceKm});

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
    final responsive = context.responsive;
    final cardPadding = responsive.cardPadding;
    final sectionGap = responsive.sectionGap;
    final imageHeight = responsive.isMobile ? 132.0 : 146.0;
    final tourism = PeruTourismCatalog.forCity(warehouse.city);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSmartImage(
              source: warehouse.imageUrl,
              height: imageHeight,
              width: double.infinity,
              borderRadius: BorderRadius.circular(14),
              fallback: PeruFlatScene(
                city: warehouse.city,
                height: imageHeight,
              ),
            ),
            SizedBox(height: sectionGap),
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
                if (warehouse.score > 0)
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
                '${context.l10n.t('discovery_distance_to_you_prefix')} '
                '${distanceKm!.toStringAsFixed(2)} '
                '${context.l10n.t('km_de_tu_ubicacion')}',
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
            SizedBox(height: responsive.itemGap),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...warehouse.extraServices.map(
                  (service) => Chip(
                    label: Text(service),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                ...tourism.highlights
                    .take(2)
                    .map(
                      (item) => Chip(
                        label: Text(item),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
              ].toList(),
            ),
            SizedBox(height: sectionGap),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: responsive.itemGap,
              runSpacing: responsive.itemGap,
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    final userCurrency = ref.watch(currencyPreferenceProvider);
                    final convertedPrice = CurrencyRates.convert(warehouse.priceFromPerHour, CurrencyCode.pen, userCurrency);
                    return Text(
                      '${context.l10n.t('discovery_price_from')}: '
                      '${formatCurrency(convertedPrice, userCurrency)}'
                      '${context.l10n.t('discovery_per_hour')}',
                      style: Theme.of(context).textTheme.titleSmall,
                    );
                  },
                ),
                FilledButton(
                  onPressed: () => context.push('/warehouse/${warehouse.id}'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    visualDensity: VisualDensity.compact,
                  ),
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

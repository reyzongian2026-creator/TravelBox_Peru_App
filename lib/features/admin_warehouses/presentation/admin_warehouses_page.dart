import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/env/app_env.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/adaptive_wrap_grid.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/state/realtime_app_event_cursor_provider.dart';
import '../../../shared/state/warehouse_catalog_sync.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/form_validators.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../incidents/data/evidence_picker.dart';
import '../../incidents/data/selected_evidence_image.dart';
import 'warehouse_location_picker_dialog.dart';

final adminWarehouseSearchProvider = StateProvider<String>((ref) => '');
final adminWarehouseActiveFilterProvider = StateProvider<String>(
  (ref) => 'ACTIVE',
);

final adminWarehousesProvider = FutureProvider<List<AdminWarehouse>>((
  ref,
) async {
  ref.watch(realtimeAppEventCursorProvider);
  ref.watch(warehouseCatalogVersionProvider);
  final dio = ref.read(dioProvider);
  final query = ref.watch(adminWarehouseSearchProvider).trim();
  final activeFilter = ref.watch(adminWarehouseActiveFilterProvider);
  final active = switch (activeFilter) {
    'ACTIVE' => true,
    'INACTIVE' => false,
    _ => null,
  };
  final response = await dio.get<List<dynamic>>(
    '/admin/warehouses',
    queryParameters: {
      if (query.isNotEmpty) 'query': query,
      // ignore: use_null_aware_elements
      if (active case final activeValue?) 'active': activeValue,
    },
  );
  return (response.data ?? const [])
      .map((item) => AdminWarehouse.fromJson(item as Map<String, dynamic>))
      .toList();
});

final adminCitiesProvider = FutureProvider<List<CityOption>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get<List<dynamic>>('/geo/cities');
  return (response.data ?? const [])
      .map((item) => CityOption.fromJson(item as Map<String, dynamic>))
      .toList();
});

final adminZonesProvider = FutureProvider.family<List<ZoneOption>, int>((
  ref,
  cityId,
) async {
  if (cityId <= 0) return const [];
  final dio = ref.read(dioProvider);
  final response = await dio.get<List<dynamic>>(
    '/geo/zones',
    queryParameters: {'cityId': cityId},
  );
  return (response.data ?? const [])
      .map((item) => ZoneOption.fromJson(item as Map<String, dynamic>))
      .toList();
});

class AdminWarehousesPage extends ConsumerStatefulWidget {
  AdminWarehousesPage({super.key});

  @override
  ConsumerState<AdminWarehousesPage> createState() =>
      _AdminWarehousesPageState();
}

class _AdminWarehousesPageState extends ConsumerState<AdminWarehousesPage> {
  final _searchController = TextEditingController();
  bool _saving = false;

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
    final warehouses = ref.watch(adminWarehousesProvider);
    final activeFilter = ref.watch(adminWarehouseActiveFilterProvider);
    return AppShellScaffold(
      title: context.l10n.t('admin_warehouses_title'),
      currentRoute: '/admin/warehouses',
      child: Column(
        children: [
          Padding(
            padding: responsive.pageInsets(top: responsive.verticalPadding),
            child: _buildToolbar(context, activeFilter: activeFilter),
          ),
          SizedBox(height: itemGap),
          Expanded(
            child: warehouses.when(
              data: (items) {
                if (items.isEmpty) {
                  return EmptyStateView(
                    message: context.l10n.t('admin_warehouses_empty_filter'),
                  );
                }

                final totalCapacity = items.fold<int>(
                  0,
                  (sum, item) => sum + item.capacity,
                );
                final totalOccupied = items.fold<int>(
                  0,
                  (sum, item) => sum + item.occupied,
                );
                final totalAvailable = items.fold<int>(
                  0,
                  (sum, item) => sum + item.available,
                );

                return ListView(
                  padding: responsive.pageInsets(top: 0, bottom: sectionGap),
                  children: [
                    AdaptiveWrapGrid(
                      spacing: itemGap,
                      runSpacing: itemGap,
                      mobileColumns: 1,
                      tabletColumns: 2,
                      desktopSmallColumns: 4,
                      desktopColumns: 4,
                      minItemWidth: 170,
                      children: [
                        _StockCard(
                          title: context.l10n.t('admin_warehouses_stock_sites'),
                          value: '${items.length}',
                          colorA: const Color(0xFF0B8B8C),
                          colorB: const Color(0xFF2AAAC2),
                        ),
                        _StockCard(
                          title: context.l10n.t(
                            'admin_warehouses_stock_total_capacity',
                          ),
                          value: '$totalCapacity',
                          colorA: const Color(0xFF1F6E8C),
                          colorB: const Color(0xFF3F9AC1),
                        ),
                        _StockCard(
                          title: context.l10n.t(
                            'admin_warehouses_stock_occupied',
                          ),
                          value: '$totalOccupied',
                          colorA: const Color(0xFFC43D3D),
                          colorB: const Color(0xFFDE7060),
                        ),
                        _StockCard(
                          title: context.l10n.t(
                            'admin_warehouses_stock_available',
                          ),
                          value: '$totalAvailable',
                          colorA: const Color(0xFF168F64),
                          colorB: const Color(0xFF2DAE7B),
                        ),
                      ],
                    ),
                    SizedBox(height: sectionGap),
                    _WarehouseRegistryTable(
                      items: items,
                      saving: _saving,
                      onEdit: _editWarehouse,
                      onToggleActive: (warehouse) {
                        if (warehouse.active) {
                          return _deleteWarehouse(warehouse);
                        }
                        return _reactivateWarehouse(warehouse);
                      },
                    ),
                  ],
                );
              },
              loading: () => const LoadingStateView(),
              error: (error, _) => ErrorStateView(
                message:
                    '${context.l10n.t('admin_warehouses_load_failed_prefix')}: '
                    '$error',
                onRetry: () => ref.invalidate(adminWarehousesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, {required String activeFilter}) {
    final responsive = context.responsive;
    final itemGap = responsive.itemGap;
    final l10n = context.l10n;

    Widget buildSearchField() {
      return TextField(
        controller: _searchController,
        onChanged: (value) {
          ref.read(adminWarehouseSearchProvider.notifier).state = value;
        },
        decoration: InputDecoration(
          labelText: l10n.t('admin_warehouses_search_label'),
          prefixIcon: const Icon(Icons.search),
        ),
      );
    }

    Widget buildStatusFilter() {
      return DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: activeFilter,
        decoration: InputDecoration(
          labelText: l10n.t('estado'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        items: [
          DropdownMenuItem(value: 'ACTIVE', child: Text(l10n.t('activos'))),
          DropdownMenuItem(value: 'ALL', child: Text(l10n.t('todos'))),
          DropdownMenuItem(value: 'INACTIVE', child: Text(l10n.t('inactivos'))),
        ],
        onChanged: (value) {
          if (value != null) {
            ref.read(adminWarehouseActiveFilterProvider.notifier).state = value;
          }
        },
      );
    }

    Widget buildCreateButton() {
      return FilledButton.icon(
        onPressed: _saving ? null : _createWarehouse,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.t('nuevo')),
      );
    }

    Widget buildRefreshButton() {
      return OutlinedButton.icon(
        onPressed: _saving
            ? null
            : () => ref.invalidate(adminWarehousesProvider),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.refresh),
        label: Text(l10n.t('recargar')),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wideRow = constraints.maxWidth >= 1080;
        if (wideRow) {
          final statusWidth = (constraints.maxWidth * 0.2)
              .clamp(180.0, 260.0)
              .toDouble();
          return Row(
            children: [
              Expanded(child: buildSearchField()),
              SizedBox(width: itemGap),
              SizedBox(width: statusWidth, child: buildStatusFilter()),
              SizedBox(width: itemGap),
              buildCreateButton(),
              SizedBox(width: itemGap),
              buildRefreshButton(),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildSearchField(),
            SizedBox(height: itemGap),
            AdaptiveWrapGrid(
              spacing: itemGap,
              runSpacing: itemGap,
              mobileColumns: 1,
              tabletColumns: 2,
              desktopSmallColumns: 3,
              desktopColumns: 3,
              minItemWidth: 170,
              children: [
                SizedBox(width: double.infinity, child: buildCreateButton()),
                buildStatusFilter(),
                SizedBox(width: double.infinity, child: buildRefreshButton()),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _createWarehouse() async {
    final form = await _openWarehouseFormDialog();
    if (form == null) return;

    setState(() => _saving = true);
    try {
      final response = await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>('/admin/warehouses', data: form.toJson());
      final createdId =
          response.data?['id']?.toString() ??
          response.data?['warehouseId']?.toString();
      if (createdId != null &&
          createdId.isNotEmpty &&
          AppEnv.firebaseStorageUploadsEnabled &&
          form.selectedPhoto != null) {
        await _uploadWarehousePhoto(createdId, form.selectedPhoto!);
      }
      _refreshWarehouseViews();
      _searchController.clear();
      ref.read(adminWarehouseSearchProvider.notifier).state = '';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('almacen_creado_correctamente'))),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _editWarehouse(AdminWarehouse warehouse) async {
    final form = await _openWarehouseFormDialog(initial: warehouse);
    if (form == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(dioProvider)
          .put<Map<String, dynamic>>(
            '/admin/warehouses/${warehouse.id}',
            data: form.toJson(),
          );
      if (AppEnv.firebaseStorageUploadsEnabled && form.selectedPhoto != null) {
        await _uploadWarehousePhoto(warehouse.id, form.selectedPhoto!);
      }
      _refreshWarehouseViews();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('almacen_actualizado_correctamente')),
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _uploadWarehousePhoto(
    String warehouseId,
    SelectedEvidenceImage image,
  ) async {
    await ref
        .read(dioProvider)
        .post<Map<String, dynamic>>(
          '/admin/warehouses/$warehouseId/photo',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(
              image.bytes,
              filename: image.filename,
              contentType: MediaType.parse(image.mimeType),
            ),
          }),
        );
  }

  Future<void> _deleteWarehouse(AdminWarehouse warehouse) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.t('desactivar_almacen')),
        content: Text(
          context.l10n.t('warehouse_deactivation_confirmation').replaceAll('{name}', warehouse.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.t('cancelar')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.t('desactivar')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(dioProvider)
          .delete<void>('/admin/warehouses/${warehouse.id}');
      _refreshWarehouseViews();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('almacen_desactivado_correctamente')),
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _reactivateWarehouse(AdminWarehouse warehouse) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(dioProvider)
          .put<Map<String, dynamic>>(
            '/admin/warehouses/${warehouse.id}',
            data: warehouse.copyWith(active: true).toFormData().toJson(),
          );
      _refreshWarehouseViews();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('almacen_reactivado_correctamente')),
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _refreshWarehouseViews() {
    ref.invalidate(adminWarehousesProvider);
    final currentVersion = ref.read(warehouseCatalogVersionProvider);
    ref.read(warehouseCatalogVersionProvider.notifier).state =
        currentVersion + 1;
  }

  Future<WarehouseFormData?> _openWarehouseFormDialog({
    AdminWarehouse? initial,
  }) async {
    return showDialog<WarehouseFormData>(
      context: context,
      builder: (context) => _WarehouseFormDialog(initial: initial),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = AppErrorFormatter.readable(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${context.l10n.t('admin_warehouses_operation_failed_prefix')}: '
          '$message',
        ),
      ),
    );
  }
}

class _WarehouseFormDialog extends ConsumerStatefulWidget {
  _WarehouseFormDialog({this.initial});

  final AdminWarehouse? initial;

  @override
  ConsumerState<_WarehouseFormDialog> createState() =>
      _WarehouseFormDialogState();
}

class _WarehouseFormDialogState extends ConsumerState<_WarehouseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _capacityController;
  late final TextEditingController _openHourController;
  late final TextEditingController _closeHourController;
  late final TextEditingController _rulesController;
  late final TextEditingController _pricePerHourSmallController;
  late final TextEditingController _pricePerHourMediumController;
  late final TextEditingController _pricePerHourLargeController;
  late final TextEditingController _pricePerHourExtraLargeController;
  late final TextEditingController _pickupFeeController;
  late final TextEditingController _dropoffFeeController;
  late final TextEditingController _insuranceFeeController;

  int? _selectedCityId;
  String? _selectedCityName;
  int? _selectedZoneId;
  SelectedEvidenceImage? _selectedPhoto;
  bool _active = true;
  bool _showValidation = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _addressController = TextEditingController(text: initial?.address ?? '');
    _latitudeController = TextEditingController(
      text: initial != null ? initial.latitude.toStringAsFixed(6) : '',
    );
    _longitudeController = TextEditingController(
      text: initial != null ? initial.longitude.toStringAsFixed(6) : '',
    );
    _capacityController = TextEditingController(
      text: initial != null ? '${initial.capacity}' : '',
    );
    _openHourController = TextEditingController(
      text: initial?.openHour ?? '08:00',
    );
    _closeHourController = TextEditingController(
      text: initial?.closeHour ?? '22:00',
    );
    _rulesController = TextEditingController(text: initial?.rules ?? '');
    _pricePerHourSmallController = TextEditingController(
      text: _formatMoneyInput(initial?.pricePerHourSmall ?? 4.0),
    );
    _pricePerHourMediumController = TextEditingController(
      text: _formatMoneyInput(initial?.pricePerHourMedium ?? 4.5),
    );
    _pricePerHourLargeController = TextEditingController(
      text: _formatMoneyInput(initial?.pricePerHourLarge ?? 5.5),
    );
    _pricePerHourExtraLargeController = TextEditingController(
      text: _formatMoneyInput(initial?.pricePerHourExtraLarge ?? 6.5),
    );
    _pickupFeeController = TextEditingController(
      text: _formatMoneyInput(initial?.pickupFee ?? 14.0),
    );
    _dropoffFeeController = TextEditingController(
      text: _formatMoneyInput(initial?.dropoffFee ?? 14.0),
    );
    _insuranceFeeController = TextEditingController(
      text: _formatMoneyInput(initial?.insuranceFee ?? 7.5),
    );

    _selectedCityId = initial?.cityId;
    _selectedCityName = initial?.cityName;
    _selectedZoneId = initial?.zoneId;
    _active = initial?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _capacityController.dispose();
    _openHourController.dispose();
    _closeHourController.dispose();
    _rulesController.dispose();
    _pricePerHourSmallController.dispose();
    _pricePerHourMediumController.dispose();
    _pricePerHourLargeController.dispose();
    _pricePerHourExtraLargeController.dispose();
    _pickupFeeController.dispose();
    _dropoffFeeController.dispose();
    _insuranceFeeController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (!AppEnv.firebaseStorageUploadsEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t('admin_warehouses_storage_not_available'),
          ),
        ),
      );
      return;
    }
    final image = await pickEvidenceImage();
    if (image == null) {
      if (!mounted || kIsWeb) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t('admin_warehouses_photo_upload_web_only'),
          ),
        ),
      );
      return;
    }
    setState(() => _selectedPhoto = image);
  }

  void _clearPhotoSelection() {
    if (_selectedPhoto == null) return;
    setState(() => _selectedPhoto = null);
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(adminCitiesProvider);
    final zonesAsync = ref.watch(adminZonesProvider(_selectedCityId ?? 0));
    final isEditing = widget.initial != null;
    final media = MediaQuery.of(context);
    final maxDialogWidth = media.size.width >= 760
        ? 560.0
        : media.size.width * 0.94;
    final maxDialogHeight = media.size.height * 0.78;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      title: Text(
        isEditing ? context.l10n.t('editar') : context.l10n.t('nuevo'),
      ),
      content: SizedBox(
        width: maxDialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDialogHeight),
          child: Form(
            key: _formKey,
            autovalidateMode: _showValidation
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (_formError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formError!,
                        style: const TextStyle(
                          color: Color(0xFF9E1B1B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                _WarehousePhotoPreview(
                  imageUrl: widget.initial?.imageUrl,
                  selectedBytes: _selectedPhoto?.bytes,
                  warehouseName: _nameController.text.trim().isEmpty
                      ? (widget.initial?.name ?? context.l10n.t('app_name'))
                      : _nameController.text.trim(),
                  cityName:
                      _selectedCityName ?? widget.initial?.cityName ?? context.l10n.t('peru'),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: AppEnv.firebaseStorageUploadsEnabled
                          ? _pickPhoto
                          : null,
                      icon: const Icon(Icons.photo_camera_back_outlined),
                      label: Text(
                        widget.initial?.imageUrl != null ||
                                _selectedPhoto != null
                            ? context.l10n.t('cambiar_foto')
                            : context.l10n.t('subir_foto'),
                      ),
                    ),
                    if (_selectedPhoto != null)
                      OutlinedButton.icon(
                        onPressed: _clearPhotoSelection,
                        icon: const Icon(Icons.close),
                        label: Text(context.l10n.t('quitar_seleccion')),
                      ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  AppEnv.firebaseStorageUploadsEnabled
                      ? context.l10n.t(
                          'admin_warehouses_photo_hint_storage_enabled',
                        )
                      : context.l10n.t(
                          'admin_warehouses_photo_hint_storage_disabled',
                        ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: context.l10n.t('admin_warehouses_name_label'),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final required = FormValidators.requiredText(
                      value,
                      label: context.l10n.t('warehouse_name_label'),
                      minLength: 4,
                    );
                    if (required != null) return required;
                    final text = value?.trim() ?? '';
                    if (text.length > 140) {
                      return context.l10n.t('admin_warehouses_name_too_long');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: context.l10n.t('admin_warehouses_address_label'),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final required = FormValidators.requiredText(
                      value,
                      label: context.l10n.t('address_label'),
                      minLength: 6,
                    );
                    if (required != null) return required;
                    final text = value?.trim() ?? '';
                    if (text.length > 220) {
                      return context.l10n.t(
                        'admin_warehouses_address_too_long',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                citiesAsync.when(
                  data: (cities) => DropdownButtonFormField<int>(
                    initialValue: _selectedCityId,
                    decoration: InputDecoration(
                      labelText: context.l10n.t('admin_warehouses_city_label'),
                    ),
                    items: cities
                        .map(
                          (city) => DropdownMenuItem<int>(
                            value: city.id,
                            child: Text(city.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCityId = value;
                        _selectedCityName = _findCity(cities, value)?.name;
                        _selectedZoneId = null;
                        _formError = null;
                        _applyCityCenterIfEmpty(_findCity(cities, value));
                      });
                    },
                    validator: (value) => value == null
                        ? context.l10n.t(
                            'admin_warehouses_select_city_required',
                          )
                        : null,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) =>
                      Text(context.l10n.t('no_se_pudieron_cargar_ciudades')),
                ),
                SizedBox(height: 10),
                zonesAsync.when(
                  data: (zones) => DropdownButtonFormField<int>(
                    initialValue: _selectedZoneId,
                    decoration: InputDecoration(
                      labelText: context.l10n.t(
                        'admin_warehouses_tourist_zone_optional',
                      ),
                    ),
                    items: zones
                        .map(
                          (zone) => DropdownMenuItem<int>(
                            value: zone.id,
                            child: Text(zone.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedZoneId = value;
                      _formError = null;
                      _applyZoneCenterIfEmpty(_findZone(zones, value));
                    }),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) =>
                      Text(context.l10n.t('no_se_pudieron_cargar_zonas')),
                ),
                SizedBox(height: 10),
                AdaptiveWrapGrid(
                  spacing: 10,
                  runSpacing: 10,
                  mobileColumns: 1,
                  tabletColumns: 2,
                  desktopSmallColumns: 2,
                  desktopColumns: 2,
                  minItemWidth: 170,
                  children: [
                    TextFormField(
                      controller: _latitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.l10n.t(
                          'admin_warehouses_latitude_label',
                        ),
                      ),
                      validator: FormValidators.latitude,
                    ),
                    TextFormField(
                      controller: _longitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.l10n.t(
                          'admin_warehouses_longitude_label',
                        ),
                      ),
                      validator: FormValidators.longitude,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                zonesAsync.when(
                  data: (zones) => citiesAsync.when(
                    data: (cities) {
                      final cityName =
                          _findCity(cities, _selectedCityId)?.name ?? context.l10n.t('peru');
                      final zoneName = _findZone(zones, _selectedZoneId)?.name;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => _openMapPicker(
                                  cityName: cityName,
                                  zoneName: zoneName,
                                  zones: zones,
                                ),
                                icon: const Icon(Icons.map_outlined),
                                label: Text(context.l10n.t('elegir_en_mapa')),
                              ),
                              if (_latitudeController.text.trim().isNotEmpty &&
                                  _longitudeController.text.trim().isNotEmpty)
                                Chip(
                                  label: Text(
                                    '${_latitudeController.text.trim()}, ${_longitudeController.text.trim()}',
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            context.l10n.t('admin_warehouses_map_helper'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 10),
                AdaptiveWrapGrid(
                  spacing: 10,
                  runSpacing: 10,
                  mobileColumns: 1,
                  tabletColumns: 2,
                  desktopSmallColumns: 3,
                  desktopColumns: 3,
                  minItemWidth: 150,
                  children: [
                    TextFormField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n.t(
                          'admin_warehouses_capacity_label',
                        ),
                      ),
                      validator: (value) => FormValidators.positiveInt(
                        value,
                        label: context.l10n.t('capacity_label'),
                      ),
                    ),
                    TextFormField(
                      controller: _openHourController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: context.l10n.t(
                          'admin_warehouses_opening_label',
                        ),
                      ),
                      validator: (value) =>
                          FormValidators.hour(value, label: context.l10n.t('opening_time_label')),
                    ),
                    TextFormField(
                      controller: _closeHourController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: context.l10n.t(
                          'admin_warehouses_closing_label',
                        ),
                      ),
                      validator: (value) {
                        final base = FormValidators.hour(
                          value,
                          label: context.l10n.t('closing_time_label'),
                        );
                        if (base != null) return base;
                        return FormValidators.hourRange(
                          _openHourController.text,
                          value,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.t('admin_warehouses_prices_panel_title'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AdaptiveWrapGrid(
                        spacing: 10,
                        runSpacing: 10,
                        mobileColumns: 1,
                        tabletColumns: 2,
                        desktopSmallColumns: 2,
                        desktopColumns: 3,
                        minItemWidth: 170,
                        children: [
                          _MoneyField(
                            controller: _pricePerHourSmallController,
                            label: context.l10n.t('admin_warehouses_rate_s_h'),
                          ),
                          _MoneyField(
                            controller: _pricePerHourMediumController,
                            label: context.l10n.t('admin_warehouses_rate_m_h'),
                          ),
                          _MoneyField(
                            controller: _pricePerHourLargeController,
                            label: context.l10n.t('admin_warehouses_rate_l_h'),
                          ),
                          _MoneyField(
                            controller: _pricePerHourExtraLargeController,
                            label: context.l10n.t('admin_warehouses_rate_xl_h'),
                          ),
                          _MoneyField(
                            controller: _pickupFeeController,
                            label: context.l10n.t(
                              'admin_warehouses_pickup_delivery_fee',
                            ),
                          ),
                          _MoneyField(
                            controller: _dropoffFeeController,
                            label: context.l10n.t(
                              'admin_warehouses_dropoff_delivery_fee',
                            ),
                          ),
                          _MoneyField(
                            controller: _insuranceFeeController,
                            label: context.l10n.t(
                              'admin_warehouses_additional_insurance',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _rulesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.l10n.t(
                      'admin_warehouses_rules_optional',
                    ),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length > 600) {
                      return context.l10n.t('admin_warehouses_rules_too_long');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  title: Text(context.l10n.t('activo')),
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
          onPressed: () {
            final isValid = _formKey.currentState!.validate();
            final cityId = _selectedCityId;
            final latitude = FormValidators.parseDouble(
              _latitudeController.text,
            );
            final longitude = FormValidators.parseDouble(
              _longitudeController.text,
            );
            final capacity = int.tryParse(_capacityController.text.trim());
            final hourRangeError = FormValidators.hourRange(
              _openHourController.text,
              _closeHourController.text,
            );
            final pricePerHourSmall = _parseNonNegativeMoney(
              _pricePerHourSmallController.text,
            );
            final pricePerHourMedium = _parseNonNegativeMoney(
              _pricePerHourMediumController.text,
            );
            final pricePerHourLarge = _parseNonNegativeMoney(
              _pricePerHourLargeController.text,
            );
            final pricePerHourExtraLarge = _parseNonNegativeMoney(
              _pricePerHourExtraLargeController.text,
            );
            final pickupFee = _parseNonNegativeMoney(_pickupFeeController.text);
            final dropoffFee = _parseNonNegativeMoney(
              _dropoffFeeController.text,
            );
            final insuranceFee = _parseNonNegativeMoney(
              _insuranceFeeController.text,
            );

            if (!isValid ||
                hourRangeError != null ||
                cityId == null ||
                latitude == null ||
                longitude == null ||
                capacity == null ||
                pricePerHourSmall == null ||
                pricePerHourMedium == null ||
                pricePerHourLarge == null ||
                pricePerHourExtraLarge == null ||
                pickupFee == null ||
                dropoffFee == null ||
                insuranceFee == null) {
              setState(() {
                _showValidation = true;
                _formError =
                    hourRangeError ??
                    context.l10n.t('admin_warehouses_price_validation_error');
              });
              return;
            }

            Navigator.of(context).pop(
              WarehouseFormData(
                cityId: cityId,
                zoneId: _selectedZoneId,
                name: _nameController.text.trim(),
                address: _addressController.text.trim(),
                imageUrl: widget.initial?.imageUrl,
                latitude: latitude,
                longitude: longitude,
                capacity: capacity,
                openHour: _openHourController.text.trim(),
                closeHour: _closeHourController.text.trim(),
                rules: _rulesController.text.trim(),
                active: _active,
                pricePerHourSmall: pricePerHourSmall,
                pricePerHourMedium: pricePerHourMedium,
                pricePerHourLarge: pricePerHourLarge,
                pricePerHourExtraLarge: pricePerHourExtraLarge,
                pickupFee: pickupFee,
                dropoffFee: dropoffFee,
                insuranceFee: insuranceFee,
                selectedPhoto: _selectedPhoto,
              ),
            );
          },
          child: Text(
            isEditing ? context.l10n.t('guardar') : context.l10n.t('crear'),
          ),
        ),
      ],
    );
  }

  double? _parseNonNegativeMoney(String raw) {
    final parsed = FormValidators.parseDouble(raw);
    if (parsed == null || parsed < 0) {
      return null;
    }
    return double.parse(parsed.toStringAsFixed(2));
  }

  String _formatMoneyInput(double value) {
    return value.toStringAsFixed(2);
  }

  Future<void> _openMapPicker({
    required String cityName,
    required String? zoneName,
    required List<ZoneOption> zones,
  }) async {
    if (_selectedCityId == null &&
        FormValidators.parseDouble(_latitudeController.text) == null &&
        FormValidators.parseDouble(_longitudeController.text) == null) {
      setState(() {
        _showValidation = true;
        _formError = context.l10n.t('admin_warehouses_select_city_before_map');
      });
      return;
    }

    final initialPoint = _resolveMapPoint(zones);
    final anchorPoint = _resolveAnchorPoint(zones);
    final selected = await showDialog<LatLng>(
      context: context,
      builder: (context) => WarehouseLocationPickerDialog(
        initialPoint: initialPoint,
        anchorPoint: anchorPoint,
        cityLabel: cityName,
        zoneLabel: zoneName,
      ),
    );
    if (selected == null) return;
    setState(() {
      _latitudeController.text = selected.latitude.toStringAsFixed(6);
      _longitudeController.text = selected.longitude.toStringAsFixed(6);
      _formError = null;
    });
  }

  LatLng _resolveMapPoint(List<ZoneOption> zones) {
    final latitude = FormValidators.parseDouble(_latitudeController.text);
    final longitude = FormValidators.parseDouble(_longitudeController.text);
    if (latitude != null && longitude != null) {
      return LatLng(latitude, longitude);
    }
    final zone = _findZone(zones, _selectedZoneId);
    if (zone?.latitude != null && zone?.longitude != null) {
      return LatLng(zone!.latitude!, zone.longitude!);
    }
    final cityCenter = _cityCenter(_selectedCityName);
    if (cityCenter != null) {
      return cityCenter;
    }
    return LatLng(-12.046374, -77.042793);
  }

  LatLng? _resolveAnchorPoint(List<ZoneOption> zones) {
    final zone = _findZone(zones, _selectedZoneId);
    if (zone?.latitude != null && zone?.longitude != null) {
      return LatLng(zone!.latitude!, zone.longitude!);
    }
    return _cityCenter(_selectedCityName);
  }

  void _applyZoneCenterIfEmpty(ZoneOption? zone) {
    if (zone?.latitude == null || zone?.longitude == null) {
      return;
    }
    if (_latitudeController.text.trim().isNotEmpty ||
        _longitudeController.text.trim().isNotEmpty) {
      return;
    }
    _latitudeController.text = zone!.latitude!.toStringAsFixed(6);
    _longitudeController.text = zone.longitude!.toStringAsFixed(6);
  }

  void _applyCityCenterIfEmpty(CityOption? city) {
    final center = _cityCenter(city?.name);
    if (center == null) return;
    if (_latitudeController.text.trim().isNotEmpty ||
        _longitudeController.text.trim().isNotEmpty) {
      return;
    }
    _latitudeController.text = center.latitude.toStringAsFixed(6);
    _longitudeController.text = center.longitude.toStringAsFixed(6);
  }

  CityOption? _findCity(List<CityOption> cities, int? cityId) {
    if (cityId == null) return null;
    for (final city in cities) {
      if (city.id == cityId) return city;
    }
    return null;
  }

  ZoneOption? _findZone(List<ZoneOption> zones, int? zoneId) {
    if (zoneId == null) return null;
    for (final zone in zones) {
      if (zone.id == zoneId) return zone;
    }
    return null;
  }

  LatLng? _cityCenter(String? cityName) {
    if (cityName == null || cityName.trim().isEmpty) return null;
    return _peruCityCenters[cityName.trim().toLowerCase()];
  }
}

class _WarehousePhotoPreview extends StatelessWidget {
  const _WarehousePhotoPreview({
    this.imageUrl,
    this.selectedBytes,
    required this.warehouseName,
    required this.cityName,
  });

  final String? imageUrl;
  final Uint8List? selectedBytes;
  final String warehouseName;
  final String cityName;

  @override
  Widget build(BuildContext context) {
    const previewHeight = 180.0;
    final fallback = Container(
      height: previewHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F6E8C), Color(0xFF65A6B9), Color(0xFFE9C07C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              warehouseName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Text(
            cityName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.t('admin_warehouses_auto_cover_by_city'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );

    Widget child;
    if (selectedBytes != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          selectedBytes!,
          height: previewHeight,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } else {
      child = AppSmartImage(
        source: imageUrl,
        height: previewHeight,
        width: double.infinity,
        borderRadius: BorderRadius.circular(16),
        fallback: fallback,
      );
    }

    return SizedBox(
      height: previewHeight,
      width: double.infinity,
      child: child,
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({
    required this.title,
    required this.value,
    required this.colorA,
    required this.colorB,
  });

  final String title;
  final String value;
  final Color colorA;
  final Color colorB;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colorA, colorB]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: 'S/ '),
      validator: (value) {
        final parsed = FormValidators.parseDouble(value);
        if (parsed == null) {
          return context.l10n.t('admin_warehouses_invalid_amount');
        }
        if (parsed < 0) {
          return context.l10n.t('admin_warehouses_amount_non_negative');
        }
        return null;
      },
    );
  }
}

class _WarehouseRegistryTable extends StatefulWidget {
  const _WarehouseRegistryTable({
    required this.items,
    required this.saving,
    required this.onEdit,
    required this.onToggleActive,
  });

  final List<AdminWarehouse> items;
  final bool saving;
  final Future<void> Function(AdminWarehouse warehouse) onEdit;
  final Future<void> Function(AdminWarehouse warehouse) onToggleActive;

  @override
  State<_WarehouseRegistryTable> createState() =>
      _WarehouseRegistryTableState();
}

class _WarehouseRegistryTableState extends State<_WarehouseRegistryTable> {
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsive.cardPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final table = DataTable(
              columnSpacing: compact ? 16 : 22,
              horizontalMargin: compact ? 10 : 12,
              dataRowMinHeight: compact ? 44 : 48,
              dataRowMaxHeight: compact ? 58 : 62,
              columns: [
                const DataColumn(label: SizedBox.shrink()),
                DataColumn(label: Text(context.l10n.t('id'))),
                DataColumn(label: Text(context.l10n.t('almacen'))),
                DataColumn(label: Text(context.l10n.t('ciudad'))),
                DataColumn(label: Text(context.l10n.t('mh'))),
                DataColumn(label: Text(context.l10n.t('recojo'))),
                DataColumn(label: Text(context.l10n.t('entrega'))),
                DataColumn(label: Text(context.l10n.t('seguro'))),
                DataColumn(label: Text(context.l10n.t('cap'))),
                DataColumn(label: Text(context.l10n.t('ocup'))),
                DataColumn(label: Text(context.l10n.t('disp'))),
                DataColumn(label: Text(context.l10n.t('lat'))),
                DataColumn(label: Text(context.l10n.t('lng'))),
                DataColumn(label: Text(context.l10n.t('estado'))),
              ],
              rows: widget.items
                  .map(
                    (item) => DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: widget.saving
                                    ? null
                                    : () => widget.onEdit(item),
                                tooltip: context.l10n.t('editar'),
                                icon: const Icon(Icons.edit_outlined),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: widget.saving
                                    ? null
                                    : () => widget.onToggleActive(item),
                                tooltip: item.active
                                    ? context.l10n.t('desactivar')
                                    : null,
                                icon: Icon(
                                  item.active
                                      ? Icons.delete_outline
                                      : Icons.restart_alt_outlined,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text(item.id)),
                        DataCell(Text(item.name)),
                        DataCell(
                          Text('${item.cityName}/${item.zoneName ?? '-'}'),
                        ),
                        DataCell(
                          Text(
                            'S/${item.pricePerHourMedium.toStringAsFixed(2)}',
                          ),
                        ),
                        DataCell(
                          Text('S/${item.pickupFee.toStringAsFixed(2)}'),
                        ),
                        DataCell(
                          Text('S/${item.dropoffFee.toStringAsFixed(2)}'),
                        ),
                        DataCell(
                          Text('S/${item.insuranceFee.toStringAsFixed(2)}'),
                        ),
                        DataCell(Text('${item.capacity}')),
                        DataCell(Text('${item.occupied}')),
                        DataCell(Text('${item.available}')),
                        DataCell(Text(item.latitude.toStringAsFixed(5))),
                        DataCell(Text(item.longitude.toStringAsFixed(5))),
                        DataCell(
                          Chip(
                            label: Text(
                              item.active
                                  ? context.l10n.t(
                                      'admin_warehouses_status_active',
                                    )
                                  : context.l10n.t(
                                      'admin_warehouses_status_inactive',
                                    ),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('admin_warehouses_registry_board'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: responsive.itemGap / 2),
                Text(
                  context.l10n.t('admin_warehouses_swipe_right_hint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(height: responsive.itemGap),
                Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: table,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CityOption {
  const CityOption({required this.id, required this.name});

  final int id;
  final String name;

  factory CityOption.fromJson(Map<String, dynamic> json) {
    return CityOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

const Map<String, LatLng> _peruCityCenters = {
  'lima': LatLng(-12.046374, -77.042793),
  'cusco': LatLng(-13.53195, -71.967463),
  'arequipa': LatLng(-16.398866, -71.536961),
  'ica': LatLng(-14.06777, -75.72861),
  'puno': LatLng(-15.840221, -70.021881),
  'paracas': LatLng(-13.836423, -76.251228),
  'nazca': LatLng(-14.833284, -74.938774),
  'trujillo': LatLng(-8.111763, -79.028687),
  'piura': LatLng(-5.19449, -80.63282),
  'mancora': LatLng(-4.10695, -81.05108),
};

class ZoneOption {
  const ZoneOption({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.radiusKm,
  });

  final int id;
  final String name;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;

  factory ZoneOption.fromJson(Map<String, dynamic> json) {
    return ZoneOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radiusKm: (json['radiusKm'] as num?)?.toDouble(),
    );
  }
}

class AdminWarehouse {
  const AdminWarehouse({
    required this.id,
    required this.name,
    required this.address,
    required this.imageUrl,
    required this.cityId,
    required this.cityName,
    required this.zoneId,
    required this.zoneName,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.occupied,
    required this.available,
    required this.openHour,
    required this.closeHour,
    required this.rules,
    required this.active,
    required this.pricePerHourSmall,
    required this.pricePerHourMedium,
    required this.pricePerHourLarge,
    required this.pricePerHourExtraLarge,
    required this.pickupFee,
    required this.dropoffFee,
    required this.insuranceFee,
  });

  final String id;
  final String name;
  final String address;
  final String? imageUrl;
  final int cityId;
  final String cityName;
  final int? zoneId;
  final String? zoneName;
  final double latitude;
  final double longitude;
  final int capacity;
  final int occupied;
  final int available;
  final String openHour;
  final String closeHour;
  final String? rules;
  final bool active;
  final double pricePerHourSmall;
  final double pricePerHourMedium;
  final double pricePerHourLarge;
  final double pricePerHourExtraLarge;
  final double pickupFee;
  final double dropoffFee;
  final double insuranceFee;

  WarehouseFormData toFormData() {
    return WarehouseFormData(
      cityId: cityId,
      zoneId: zoneId,
      name: name,
      address: address,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      capacity: capacity,
      openHour: openHour,
      closeHour: closeHour,
      rules: rules ?? '',
      active: active,
      pricePerHourSmall: pricePerHourSmall,
      pricePerHourMedium: pricePerHourMedium,
      pricePerHourLarge: pricePerHourLarge,
      pricePerHourExtraLarge: pricePerHourExtraLarge,
      pickupFee: pickupFee,
      dropoffFee: dropoffFee,
      insuranceFee: insuranceFee,
      selectedPhoto: null,
    );
  }

  AdminWarehouse copyWith({bool? active}) {
    return AdminWarehouse(
      id: id,
      name: name,
      address: address,
      imageUrl: imageUrl,
      cityId: cityId,
      cityName: cityName,
      zoneId: zoneId,
      zoneName: zoneName,
      latitude: latitude,
      longitude: longitude,
      capacity: capacity,
      occupied: occupied,
      available: available,
      openHour: openHour,
      closeHour: closeHour,
      rules: rules,
      active: active ?? this.active,
      pricePerHourSmall: pricePerHourSmall,
      pricePerHourMedium: pricePerHourMedium,
      pricePerHourLarge: pricePerHourLarge,
      pricePerHourExtraLarge: pricePerHourExtraLarge,
      pickupFee: pickupFee,
      dropoffFee: dropoffFee,
      insuranceFee: insuranceFee,
    );
  }

  factory AdminWarehouse.fromJson(Map<String, dynamic> json) {
    return AdminWarehouse(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      imageUrl: _readWarehouseImageUrl(json),
      cityId: (json['cityId'] as num?)?.toInt() ?? 0,
      cityName: json['cityName']?.toString() ?? '',
      zoneId: (json['zoneId'] as num?)?.toInt(),
      zoneName: json['zoneName']?.toString(),
      latitude:
          (json['latitude'] as num?)?.toDouble() ??
          (json['lat'] as num?)?.toDouble() ??
          0,
      longitude:
          (json['longitude'] as num?)?.toDouble() ??
          (json['lng'] as num?)?.toDouble() ??
          0,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      occupied: (json['occupied'] as num?)?.toInt() ?? 0,
      available:
          (json['available'] as num?)?.toInt() ??
          (json['availableSlots'] as num?)?.toInt() ??
          0,
      openHour: json['openHour']?.toString() ?? '08:00',
      closeHour: json['closeHour']?.toString() ?? '22:00',
      rules: json['rules']?.toString(),
      active: json['active'] as bool? ?? true,
      pricePerHourSmall:
          (json['pricePerHourSmall'] as num?)?.toDouble() ??
          (json['priceFromPerHour'] as num?)?.toDouble() ??
          4.0,
      pricePerHourMedium:
          (json['pricePerHourMedium'] as num?)?.toDouble() ??
          (json['priceFromPerHour'] as num?)?.toDouble() ??
          4.5,
      pricePerHourLarge:
          (json['pricePerHourLarge'] as num?)?.toDouble() ??
          (json['priceFromPerHour'] as num?)?.toDouble() ??
          5.5,
      pricePerHourExtraLarge:
          (json['pricePerHourExtraLarge'] as num?)?.toDouble() ??
          (json['priceFromPerHour'] as num?)?.toDouble() ??
          6.5,
      pickupFee:
          (json['pickupFee'] as num?)?.toDouble() ??
          (json['pickupDeliveryFee'] as num?)?.toDouble() ??
          14.0,
      dropoffFee:
          (json['dropoffFee'] as num?)?.toDouble() ??
          (json['dropoffDeliveryFee'] as num?)?.toDouble() ??
          14.0,
      insuranceFee: (json['insuranceFee'] as num?)?.toDouble() ?? 7.5,
    );
  }
}

class WarehouseFormData {
  const WarehouseFormData({
    required this.cityId,
    required this.zoneId,
    required this.name,
    required this.address,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.openHour,
    required this.closeHour,
    required this.rules,
    required this.active,
    required this.pricePerHourSmall,
    required this.pricePerHourMedium,
    required this.pricePerHourLarge,
    required this.pricePerHourExtraLarge,
    required this.pickupFee,
    required this.dropoffFee,
    required this.insuranceFee,
    required this.selectedPhoto,
  });

  final int cityId;
  final int? zoneId;
  final String name;
  final String address;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final int capacity;
  final String openHour;
  final String closeHour;
  final String rules;
  final bool active;
  final double pricePerHourSmall;
  final double pricePerHourMedium;
  final double pricePerHourLarge;
  final double pricePerHourExtraLarge;
  final double pickupFee;
  final double dropoffFee;
  final double insuranceFee;
  final SelectedEvidenceImage? selectedPhoto;

  Map<String, dynamic> toJson() {
    return {
      'cityId': cityId,
      'zoneId': zoneId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'lat': latitude,
      'lng': longitude,
      'capacity': capacity,
      'openHour': openHour,
      'closeHour': closeHour,
      'rules': rules,
      'active': active,
      'pricePerHourSmall': pricePerHourSmall,
      'pricePerHourMedium': pricePerHourMedium,
      'pricePerHourLarge': pricePerHourLarge,
      'pricePerHourExtraLarge': pricePerHourExtraLarge,
      'pickupFee': pickupFee,
      'dropoffFee': dropoffFee,
      'insuranceFee': insuranceFee,
    };
  }
}

String? _readWarehouseImageUrl(Map<String, dynamic> json) {
  const keys = ['coverImageUrl', 'imageUrl', 'photoUrl', 'image', 'imagen'];
  for (final key in keys) {
    final value = json[key]?.toString();
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/form_validators.dart';
import '../../incidents/data/selected_evidence_image.dart';

final adminUsersAppliedSearchProvider = StateProvider<String>((ref) => '');
final adminUsersAppliedRoleProvider = StateProvider<String>((ref) => 'ALL');
final adminUsersLatestOnlyProvider = StateProvider<bool>((ref) => true);
final adminUsersLoadRequestedProvider = StateProvider<bool>((ref) => false);

final adminUsersProvider = FutureProvider<List<AdminUserItem>>((ref) async {
  final shouldLoad = ref.watch(adminUsersLoadRequestedProvider);
  if (!shouldLoad) {
    return const [];
  }
  final dio = ref.read(dioProvider);
  final query = ref.watch(adminUsersAppliedSearchProvider).trim();
  final role = ref.watch(adminUsersAppliedRoleProvider);
  final latestOnly = ref.watch(adminUsersLatestOnlyProvider);
  final response = await dio.get<List<dynamic>>(
    '/admin/users',
    queryParameters: {
      if (query.isNotEmpty) 'query': query,
      if (role != 'ALL') 'role': role,
      if (latestOnly) 'latestOnly': true,
      if (latestOnly) 'limit': 1,
    },
  );
  return (response.data ?? const [])
      .map((item) => AdminUserItem.fromJson(item as Map<String, dynamic>))
      .toList();
});

final adminUsersSummaryProvider = FutureProvider<AdminUsersSummaryData?>((
  ref,
) async {
  final shouldLoad = ref.watch(adminUsersLoadRequestedProvider);
  if (!shouldLoad) {
    return null;
  }
  final dio = ref.read(dioProvider);
  final query = ref.watch(adminUsersAppliedSearchProvider).trim();
  final role = ref.watch(adminUsersAppliedRoleProvider);
  final response = await dio.get<Map<String, dynamic>>(
    '/admin/users/summary',
    queryParameters: {
      if (query.isNotEmpty) 'query': query,
      if (role != 'ALL') 'role': role,
    },
  );
  final data = response.data;
  if (data == null) {
    return null;
  }
  return AdminUsersSummaryData.fromJson(data);
});

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final _searchController = TextEditingController();
  Timer? _filterApplyDebounce;
  bool _saving = false;
  String _draftRole = 'ALL';
  bool _draftLatestOnly = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _applyUserFilters();
    });
  }

  @override
  void dispose() {
    _filterApplyDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final itemGap = responsive.itemGap;
    final sectionGap = responsive.sectionGap;
    final usersAsync = ref.watch(adminUsersProvider);
    final summaryAsync = ref.watch(adminUsersSummaryProvider);
    final loadRequested = ref.watch(adminUsersLoadRequestedProvider);

    return AppShellScaffold(
      title: 'Usuarios operativos',
      currentRoute: '/admin/users',
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.horizontalPadding,
              responsive.verticalPadding,
              responsive.horizontalPadding,
              0,
            ),
            child: Wrap(
              spacing: itemGap,
              runSpacing: itemGap,
              children: [
                SizedBox(
                  width: responsive.isMobile ? double.infinity : 360,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _scheduleFilterApplyFromTyping(),
                    onSubmitted: (_) => _applyUserFilters(),
                    decoration: const InputDecoration(
                      labelText: 'Buscar usuario, correo o telefono',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _draftRole,
                  items: [
                    DropdownMenuItem(
                      value: 'ALL',
                      child: Text(context.l10n.t('todos')),
                    ),
                    DropdownMenuItem(
                      value: 'CLIENT',
                      child: Text(context.l10n.t('client')),
                    ),
                    DropdownMenuItem(
                      value: 'COURIER',
                      child: Text(context.l10n.t('courier')),
                    ),
                    DropdownMenuItem(
                      value: 'OPERATOR',
                      child: Text(context.l10n.t('operator')),
                    ),
                    DropdownMenuItem(
                      value: 'CITY_SUPERVISOR',
                      child: Text(context.l10n.t('citysupervisor')),
                    ),
                    DropdownMenuItem(
                      value: 'SUPPORT',
                      child: Text(context.l10n.t('support')),
                    ),
                    DropdownMenuItem(
                      value: 'ADMIN',
                      child: Text(context.l10n.t('admin')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _draftRole = value);
                      _maybeApplyFiltersAfterFirstLoad();
                    }
                  },
                ),
                ChoiceChip(
                  label: Text(context.l10n.t('solo_ultimo_registro')),
                  selected: _draftLatestOnly,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    setState(() => _draftLatestOnly = true);
                    _maybeApplyFiltersAfterFirstLoad();
                  },
                ),
                ChoiceChip(
                  label: Text(context.l10n.t('todos_los_registros')),
                  selected: !_draftLatestOnly,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    setState(() => _draftLatestOnly = false);
                    _maybeApplyFiltersAfterFirstLoad();
                  },
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _applyUserFilters,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(Icons.filter_alt_outlined),
                  label: Text(context.l10n.t('ver_usuarios')),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _openCreateDialog(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(Icons.person_add_alt_1_outlined),
                  label: Text(context.l10n.t('nuevo_usuario')),
                ),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () =>
                            _openCreateDialog(presetRoles: const {'OPERATOR'}),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(Icons.badge_outlined),
                  label: Text(context.l10n.t('nuevo_operador')),
                ),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _openCreateDialog(presetRoles: const {'COURIER'}),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(Icons.delivery_dining_outlined),
                  label: Text(context.l10n.t('nuevo_courier')),
                ),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : loadRequested
                      ? _reloadUsers
                      : _applyUserFilters,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(Icons.refresh),
                  label: Text(context.l10n.t('recargar')),
                ),
              ],
            ),
          ),
          SizedBox(height: itemGap),
          Expanded(
            child: usersAsync.when(
              data: (items) {
                if (!loadRequested) {
                  return EmptyStateView(
                    message:
                        'Presiona "Ver usuarios" para cargar segun tu filtro.',
                    actionLabel: 'Cargar ahora',
                    onAction: _applyUserFilters,
                  );
                }
                if (items.isEmpty) {
                  return const EmptyStateView(
                    message: 'No hay usuarios para este filtro.',
                  );
                }
                return ListView(
                  padding: responsive.pageInsets(top: 0, bottom: sectionGap),
                  children: [
                    _AdminUsersSummary(
                      items: items,
                      summary: summaryAsync.asData?.value,
                    ),
                    SizedBox(height: sectionGap),
                    ...items.map(
                      (user) => Padding(
                        padding: EdgeInsets.only(bottom: itemGap),
                        child: _AdminUserCard(
                          user: user,
                          saving: _saving,
                          onToggleActive: (value) => _toggleActive(user, value),
                          onEdit: () => _openEditDialog(user),
                          onPassword: () => _openPasswordDialog(user),
                          onDelete: () => _deleteUser(user),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LoadingStateView(),
              error: (error, _) => ErrorStateView(
                message:
                    'No se pudieron cargar usuarios: ${AppErrorFormatter.readable(error)}',
                onRetry: () => ref.invalidate(adminUsersProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyUserFilters() {
    ref.read(adminUsersAppliedSearchProvider.notifier).state = _searchController
        .text
        .trim();
    ref.read(adminUsersAppliedRoleProvider.notifier).state = _draftRole;
    ref.read(adminUsersLatestOnlyProvider.notifier).state = _draftLatestOnly;
    ref.read(adminUsersLoadRequestedProvider.notifier).state = true;
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminUsersSummaryProvider);
  }

  void _reloadUsers() {
    if (!ref.read(adminUsersLoadRequestedProvider)) {
      _applyUserFilters();
      return;
    }
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminUsersSummaryProvider);
  }

  void _maybeApplyFiltersAfterFirstLoad() {
    if (!ref.read(adminUsersLoadRequestedProvider)) {
      return;
    }
    _applyUserFilters();
  }

  void _scheduleFilterApplyFromTyping() {
    if (!ref.read(adminUsersLoadRequestedProvider)) {
      return;
    }
    _filterApplyDebounce?.cancel();
    _filterApplyDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _applyUserFilters();
    });
  }

  Future<void> _toggleActive(AdminUserItem user, bool active) async {
    if (user.isAdmin && !active) {
      _showSnack('Un usuario ADMIN no puede quedar inactivo.', isError: true);
      return;
    }
    await _runAdminAction(() async {
      await ref
          .read(dioProvider)
          .patch<Map<String, dynamic>>(
            '/admin/users/${user.id}/active',
            data: {'active': active},
          );
    }, successMessage: active ? 'Usuario activado.' : 'Usuario desactivado.');
  }

  Future<void> _openCreateDialog({Set<String> presetRoles = const {}}) async {
    final warehouseOptions = await _loadWarehouseOptions();
    if (!mounted) return;
    final payload = await showDialog<_AdminUserFormData>(
      context: context,
      builder: (context) => _AdminUserFormDialog(
        title: 'Crear usuario operativo',
        submitLabel: 'Crear usuario',
        presetRoles: presetRoles,
        includePassword: true,
        warehouseOptions: warehouseOptions,
      ),
    );
    if (payload == null) {
      return;
    }
    await _runAdminAction(() async {
      String? uploadedDocumentPhotoPath = payload.documentPhotoPath;
      if (payload.documentPhotoFile != null) {
        uploadedDocumentPhotoPath = await _uploadDocumentPhoto(
          payload.documentPhotoFile!,
        );
      }
      await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>(
            '/admin/users',
            data: payload.toCreatePayload(
              uploadedDocumentPhotoPath: uploadedDocumentPhotoPath,
            ),
          );
    }, successMessage: 'Usuario creado correctamente.');
  }

  Future<void> _openEditDialog(AdminUserItem user) async {
    final warehouseOptions = await _loadWarehouseOptions();
    if (!mounted) return;
    final payload = await showDialog<_AdminUserFormData>(
      context: context,
      builder: (context) => _AdminUserFormDialog(
        title: 'Editar usuario',
        submitLabel: 'Guardar cambios',
        initialUser: user,
        warehouseOptions: warehouseOptions,
      ),
    );
    if (payload == null) {
      return;
    }
    await _runAdminAction(() async {
      String? uploadedDocumentPhotoPath = payload.documentPhotoPath;
      if (payload.documentPhotoFile != null) {
        uploadedDocumentPhotoPath = await _uploadDocumentPhoto(
          payload.documentPhotoFile!,
        );
      }
      await ref
          .read(dioProvider)
          .put<Map<String, dynamic>>(
            '/admin/users/${user.id}',
            data: payload.toUpdatePayload(
              uploadedDocumentPhotoPath: uploadedDocumentPhotoPath,
            ),
          );
    }, successMessage: 'Usuario actualizado.');
  }

  Future<void> _openPasswordDialog(AdminUserItem user) async {
    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => _PasswordDialog(user: user),
    );
    if (newPassword == null) {
      return;
    }
    await _runAdminAction(() async {
      await ref
          .read(dioProvider)
          .patch<Map<String, dynamic>>(
            '/admin/users/${user.id}/password',
            data: {'password': newPassword},
          );
    }, successMessage: 'Credenciales actualizadas.');
  }

  Future<void> _deleteUser(AdminUserItem user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.t('eliminar_usuario')),
        content: Text(
          'Se eliminara ${user.fullName}. Si ya tiene operaciones vinculadas, el sistema bloqueara la eliminacion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.t('cancelar')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.t('eliminar')),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _runAdminAction(() async {
      await ref.read(dioProvider).delete<void>('/admin/users/${user.id}');
    }, successMessage: 'Usuario eliminado.');
  }

  Future<String> _uploadDocumentPhoto(SelectedEvidenceImage file) async {
    final contentType = MediaType.parse(file.mimeType);
    final response = await ref
        .read(dioProvider)
        .post<Map<String, dynamic>>(
          '/admin/users/document-photo',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(
              file.bytes,
              filename: file.filename,
              contentType: contentType,
            ),
          }),
        );
    final data = response.data ?? const <String, dynamic>{};
    final url = data['url']?.toString().trim() ?? '';
    if (url.isEmpty) {
      throw StateError('No se recibio URL de la foto de documento.');
    }
    return url;
  }

  Future<void> _runAdminAction(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    setState(() => _saving = true);
    try {
      await operation();
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminUsersSummaryProvider);
      _showSnack(successMessage);
    } catch (error) {
      _showSnack(AppErrorFormatter.readable(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Color(0xFFC43D3D) : null,
      ),
    );
  }

  Future<List<_AdminWarehouseOption>> _loadWarehouseOptions() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get<List<dynamic>>(
            '/admin/warehouses',
            queryParameters: {'active': true},
          );
      return (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_AdminWarehouseOption.fromJson)
          .where((warehouse) => warehouse.id > 0)
          .toList()
        ..sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );
    } catch (error) {
      _showSnack(
        'No se pudo cargar sedes: ${AppErrorFormatter.readable(error)}',
        isError: true,
      );
      return const [];
    }
  }
}

class _AdminUsersSummary extends StatelessWidget {
  const _AdminUsersSummary({required this.items, this.summary});

  final List<AdminUserItem> items;
  final AdminUsersSummaryData? summary;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final totalUsers = summary?.totalUsers ?? items.length;
    final activeCount =
        summary?.activeUsers ?? items.where((item) => item.active).length;
    final operatorCount =
        summary?.operatorUsers ?? items.where((item) => item.isOperator).length;
    final courierCount =
        summary?.courierUsers ?? items.where((item) => item.isCourier).length;
    final completedDeliveries =
        summary?.completedDeliveries ??
        items.fold<int>(0, (sum, item) => sum + item.deliveryCompletedCount);

    return Wrap(
      spacing: responsive.itemGap,
      runSpacing: responsive.itemGap,
      children: [
        _SummaryCard(title: 'Usuarios', value: '$totalUsers'),
        _SummaryCard(title: 'Activos', value: '$activeCount'),
        _SummaryCard(title: 'Operadores', value: '$operatorCount'),
        _SummaryCard(title: 'Couriers', value: '$courierCount'),
        _SummaryCard(
          title: 'Entregas completadas',
          value: '$completedDeliveries',
        ),
        if (summary != null && items.isNotEmpty && totalUsers > items.length)
          _SummaryCard(
            title: 'Mostrando',
            value: '${items.length} de $totalUsers',
          ),
      ],
    );
  }
}

class AdminUsersSummaryData {
  const AdminUsersSummaryData({
    required this.totalUsers,
    required this.activeUsers,
    required this.operatorUsers,
    required this.courierUsers,
    required this.completedDeliveries,
  });

  final int totalUsers;
  final int activeUsers;
  final int operatorUsers;
  final int courierUsers;
  final int completedDeliveries;

  factory AdminUsersSummaryData.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) => (value as num?)?.toInt() ?? 0;
    return AdminUsersSummaryData(
      totalUsers: asInt(json['totalUsers']),
      activeUsers: asInt(json['activeUsers']),
      operatorUsers: asInt(json['operatorUsers']),
      courierUsers: asInt(json['courierUsers']),
      completedDeliveries: asInt(json['completedDeliveries']),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final width = responsive.isMobile ? 150.0 : 180.0;
    final height = responsive.isMobile ? 96.0 : 108.0;
    return SizedBox(
      width: width,
      child: SizedBox(
        height: height,
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(responsive.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  const _AdminUserCard({
    required this.user,
    required this.saving,
    required this.onToggleActive,
    required this.onEdit,
    required this.onPassword,
    required this.onDelete,
  });

  final AdminUserItem user;
  final bool saving;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onPassword;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final itemGap = responsive.itemGap;
    final sectionGap = responsive.sectionGap;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsive.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: itemGap / 2),
                      Text(user.email),
                      Text(user.phone),
                    ],
                  ),
                ),
                Tooltip(
                  message: user.isAdmin
                      ? 'ADMIN no se puede desactivar.'
                      : 'Cambiar estado del usuario',
                  child: Switch(
                    value: user.active,
                    onChanged: (saving || user.isAdmin) ? null : onToggleActive,
                  ),
                ),
              ],
            ),
            SizedBox(height: itemGap),
            Wrap(
              spacing: itemGap,
              runSpacing: itemGap,
              children: [
                ...user.roles.map(
                  (role) => Chip(
                    label: Text(role),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Chip(
                  label: Text('Auth ${user.authProvider}'),
                  visualDensity: VisualDensity.compact,
                ),
                if (user.managedByAdmin)
                  Chip(
                    label: Text(context.l10n.t('gestionado_por_admin')),
                    visualDensity: VisualDensity.compact,
                  ),
                if (user.preferredLanguage.isNotEmpty)
                  Chip(
                    label: Text('Idioma ${user.preferredLanguage}'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (user.nationality.isNotEmpty)
                  Chip(
                    label: Text(user.nationality),
                    visualDensity: VisualDensity.compact,
                  ),
                if (user.documentNumber?.trim().isNotEmpty == true)
                  Chip(
                    avatar: Icon(Icons.badge_outlined, size: 16),
                    label: Text(
                      '${user.documentType ?? 'DOC'} ${user.documentNumber}',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (user.documentPhotoPath?.trim().isNotEmpty == true)
                  Chip(
                    avatar: Icon(Icons.photo_camera_outlined, size: 16),
                    label: Text(context.l10n.t('foto_dni_adjunta')),
                    visualDensity: VisualDensity.compact,
                  ),
                if (user.vehiclePlate?.trim().isNotEmpty == true)
                  Chip(
                    avatar: Icon(Icons.local_shipping_outlined, size: 16),
                    label: Text('Placa ${user.vehiclePlate}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ...user.warehouseNames.map(
                  (warehouseName) => Chip(
                    avatar: const Icon(
                      Icons.store_mall_directory_outlined,
                      size: 16,
                    ),
                    label: Text(warehouseName),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (user.requiresWarehouseScope && user.warehouseNames.isEmpty)
                  Chip(
                    backgroundColor: Color(0xFFFFE4E4),
                    label: Text(context.l10n.t('sin_sede_asignada')),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            SizedBox(height: itemGap),
            Wrap(
              spacing: itemGap,
              runSpacing: itemGap,
              children: [
                if (user.deliveryCreatedCount > 0)
                  _MetricBadge(
                    icon: Icons.add_task_outlined,
                    label: 'Servicios creados ${user.deliveryCreatedCount}',
                  ),
                if (user.deliveryAssignedCount > 0)
                  _MetricBadge(
                    icon: Icons.assignment_ind_outlined,
                    label: 'Asignados ${user.deliveryAssignedCount}',
                  ),
                if (user.deliveryCompletedCount > 0)
                  _MetricBadge(
                    icon: Icons.check_circle_outline,
                    label: 'Completados ${user.deliveryCompletedCount}',
                  ),
                if (user.activeDeliveryCount > 0)
                  _MetricBadge(
                    icon: Icons.route_outlined,
                    label: 'Activos ${user.activeDeliveryCount}',
                  ),
              ],
            ),
            SizedBox(height: sectionGap),
            Wrap(
              spacing: itemGap,
              runSpacing: itemGap,
              children: [
                OutlinedButton.icon(
                  onPressed: saving ? null : onEdit,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.l10n.t('editar_ficha')),
                ),
                OutlinedButton.icon(
                  onPressed: saving ? null : onPassword,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(Icons.lock_reset_outlined),
                  label: Text(context.l10n.t('credenciales')),
                ),
                Tooltip(
                  message: user.isAdmin
                      ? 'ADMIN no se puede eliminar desde este panel.'
                      : 'Eliminar usuario',
                  child: OutlinedButton.icon(
                    onPressed: (saving || user.isAdmin) ? null : onDelete,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(Icons.delete_outline),
                    label: Text(context.l10n.t('eliminar')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1F6E8C)),
          SizedBox(width: responsive.itemGap / 1.5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AdminUserFormDialog extends StatefulWidget {
  const _AdminUserFormDialog({
    required this.title,
    required this.submitLabel,
    required this.warehouseOptions,
    this.initialUser,
    this.presetRoles = const {},
    this.includePassword = false,
  });

  final String title;
  final String submitLabel;
  final List<_AdminWarehouseOption> warehouseOptions;
  final AdminUserItem? initialUser;
  final Set<String> presetRoles;
  final bool includePassword;

  @override
  State<_AdminUserFormDialog> createState() => _AdminUserFormDialogState();
}

class _AdminUserFormDialogState extends State<_AdminUserFormDialog> {
  static const _roles = <String>[
    'CLIENT',
    'COURIER',
    'OPERATOR',
    'CITY_SUPERVISOR',
    'SUPPORT',
    'ADMIN',
  ];
  static const _warehouseScopedRoles = <String>{
    'COURIER',
    'OPERATOR',
    'CITY_SUPERVISOR',
    'SUPPORT',
  };
  static const _workerRoles = <String>{
    'COURIER',
    'OPERATOR',
    'CITY_SUPERVISOR',
    'SUPPORT',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _nationalityController;
  late final TextEditingController _documentNumberController;
  late final TextEditingController _vehiclePlateController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final Set<String> _selectedRoles;
  late final Set<int> _selectedWarehouseIds;
  late bool _active;
  late String _preferredLanguage;
  late String _documentType;
  String? _existingDocumentPhotoPath;
  SelectedEvidenceImage? _documentPhotoFile;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  bool get _requiresWarehouseScope =>
      _selectedRoles.any(_warehouseScopedRoles.contains);
  bool get _requiresWorkerDocument => _selectedRoles.any(_workerRoles.contains);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialUser;
    _fullNameController = TextEditingController(text: initial?.fullName ?? '');
    _emailController = TextEditingController(text: initial?.email ?? '');
    _phoneController = TextEditingController(text: initial?.phone ?? '');
    _nationalityController = TextEditingController(
      text: initial?.nationality.isNotEmpty == true
          ? initial!.nationality
          : 'Peru',
    );
    _documentNumberController = TextEditingController(
      text: initial?.documentNumber ?? '',
    );
    _vehiclePlateController = TextEditingController(
      text: initial?.vehiclePlate ?? '',
    );
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _selectedRoles = {...?initial?.roles.toSet(), ...widget.presetRoles};
    _selectedWarehouseIds = {...?initial?.warehouseIds.toSet()};
    _active = initial?.active ?? true;
    _preferredLanguage = initial?.preferredLanguage.isNotEmpty == true
        ? initial!.preferredLanguage
        : 'es';
    _documentType = initial?.documentType?.trim().isNotEmpty == true
        ? initial!.documentType!.trim().toUpperCase()
        : 'DNI';
    _existingDocumentPhotoPath = initial?.documentPhotoPath;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nationalityController.dispose();
    _documentNumberController.dispose();
    _vehiclePlateController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxDialogWidth = media.size.width >= 640
        ? 460.0
        : media.size.width * 0.92;
    final maxDialogHeight = media.size.height * 0.72;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      title: Text(widget.title),
      content: SizedBox(
        width: maxDialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDialogHeight),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidateMode,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                    ),
                    validator: (value) =>
                        FormValidators.requiredText(value, label: 'nombre'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Correo'),
                    keyboardType: TextInputType.emailAddress,
                    validator: FormValidators.email,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Telefono'),
                    keyboardType: TextInputType.phone,
                    validator: FormValidators.phone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _preferredLanguage,
                    decoration: InputDecoration(labelText: 'Idioma'),
                    items: [
                      DropdownMenuItem(
                        value: 'es',
                        child: Text(context.l10n.t('es')),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(context.l10n.t('en')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _preferredLanguage = value);
                      }
                    },
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _nationalityController,
                    decoration: const InputDecoration(
                      labelText: 'Nacionalidad',
                    ),
                    validator: (value) => FormValidators.requiredText(
                      value,
                      label: 'nacionalidad',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _documentType,
                    decoration: InputDecoration(
                      labelText: 'Tipo de documento',
                      helperText: _requiresWorkerDocument
                          ? 'Obligatorio para operadores, couriers y soporte.'
                          : 'Opcional para este rol.',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'DNI',
                        child: Text(context.l10n.t('dni')),
                      ),
                      DropdownMenuItem(
                        value: 'CE',
                        child: Text(context.l10n.t('ce')),
                      ),
                      DropdownMenuItem(
                        value: 'PASSPORT',
                        child: Text(context.l10n.t('pasaporte')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _documentType = value);
                      }
                    },
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _documentNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Numero de documento',
                    ),
                    validator: (value) {
                      if (_requiresWorkerDocument) {
                        return FormValidators.requiredText(
                          value,
                          label: 'numero de documento',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickDocumentPhoto,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(context.l10n.t('adjuntar_foto_dni')),
                        ),
                        if (_documentPhotoFile != null)
                          Chip(label: Text(_documentPhotoFile!.filename))
                        else if (_existingDocumentPhotoPath?.isNotEmpty == true)
                          Chip(label: Text(context.l10n.t('dni_ya_adjuntado'))),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _vehiclePlateController,
                    decoration: InputDecoration(
                      labelText: 'Placa del vehiculo',
                      helperText: _selectedRoles.contains('COURIER')
                          ? 'Obligatoria para usuarios courier.'
                          : 'Solo aplica para courier.',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (_selectedRoles.contains('COURIER')) {
                        return FormValidators.requiredText(
                          value,
                          label: 'la placa del vehiculo',
                        );
                      }
                      return null;
                    },
                  ),
                  if (widget.includePassword) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Contrasena temporal',
                        suffixIcon: IconButton(
                          tooltip: _passwordVisible
                              ? 'Ocultar contrasena'
                              : 'Ver contrasena',
                          onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible,
                          ),
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      obscureText: !_passwordVisible,
                      validator: FormValidators.password,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirmar contrasena',
                        suffixIcon: IconButton(
                          tooltip: _confirmPasswordVisible
                              ? 'Ocultar contrasena'
                              : 'Ver contrasena',
                          onPressed: () => setState(
                            () => _confirmPasswordVisible =
                                !_confirmPasswordVisible,
                          ),
                          icon: Icon(
                            _confirmPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      obscureText: !_confirmPasswordVisible,
                      validator: (value) => FormValidators.confirmPassword(
                        value,
                        _passwordController.text,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.t('usuario_activo')),
                    value: _active,
                    subtitle: _selectedRoles.contains('ADMIN')
                        ? Text(context.l10n.t('admin_siempre_activo'))
                        : null,
                    onChanged: _selectedRoles.contains('ADMIN')
                        ? null
                        : (value) => setState(() => _active = value),
                  ),
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Roles',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ..._roles.map(
                    (role) => CheckboxListTile(
                      value: _selectedRoles.contains(role),
                      contentPadding: EdgeInsets.zero,
                      title: Text(role),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedRoles.add(role);
                          } else {
                            _selectedRoles.remove(role);
                          }
                          if (_selectedRoles.contains('ADMIN')) {
                            _active = true;
                          }
                        });
                      },
                    ),
                  ),
                  if (_selectedRoles.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Debes seleccionar al menos un rol.',
                        style: TextStyle(color: Color(0xFFC43D3D)),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sedes asignadas',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_requiresWarehouseScope &&
                      widget.warehouseOptions.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No hay sedes activas. Crea o activa una sede antes de guardar este usuario.',
                        style: TextStyle(color: Color(0xFFC43D3D)),
                      ),
                    ),
                  ...widget.warehouseOptions.map(
                    (warehouse) => CheckboxListTile(
                      value: _selectedWarehouseIds.contains(warehouse.id),
                      contentPadding: EdgeInsets.zero,
                      title: Text(warehouse.label),
                      subtitle: warehouse.cityName.isNotEmpty
                          ? Text('Ciudad: ${warehouse.cityName}')
                          : null,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedWarehouseIds.add(warehouse.id);
                          } else {
                            _selectedWarehouseIds.remove(warehouse.id);
                          }
                        });
                      },
                    ),
                  ),
                  if (_requiresWarehouseScope && _selectedWarehouseIds.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Debes seleccionar al menos una sede para estos roles.',
                        style: TextStyle(color: Color(0xFFC43D3D)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.t('cancelar')),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }

  void _submit() {
    if (_selectedRoles.isEmpty ||
        (_requiresWarehouseScope && _selectedWarehouseIds.isEmpty) ||
        !_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    if (_requiresWorkerDocument &&
        _documentPhotoFile == null &&
        (_existingDocumentPhotoPath?.trim().isEmpty ?? true)) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t('debes_adjuntar_foto_de_dni_para_este_tra'),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _AdminUserFormData(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        nationality: _nationalityController.text.trim(),
        preferredLanguage: _preferredLanguage,
        roles: _selectedRoles.toList()..sort(),
        warehouseIds: _requiresWarehouseScope
            ? (_selectedWarehouseIds.toList()..sort())
            : const [],
        documentType: _requiresWorkerDocument ? _documentType : null,
        documentNumber: _requiresWorkerDocument
            ? _documentNumberController.text.trim()
            : null,
        documentPhotoPath: _documentPhotoFile == null
            ? _existingDocumentPhotoPath?.trim()
            : null,
        documentPhotoFile: _documentPhotoFile,
        vehiclePlate: _selectedRoles.contains('COURIER')
            ? _vehiclePlateController.text.trim().toUpperCase()
            : null,
        active: _selectedRoles.contains('ADMIN') ? true : _active,
        password: widget.includePassword ? _passwordController.text : null,
      ),
    );
  }

  Future<void> _pickDocumentPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t('no_se_pudo_leer_la_imagen_seleccionada'),
          ),
        ),
      );
      return;
    }
    final extension = (file.extension ?? '').toLowerCase().trim();
    setState(() {
      _documentPhotoFile = SelectedEvidenceImage(
        filename: file.name,
        mimeType: _guessMimeType(extension),
        bytes: bytes,
      );
      _existingDocumentPhotoPath = null;
    });
  }

  String _guessMimeType(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'image/jpeg',
    };
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.user});

  final AdminUserItem user;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxDialogWidth = media.size.width >= 560
        ? 380.0
        : media.size.width * 0.9;
    final maxDialogHeight = media.size.height * 0.52;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: Text('Actualizar credenciales de ${widget.user.fullName}'),
      content: SizedBox(
        width: maxDialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDialogHeight),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidateMode,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Nueva contrasena',
                      suffixIcon: IconButton(
                        tooltip: _passwordVisible
                            ? 'Ocultar contrasena'
                            : 'Ver contrasena',
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    obscureText: !_passwordVisible,
                    validator: FormValidators.password,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirmar contrasena',
                      suffixIcon: IconButton(
                        tooltip: _confirmPasswordVisible
                            ? 'Ocultar contrasena'
                            : 'Ver contrasena',
                        onPressed: () => setState(
                          () => _confirmPasswordVisible =
                              !_confirmPasswordVisible,
                        ),
                        icon: Icon(
                          _confirmPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    obscureText: !_confirmPasswordVisible,
                    validator: (value) => FormValidators.confirmPassword(
                      value,
                      _passwordController.text,
                    ),
                  ),
                ],
              ),
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
          onPressed: _submit,
          child: Text(context.l10n.t('guardar_contrasena')),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    Navigator.of(context).pop(_passwordController.text);
  }
}

class _AdminUserFormData {
  const _AdminUserFormData({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.nationality,
    required this.preferredLanguage,
    required this.roles,
    required this.warehouseIds,
    required this.documentType,
    required this.documentNumber,
    required this.documentPhotoPath,
    required this.documentPhotoFile,
    required this.vehiclePlate,
    required this.active,
    this.password,
  });

  final String fullName;
  final String email;
  final String phone;
  final String nationality;
  final String preferredLanguage;
  final List<String> roles;
  final List<int> warehouseIds;
  final String? documentType;
  final String? documentNumber;
  final String? documentPhotoPath;
  final SelectedEvidenceImage? documentPhotoFile;
  final String? vehiclePlate;
  final bool active;
  final String? password;

  Map<String, dynamic> toCreatePayload({String? uploadedDocumentPhotoPath}) {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'password': password,
      'roles': roles,
      'warehouseIds': warehouseIds,
      'documentType': documentType,
      'documentNumber': documentNumber,
      'documentPhotoPath': uploadedDocumentPhotoPath ?? documentPhotoPath,
      'vehiclePlate': vehiclePlate,
      'nationality': nationality,
      'preferredLanguage': preferredLanguage,
      'active': active,
    };
  }

  Map<String, dynamic> toUpdatePayload({String? uploadedDocumentPhotoPath}) {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'roles': roles,
      'warehouseIds': warehouseIds,
      'documentType': documentType,
      'documentNumber': documentNumber,
      'documentPhotoPath': uploadedDocumentPhotoPath ?? documentPhotoPath,
      'vehiclePlate': vehiclePlate,
      'nationality': nationality,
      'preferredLanguage': preferredLanguage,
      'active': active,
    };
  }
}

class AdminUserItem {
  const AdminUserItem({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.nationality,
    required this.preferredLanguage,
    required this.authProvider,
    required this.managedByAdmin,
    required this.documentType,
    required this.documentNumber,
    required this.documentPhotoPath,
    required this.vehiclePlate,
    required this.active,
    required this.roles,
    required this.warehouseIds,
    required this.warehouseNames,
    required this.deliveryCreatedCount,
    required this.deliveryAssignedCount,
    required this.deliveryCompletedCount,
    required this.activeDeliveryCount,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String nationality;
  final String preferredLanguage;
  final String authProvider;
  final bool managedByAdmin;
  final String? documentType;
  final String? documentNumber;
  final String? documentPhotoPath;
  final String? vehiclePlate;
  final bool active;
  final List<String> roles;
  final List<int> warehouseIds;
  final List<String> warehouseNames;
  final int deliveryCreatedCount;
  final int deliveryAssignedCount;
  final int deliveryCompletedCount;
  final int activeDeliveryCount;
  final DateTime? createdAt;

  bool get isCourier => roles.contains('COURIER');
  bool get isOperator => roles.contains('OPERATOR');
  bool get isAdmin => roles.contains('ADMIN');
  bool get requiresWarehouseScope =>
      roles.contains('COURIER') ||
      roles.contains('OPERATOR') ||
      roles.contains('CITY_SUPERVISOR') ||
      roles.contains('SUPPORT');

  factory AdminUserItem.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    final warehouseIds = (json['warehouseIds'] as List<dynamic>? ?? const [])
        .map((item) => (item as num?)?.toInt())
        .whereType<int>()
        .toList();
    final warehouseNames =
        (json['warehouseNames'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();
    return AdminUserItem(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Usuario',
      email: json['email']?.toString() ?? '-',
      phone: json['phone']?.toString() ?? '-',
      nationality: json['nationality']?.toString() ?? '',
      preferredLanguage: json['preferredLanguage']?.toString() ?? '',
      authProvider: json['authProvider']?.toString() ?? 'LOCAL',
      managedByAdmin: json['managedByAdmin'] as bool? ?? false,
      documentType: json['documentType']?.toString(),
      documentNumber: json['documentNumber']?.toString(),
      documentPhotoPath: json['documentPhotoPath']?.toString(),
      vehiclePlate: json['vehiclePlate']?.toString(),
      active: json['active'] as bool? ?? true,
      roles: roles,
      warehouseIds: warehouseIds,
      warehouseNames: warehouseNames,
      deliveryCreatedCount:
          (json['deliveryCreatedCount'] as num?)?.toInt() ?? 0,
      deliveryAssignedCount:
          (json['deliveryAssignedCount'] as num?)?.toInt() ?? 0,
      deliveryCompletedCount:
          (json['deliveryCompletedCount'] as num?)?.toInt() ?? 0,
      activeDeliveryCount: (json['activeDeliveryCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class _AdminWarehouseOption {
  const _AdminWarehouseOption({
    required this.id,
    required this.name,
    required this.cityName,
  });

  final int id;
  final String name;
  final String cityName;

  String get label {
    if (cityName.isEmpty) return name;
    return '$name - $cityName';
  }

  factory _AdminWarehouseOption.fromJson(Map<String, dynamic> json) {
    return _AdminWarehouseOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString().trim()
          : 'Sede',
      cityName: json['cityName']?.toString().trim() ?? '',
    );
  }
}

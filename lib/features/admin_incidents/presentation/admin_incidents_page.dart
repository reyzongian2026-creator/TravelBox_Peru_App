import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../shared/utils/file_exporter.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../reservation/presentation/reservation_providers.dart';

final adminIncidentsSearchProvider = StateProvider<String>((ref) => '');
final adminIncidentsStatusProvider = StateProvider<String>((ref) => 'OPEN');

final adminIncidentsProvider = FutureProvider<List<AdminIncidentItem>>((
  ref,
) async {
  ref.watch(reservationRealtimeEventCursorProvider);
  final dio = ref.read(dioProvider);
  final query = ref.watch(adminIncidentsSearchProvider).trim();
  final status = ref.watch(adminIncidentsStatusProvider);
  final response = await dio.get<List<dynamic>>(
    '/incidents',
    queryParameters: {
      if (query.isNotEmpty) 'query': query,
      if (status != 'ALL') 'status': status,
    },
  );
  return (response.data ?? const [])
      .map((item) => AdminIncidentItem.fromJson(item as Map<String, dynamic>))
      .toList();
});

class AdminIncidentsPage extends ConsumerStatefulWidget {
  AdminIncidentsPage({
    super.key,
    this.title = 'Admin incidencias',
    this.currentRoute = '/admin/incidents',
  });

  final String title;
  final String currentRoute;

  @override
  ConsumerState<AdminIncidentsPage> createState() => _AdminIncidentsPageState();
}

class _AdminIncidentsPageState extends ConsumerState<AdminIncidentsPage> {
  final _searchController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incidentsAsync = ref.watch(adminIncidentsProvider);
    final status = ref.watch(adminIncidentsStatusProvider);
    final session = ref.watch(sessionControllerProvider);
    final supportMode = widget.currentRoute.startsWith('/support');
    final canResolve =
        session.user?.role == UserRole.admin ||
        session.user?.role == UserRole.support;

    return AppShellScaffold(
      title: widget.title,
      currentRoute: widget.currentRoute,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        ref.read(adminIncidentsSearchProvider.notifier).state =
                            value,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por reserva, cliente o detalle',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: status,
                  items: [
                    DropdownMenuItem(
                      value: 'OPEN',
                      child: Text(context.l10n.t('abiertos')),
                    ),
                    DropdownMenuItem(
                      value: 'RESOLVED',
                      child: Text(context.l10n.t('resueltos')),
                    ),
                    DropdownMenuItem(
                      value: 'ALL',
                      child: Text(context.l10n.t('todos')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(adminIncidentsStatusProvider.notifier).state =
                          value;
                    }
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => ref.invalidate(adminIncidentsProvider),
                  icon: Icon(Icons.refresh),
                  label: Text(context.l10n.t('recargar')),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: incidentsAsync.when(
              data: (items) {
                final openCount = items
                    .where((item) => item.status == 'OPEN')
                    .length;
                final resolvedCount = items
                    .where((item) => item.status == 'RESOLVED')
                    .length;
                final resolvedItems = items
                    .where((item) => item.status == 'RESOLVED')
                    .toList();
                if (items.isEmpty) {
                  return const EmptyStateView(
                    message: 'No hay tickets para este filtro.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _IncidentKpi(
                          title: 'Abiertos',
                          value: '$openCount',
                          color: const Color(0xFFC43D3D),
                        ),
                        _IncidentKpi(
                          title: 'Resueltos',
                          value: '$resolvedCount',
                          color: const Color(0xFF168F64),
                        ),
                        _IncidentKpi(
                          title: 'Total',
                          value: '${items.length}',
                          color: const Color(0xFF1F6E8C),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _saving || resolvedItems.isEmpty
                                  ? null
                                  : () => _exportResolvedCsv(resolvedItems),
                              icon: const Icon(Icons.table_view_outlined),
                              label: Text(
                                context.l10n.t('exportar_csv_resueltos'),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _saving || resolvedItems.isEmpty
                                  ? null
                                  : () => _exportResolvedPdf(resolvedItems),
                              icon: Icon(Icons.picture_as_pdf_outlined),
                              label: Text(
                                context.l10n.t('exportar_pdf_resueltos'),
                              ),
                            ),
                            if (resolvedItems.isEmpty)
                              Chip(
                                label: Text(
                                  'No hay resueltos en la vista actual',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
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
                                      'Ticket #${item.id}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Chip(
                                      label: Text(item.status),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Chip(
                                      label: Text(
                                        'Reserva ${item.reservationStatus}',
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${item.reservationCode} - ${item.warehouseName}',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                Text(item.warehouseAddress),
                                const SizedBox(height: 8),
                                Text(
                                  'Cliente: ${item.openedByName} (${item.openedByEmail})',
                                ),
                                const SizedBox(height: 6),
                                if (item.customerName.isNotEmpty ||
                                    item.customerPhone.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (item.customerName.isNotEmpty)
                                        Chip(
                                          label: Text(
                                            'Cliente: ${item.customerName}',
                                          ),
                                        ),
                                      if (item.customerPhone.isNotEmpty)
                                        Chip(
                                          label: Text(
                                            'Tel: ${item.customerPhone}',
                                          ),
                                        ),
                                    ],
                                  ),
                                const SizedBox(height: 8),
                                Text(item.cleanDescription),
                                if (item.evidenceUrl != null) ...[
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AppSmartImage(
                                      source: item.evidenceUrl,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      fallback: Container(
                                        height: 84,
                                        alignment: Alignment.center,
                                        color: const Color(0xFFF3F4F6),
                                        child: const Text(
                                          'No se pudo cargar la evidencia.',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (item.resolution != null &&
                                    item.resolution!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'Resolucion: ${item.resolution}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (!supportMode)
                                      OutlinedButton.icon(
                                        onPressed: () => context.go(
                                          '/reservation/${item.reservationId}',
                                        ),
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                        ),
                                        label: Text(
                                          context.l10n.t('ver_reserva'),
                                        ),
                                      ),
                                    if (!supportMode)
                                      OutlinedButton.icon(
                                        onPressed: () => context.go(
                                          _trackingRoute(item.reservationId),
                                        ),
                                        icon: Icon(Icons.route_outlined),
                                        label: Text(
                                          context.l10n.t('ver_tracking'),
                                        ),
                                      ),
                                    if (item.customerWhatsappUrl != null)
                                      OutlinedButton.icon(
                                        onPressed: () => _openExternal(
                                          item.customerWhatsappUrl!,
                                          'No se pudo abrir WhatsApp en este dispositivo.',
                                        ),
                                        icon: Icon(Icons.chat_outlined),
                                        label: Text(context.l10n.t('whatsapp')),
                                      ),
                                    if (item.customerCallUrl != null)
                                      OutlinedButton.icon(
                                        onPressed: () => _openExternal(
                                          item.customerCallUrl!,
                                          'No se pudo iniciar la llamada en este dispositivo.',
                                        ),
                                        icon: Icon(Icons.call_outlined),
                                        label: Text(context.l10n.t('llamar')),
                                      ),
                                    if (canResolve && item.status == 'OPEN')
                                      FilledButton.tonalIcon(
                                        onPressed: _saving
                                            ? null
                                            : () => _resolveIncident(item),
                                        icon: Icon(Icons.task_alt_outlined),
                                        label: Text(context.l10n.t('resolver')),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => LoadingStateView(),
              error: (error, _) => ErrorStateView(
                message: 'No se pudieron cargar incidencias: $error',
                onRetry: () => ref.invalidate(adminIncidentsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveIncident(AdminIncidentItem item) async {
    final resolution = await showDialog<String>(
      context: context,
      builder: (context) => const _ResolutionDialog(),
    );
    if (resolution == null || resolution.trim().isEmpty) {
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(dioProvider)
          .patch<Map<String, dynamic>>(
            '/incidents/${item.id}/resolve',
            data: {'resolution': resolution.trim()},
          );
      ref.invalidate(adminIncidentsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('incidencia_resuelta_correctamente')),
          action: ref.read(adminIncidentsStatusProvider) == 'OPEN'
              ? SnackBarAction(
                  label: 'Ver resueltos',
                  onPressed: () {
                    ref.read(adminIncidentsStatusProvider.notifier).state =
                        'RESOLVED';
                  },
                )
              : null,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo resolver la incidencia: ${_errorMessage(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _errorMessage(Object error) {
    return AppErrorFormatter.readable(error);
  }

  String _trackingRoute(String reservationId) {
    if (widget.currentRoute.startsWith('/support')) {
      return '/support/incidents';
    }
    if (widget.currentRoute.startsWith('/operator')) {
      return '/operator/tracking/$reservationId';
    }
    return '/admin/tracking/$reservationId';
  }

  Future<void> _openExternal(String url, String failMessage) async {
    final success = await launchUrlString(url);
    if (success || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failMessage)));
  }

  Future<void> _exportResolvedCsv(List<AdminIncidentItem> items) async {
    final success = await downloadTextFile(
      filename: _buildExportFilename('csv'),
      content: _buildResolvedCsv(items),
      mimeType: 'text/csv;charset=utf-8',
    );
    if (!mounted) return;
    _showExportFeedback(
      success: success,
      successMessage: 'CSV de incidencias resueltas generado.',
    );
  }

  Future<void> _exportResolvedPdf(List<AdminIncidentItem> items) async {
    final success = await openPrintPreview(
      title: 'Incidencias resueltas TravelBox',
      htmlContent: _buildResolvedHtml(items),
    );
    if (!mounted) return;
    _showExportFeedback(
      success: success,
      successMessage:
          'Vista imprimible abierta. Desde el navegador puedes guardar como PDF.',
    );
  }

  void _showExportFeedback({
    required bool success,
    required String successMessage,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? successMessage
              : 'La exportacion solo esta disponible en la version web.',
        ),
      ),
    );
  }

  String _buildResolvedCsv(List<AdminIncidentItem> items) {
    final rows = <List<String>>[
      [
        'ticket_id',
        'reserva_id',
        'codigo_reserva',
        'estado_reserva',
        'almacen',
        'direccion_almacen',
        'cliente',
        'correo_cliente',
        'detalle',
        'resolucion',
      ],
      ...items.map(
        (item) => [
          item.id,
          item.reservationId,
          item.reservationCode,
          item.reservationStatus,
          item.warehouseName,
          item.warehouseAddress,
          item.openedByName,
          item.openedByEmail,
          item.cleanDescription,
          item.resolution ?? '',
        ],
      ),
    ];

    return rows.map((row) => row.map(_escapeCsv).join(',')).join('\n');
  }

  String _escapeCsv(String value) {
    final normalized = value.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
    final escaped = normalized.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _buildResolvedHtml(List<AdminIncidentItem> items) {
    final escape = HtmlEscape();
    final rows = items.map((item) {
      return '''
<tr>
  <td>${escape.convert(item.id)}</td>
  <td>${escape.convert(item.reservationCode)}</td>
  <td>${escape.convert(item.warehouseName)}</td>
  <td>${escape.convert(item.openedByName)}</td>
  <td>${escape.convert(item.cleanDescription)}</td>
  <td>${escape.convert(item.resolution ?? '-')}</td>
</tr>
''';
    }).join();

    return '''
<h1>Incidencias resueltas</h1>
<p class="meta">Generado el ${escape.convert(_exportGeneratedAt())}</p>
<p class="meta">Cantidad exportada: ${items.length}</p>
<table>
  <thead>
    <tr>
      <th>Ticket</th>
      <th>Reserva</th>
      <th>Almacen</th>
      <th>Cliente</th>
      <th>Detalle</th>
      <th>Resolucion</th>
    </tr>
  </thead>
  <tbody>
    $rows
  </tbody>
</table>
''';
  }

  String _buildExportFilename(String extension) {
    final now = PeruTime.toPeruClock(DateTime.now());
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'travelbox_incidencias_resueltas_$stamp.$extension';
  }

  String _exportGeneratedAt() {
    return PeruTime.formatDateTime(DateTime.now());
  }
}

class _IncidentKpi extends StatelessWidget {
  const _IncidentKpi({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolutionDialog extends StatefulWidget {
  const _ResolutionDialog();

  @override
  State<_ResolutionDialog> createState() => _ResolutionDialogState();
}

class _ResolutionDialogState extends State<_ResolutionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxDialogWidth = media.size.width >= 620
        ? 420.0
        : media.size.width * 0.92;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: Text(context.l10n.t('resolver_incidencia')),
      content: SizedBox(
        width: maxDialogWidth,
        child: TextField(
          controller: _controller,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Resolucion',
            hintText: 'Indica que accion se tomo para cerrar el ticket.',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.t('cancelar')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(context.l10n.t('guardar')),
        ),
      ],
    );
  }
}

class AdminIncidentItem {
  const AdminIncidentItem({
    required this.id,
    required this.reservationId,
    required this.reservationCode,
    required this.reservationStatus,
    required this.warehouseName,
    required this.warehouseAddress,
    required this.openedByName,
    required this.openedByEmail,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.customerWhatsappUrl,
    required this.customerCallUrl,
    required this.status,
    required this.description,
    required this.resolution,
  });

  final String id;
  final String reservationId;
  final String reservationCode;
  final String reservationStatus;
  final String warehouseName;
  final String warehouseAddress;
  final String openedByName;
  final String openedByEmail;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String? customerWhatsappUrl;
  final String? customerCallUrl;
  final String status;
  final String description;
  final String? resolution;

  String get cleanDescription => description
      .replaceAll(_evidencePattern, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String? get evidenceUrl {
    final match = _evidencePattern.firstMatch(description);
    return match?.group(1)?.trim();
  }

  factory AdminIncidentItem.fromJson(Map<String, dynamic> json) {
    return AdminIncidentItem(
      id: json['id']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      reservationCode: json['reservationCode']?.toString() ?? '-',
      reservationStatus: json['reservationStatus']?.toString() ?? '-',
      warehouseName: json['warehouseName']?.toString() ?? 'Sin almacen',
      warehouseAddress: json['warehouseAddress']?.toString() ?? '-',
      openedByName: json['openedByName']?.toString() ?? 'Usuario',
      openedByEmail: json['openedByEmail']?.toString() ?? '-',
      customerName: json['customerName']?.toString() ?? '',
      customerEmail: json['customerEmail']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      customerWhatsappUrl: json['customerWhatsappUrl']?.toString(),
      customerCallUrl: json['customerCallUrl']?.toString(),
      status: json['status']?.toString() ?? 'OPEN',
      description: json['description']?.toString() ?? '',
      resolution: json['resolution']?.toString(),
    );
  }

  static final RegExp _evidencePattern = RegExp(
    r'EVIDENCIA:\s*(\S+)',
    caseSensitive: false,
  );
}

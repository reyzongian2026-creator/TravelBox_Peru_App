import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/adaptive_wrap_grid.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/responsive_filter_panel.dart';
import '../../../core/widgets/responsive_page_header_actions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/incident_i18n_codec.dart';
import '../../../shared/utils/incident_translation_service.dart';
import '../../../shared/utils/file_exporter.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../reservation/presentation/reservation_providers.dart';

final adminIncidentsSearchProvider = StateProvider<String>((ref) => '');
final adminIncidentsStatusProvider = StateProvider<String>((ref) => 'OPEN');
final adminIncidentsPageProvider = StateProvider<int>((ref) => 0);
final adminIncidentsPageSizeProvider = Provider<int>((ref) => 5);

final adminIncidentsProvider = FutureProvider<AdminIncidentsPageResult>((
  ref,
) async {
  ref.watch(reservationRealtimeEventCursorProvider);
  final dio = ref.read(dioProvider);
  final query = ref.watch(adminIncidentsSearchProvider).trim();
  final status = ref.watch(adminIncidentsStatusProvider);
  final page = ref.watch(adminIncidentsPageProvider);
  final size = ref.watch(adminIncidentsPageSizeProvider);
  final response = await dio.get<Map<String, dynamic>>(
    '/incidents/page',
    queryParameters: {
      'page': page,
      'size': size,
      if (query.isNotEmpty) 'query': query,
      if (status != 'ALL') 'status': status,
    },
  );
  final data = response.data ?? const <String, dynamic>{};
  final itemsRaw = data['items'] as List<dynamic>? ?? const [];
  final items = itemsRaw
      .map((item) => AdminIncidentItem.fromJson(item as Map<String, dynamic>))
      .toList();
  return AdminIncidentsPageResult(
    items: items,
    page: (data['page'] as num?)?.toInt() ?? page,
    totalPages: (data['totalPages'] as num?)?.toInt() ?? 0,
    totalElements: (data['totalElements'] as num?)?.toInt() ?? items.length,
    hasNext: data['hasNext'] as bool? ?? false,
    hasPrevious: data['hasPrevious'] as bool? ?? page > 0,
  );
});

class AdminIncidentsPageResult {
  const AdminIncidentsPageResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalElements,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<AdminIncidentItem> items;
  final int page;
  final int totalPages;
  final int totalElements;
  final bool hasNext;
  final bool hasPrevious;
}

class AdminIncidentsPage extends ConsumerStatefulWidget {
  const AdminIncidentsPage({
    super.key,
    this.title = 'admin_incidents',
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
    final responsive = context.responsive;
    final itemGap = responsive.itemGap;
    final sectionGap = responsive.sectionGap;
    final cardPadding = responsive.cardPadding;
    final incidentsAsync = ref.watch(adminIncidentsProvider);
    final status = ref.watch(adminIncidentsStatusProvider);
    final session = ref.watch(sessionControllerProvider);
    final translator = ref.read(incidentTranslationServiceProvider);
    final supportMode = widget.currentRoute.startsWith('/support');
    final canResolve =
        session.user?.role == UserRole.admin ||
        session.user?.role == UserRole.support;

    return AppShellScaffold(
      title: context.l10n.t(widget.title),
      currentRoute: widget.currentRoute,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.horizontalPadding,
              responsive.verticalPadding,
              responsive.horizontalPadding,
              0,
            ),
            child: ResponsiveFilterPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      ref.read(adminIncidentsSearchProvider.notifier).state = value;
                      ref.read(adminIncidentsPageProvider.notifier).state = 0;
                    },
                    decoration: InputDecoration(
                      labelText: context.l10n.t('incident_admin_search_label'),
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                  SizedBox(height: itemGap),
                  if (responsive.isMobile)
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.t('estado'),
                      ),
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
                          ref.read(adminIncidentsPageProvider.notifier).state = 0;
                        }
                      },
                    )
                  else
                    Wrap(
                      spacing: itemGap,
                      runSpacing: itemGap,
                      children: [
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
                              ref.read(adminIncidentsPageProvider.notifier).state = 0;
                            }
                          },
                        ),
                      ],
                    ),
                  SizedBox(height: itemGap),
                  ResponsivePageHeaderActions(
                    actions: [
                      ResponsiveHeaderAction(
                        label: context.l10n.t('recargar'),
                        icon: Icons.refresh,
                        onPressed: _saving
                            ? null
                            : () => ref.invalidate(adminIncidentsProvider),
                        primary: true,
                      ),
                    ],
                    mobileVisibleCount: 1,
                    tabletVisibleCount: 1,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: itemGap),
          Expanded(
            child: incidentsAsync.when(
              data: (pageData) {
                final items = pageData.items;
                final openCount = items
                    .where((item) => item.status == 'OPEN')
                    .length;
                final resolvedCount = items
                    .where((item) => item.status == 'RESOLVED')
                    .length;
                if (items.isEmpty) {
                  return EmptyStateView(
                    message: context.l10n.t('incident_admin_empty_for_filter'),
                    actionLabel: pageData.hasPrevious
                        ? context.l10n.t('previous')
                        : context.l10n.t('recargar'),
                    onAction: pageData.hasPrevious
                        ? () {
                            final notifier = ref.read(
                              adminIncidentsPageProvider.notifier,
                            );
                            if (notifier.state > 0) {
                              notifier.state = notifier.state - 1;
                            }
                          }
                        : () => ref.invalidate(adminIncidentsProvider),
                  );
                }
                return ListView(
                  padding: responsive.pageInsets(top: 0, bottom: sectionGap),
                  children: [
                    AdaptiveWrapGrid(
                      spacing: itemGap,
                      runSpacing: itemGap,
                      mobileColumns: 1,
                      tabletColumns: 2,
                      desktopSmallColumns: 3,
                      desktopColumns: 3,
                      minItemWidth: 160,
                      children: [
                        _IncidentKpi(
                          title: context.l10n.t('abiertos'),
                          value: '$openCount',
                          color: const Color(0xFFC43D3D),
                        ),
                        _IncidentKpi(
                          title: context.l10n.t('resueltos'),
                          value: '$resolvedCount',
                          color: const Color(0xFF168F64),
                        ),
                        _IncidentKpi(
                          title: context.l10n.t('todos'),
                          value: '${pageData.totalElements}',
                          color: const Color(0xFF1F6E8C),
                        ),
                      ],
                    ),
                    SizedBox(height: sectionGap),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Wrap(
                          spacing: itemGap,
                          runSpacing: itemGap,
                          children: [
                            FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _exportProfessionalExcel(),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.table_view_outlined),
                              label: Text(context.l10n.t('excel_report')),
                            ),
                            OutlinedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _exportProfessionalPdf(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: Icon(Icons.picture_as_pdf_outlined),
                              label: Text(context.l10n.t('pdf_report')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    ...items.map((item) {
                      final localizedDescription = item.localizedDescription(
                        viewerLanguage: session.locale.languageCode,
                        backofficeMode: true,
                        translator: translator,
                      );
                      final localizedResolution = item.localizedResolution(
                        viewerLanguage: session.locale.languageCode,
                        backofficeMode: true,
                        translator: translator,
                      );

                      return Padding(
                        padding: EdgeInsets.only(bottom: itemGap),
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(cardPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: itemGap,
                                  runSpacing: itemGap,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '${context.l10n.t('incident_ticket')}: #${item.id}',
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
                                        '${context.l10n.t('incident_reservation')}: ${item.reservationStatus}',
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                SizedBox(height: itemGap / 1.5),
                                Text(
                                  '${item.reservationCode} - ${item.warehouseName}',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                Text(item.warehouseAddress),
                                SizedBox(height: itemGap),
                                Text(
                                  '${context.l10n.t('incident_client')}: ${item.openedByName} (${item.openedByEmail})',
                                ),
                                SizedBox(height: itemGap / 1.5),
                                if (item.customerName.isNotEmpty ||
                                    item.customerPhone.isNotEmpty)
                                  Wrap(
                                    spacing: itemGap,
                                    runSpacing: itemGap,
                                    children: [
                                      if (item.customerName.isNotEmpty)
                                        Chip(
                                          label: Text(
                                            '${context.l10n.t('incident_client')}: ${item.customerName}',
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      if (item.customerPhone.isNotEmpty)
                                        Chip(
                                          label: Text(
                                            '${context.l10n.t('incident_phone')}: ${item.customerPhone}',
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                SizedBox(height: itemGap),
                                Text(localizedDescription),
                                if (item.evidenceUrl != null) ...[
                                  SizedBox(height: sectionGap),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AppSmartImage(
                                      source: item.evidenceUrl,
                                      height: responsive.isMobile ? 184 : 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      fallback: Container(
                                        height: 84,
                                        alignment: Alignment.center,
                                        color: const Color(0xFFF3F4F6),
                                        child: Text(
                                          context.l10n.t(
                                            'incident_evidence_load_failed',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (localizedResolution.isNotEmpty) ...[
                                  SizedBox(height: itemGap),
                                  Text(
                                    '${context.l10n.t('incident_resolution')}: $localizedResolution',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                                SizedBox(height: sectionGap),
                                Wrap(
                                  spacing: itemGap,
                                  runSpacing: itemGap,
                                  children: [
                                    if (!supportMode)
                                      OutlinedButton.icon(
                                        onPressed: () => context.go(
                                          '/reservation/${item.reservationId}',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 40),
                                          visualDensity: VisualDensity.compact,
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
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 40),
                                          visualDensity: VisualDensity.compact,
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
                                          context.l10n.t(
                                            'incident_whatsapp_open_failed',
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 40),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: Icon(Icons.chat_outlined),
                                        label: Text(context.l10n.t('whatsapp')),
                                      ),
                                    if (item.customerCallUrl != null)
                                      OutlinedButton.icon(
                                        onPressed: () => _openExternal(
                                          item.customerCallUrl!,
                                          context.l10n.t(
                                            'incident_call_open_failed',
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 40),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: Icon(Icons.call_outlined),
                                        label: Text(context.l10n.t('llamar')),
                                      ),
                                    if (canResolve && item.status == 'OPEN')
                                      FilledButton.tonalIcon(
                                        onPressed: _saving
                                            ? null
                                            : () => _resolveIncident(item),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 40),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: Icon(Icons.task_alt_outlined),
                                        label: Text(context.l10n.t('resolver')),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: itemGap),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${context.l10n.t('my_reservations_page')} ${pageData.page + 1} ${context.l10n.t('my_reservations_of')} ${pageData.totalPages <= 0 ? 1 : pageData.totalPages}',
                          ),
                          OutlinedButton.icon(
                            onPressed: pageData.hasPrevious
                                ? () {
                                    final notifier = ref.read(
                                      adminIncidentsPageProvider.notifier,
                                    );
                                    if (notifier.state > 0) {
                                      notifier.state = notifier.state - 1;
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            label: Text(context.l10n.t('previous')),
                          ),
                          FilledButton.icon(
                            onPressed: pageData.hasNext
                                ? () {
                                    final notifier = ref.read(
                                      adminIncidentsPageProvider.notifier,
                                    );
                                    notifier.state = notifier.state + 1;
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            label: Text(context.l10n.t('next')),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => LoadingStateView(),
              error: (error, _) => ErrorStateView(
                message:
                    '${context.l10n.t('incident_admin_load_failed')}: $error',
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
      final customerLanguage = item.customerLanguage;
      final sourceLanguage = ref
          .read(sessionControllerProvider)
          .locale
          .languageCode;
      final translatedResolution = ref
          .read(incidentTranslationServiceProvider)
          .translate(
            message: resolution.trim(),
            sourceLanguage: sourceLanguage,
            customerLanguage: customerLanguage,
          )
          .messageInSpanish;
      await ref
          .read(dioProvider)
          .patch<Map<String, dynamic>>(
            '/incidents/${item.id}/resolve',
            data: {
              'resolution': IncidentI18nCodec.withLanguageMarker(
                textInSpanish: translatedResolution,
                customerLanguage: customerLanguage,
              ),
            },
          );
      ref.invalidate(adminIncidentsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('incidencia_resuelta_correctamente')),
          action: ref.read(adminIncidentsStatusProvider) == 'OPEN'
              ? SnackBarAction(
                  label: context.l10n.t('incident_view_resolved'),
                  onPressed: () {
                    ref.read(adminIncidentsStatusProvider.notifier).state =
                        'RESOLVED';
                    ref.read(adminIncidentsPageProvider.notifier).state = 0;
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
            '${context.l10n.t('incident_resolve_failed')}: ${_errorMessage(error)}',
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
    return AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key));
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

  Future<void> _exportProfessionalPdf() async {
    setState(() => _saving = true);
    try {
      final status = ref.read(adminIncidentsStatusProvider);
      final query = ref.read(adminIncidentsSearchProvider);
      final response = await ref.read(dioProvider).post<Map<String, dynamic>>(
        '/incidents/reports/export/pdf',
        data: {
          if (status != 'ALL') 'status': status,
          if (query.isNotEmpty) 'query': query,
        },
      );
      final data = response.data;
      if (data == null || !mounted) return;
      final downloadUrl = data['downloadUrl'] as String?;
      final fileName = data['fileName'] as String?;
      if (downloadUrl == null || fileName == null) return;
      await downloadFromUrl(downloadUrl, fileName);
      if (!mounted) return;
      _showExportFeedback(
        success: true,
        successMessage: 'PDF report generated successfully',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('error_generating_pdf_prefix')}: ${_errorMessage(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _exportProfessionalExcel() async {
    setState(() => _saving = true);
    try {
      final status = ref.read(adminIncidentsStatusProvider);
      final query = ref.read(adminIncidentsSearchProvider);
      final response = await ref.read(dioProvider).post<Map<String, dynamic>>(
        '/incidents/reports/export/excel',
        data: {
          if (status != 'ALL') 'status': status,
          if (query.isNotEmpty) 'query': query,
        },
      );
      final data = response.data;
      if (data == null || !mounted) return;
      final downloadUrl = data['downloadUrl'] as String?;
      final fileName = data['fileName'] as String?;
      if (downloadUrl == null || fileName == null) return;
      await downloadFromUrl(downloadUrl, fileName);
      if (!mounted) return;
      _showExportFeedback(
        success: true,
        successMessage: 'Excel report generated successfully',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('error_generating_excel_prefix')}: ${_errorMessage(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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
              : context.l10n.t('admin_incidents_export_web_only'),
        ),
      ),
    );
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
    final responsive = context.responsive;
    return Container(
      padding: EdgeInsets.all(responsive.cardPadding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          SizedBox(height: responsive.itemGap),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
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
            labelText: context.l10n.t('incident_resolution'),
            hintText: context.l10n.t('incident_resolution_hint'),
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

  String get cleanDescription => IncidentI18nCodec.stripMarker(
    description
        .replaceAll(_evidencePattern, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim(),
  );

  String get customerLanguage =>
      IncidentI18nCodec.customerLanguageFrom(description, fallback: 'es');

  String get cleanResolution =>
      IncidentI18nCodec.stripMarker(resolution?.trim() ?? '');

  String localizedDescription({
    required String viewerLanguage,
    required bool backofficeMode,
    required IncidentTranslationService translator,
  }) {
    if (cleanDescription.isEmpty) {
      return cleanDescription;
    }
    if (backofficeMode || _normalizeLanguage(viewerLanguage) == 'es') {
      return cleanDescription;
    }
    return translator
        .translate(
          message: cleanDescription,
          sourceLanguage: 'es',
          customerLanguage: _normalizeLanguage(viewerLanguage),
        )
        .messageForCustomerLanguage;
  }

  String localizedResolution({
    required String viewerLanguage,
    required bool backofficeMode,
    required IncidentTranslationService translator,
  }) {
    final raw = resolution?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }
    final clean = IncidentI18nCodec.stripMarker(raw);
    if (clean.isEmpty) {
      return '';
    }
    if (backofficeMode || _normalizeLanguage(viewerLanguage) == 'es') {
      return clean;
    }
    return translator
        .translate(
          message: clean,
          sourceLanguage: 'es',
          customerLanguage: _normalizeLanguage(viewerLanguage),
        )
        .messageForCustomerLanguage;
  }

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
      warehouseName: json['warehouseName']?.toString() ?? '-',
      warehouseAddress: json['warehouseAddress']?.toString() ?? '-',
      openedByName: json['openedByName']?.toString() ?? '-',
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

  static String _normalizeLanguage(String languageCode) {
    final normalized = languageCode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'es';
    }
    if (normalized.length <= 2) {
      return normalized;
    }
    return normalized.substring(0, 2);
  }
}

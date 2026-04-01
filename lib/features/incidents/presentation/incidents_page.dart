import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/incident_i18n_codec.dart';
import '../../../shared/utils/incident_translation_service.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../shared/utils/status_localizer.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../reservation/presentation/reservation_providers.dart';
import 'incident_conversation_dialog.dart';
import '../data/evidence_picker.dart';
import '../data/selected_evidence_image.dart';

class ReservationIncidentsQuery {
  const ReservationIncidentsQuery({
    required this.reservationId,
    required this.page,
    this.size = 5,
  });

  final String reservationId;
  final int page;
  final int size;

  @override
  bool operator ==(Object other) {
    return other is ReservationIncidentsQuery &&
        other.reservationId == reservationId &&
        other.page == page &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(reservationId, page, size);
}

class ReservationIncidentsPage {
  const ReservationIncidentsPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<ClientIncidentItem> items;
  final int page;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
}

final reservationIncidentsProvider =
    FutureProvider.family<ReservationIncidentsPage, ReservationIncidentsQuery>((
      ref,
      query,
    ) async {
      ref.watch(reservationRealtimeEventCursorProvider);
      final dio = ref.read(dioProvider);
      final response = await dio.get<Map<String, dynamic>>(
        '/incidents/page',
        queryParameters: {
          'reservationId': query.reservationId,
          'page': query.page,
          'size': query.size,
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      final itemsRaw = data['items'] as List<dynamic>? ?? const [];
      final items = itemsRaw
          .map(
            (item) => ClientIncidentItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      return ReservationIncidentsPage(
        items: items,
        page: (data['page'] as num?)?.toInt() ?? query.page,
        totalPages: (data['totalPages'] as num?)?.toInt() ?? 0,
        hasNext: data['hasNext'] as bool? ?? false,
        hasPrevious: data['hasPrevious'] as bool? ?? query.page > 0,
      );
    });

class IncidentsPage extends ConsumerStatefulWidget {
  const IncidentsPage({super.key, this.reservationId});

  final String? reservationId;

  @override
  ConsumerState<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends ConsumerState<IncidentsPage> {
  String category = 'damage';
  final _commentController = TextEditingController();
  bool includePhotos = true;
  bool submitting = false;
  SelectedEvidenceImage? _selectedImage;
  int _incidentPage = 0;

  static const int _incidentPageSize = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reservationId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.t('soporte_e_incidencias'))),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: EmptyStateView(
            message: context.l10n.t('incident_open_from_reservation_required'),
          ),
        ),
      );
    }

    final reservationAsync = ref.watch(
      reservationByIdProvider(widget.reservationId!),
    );
    final incidentsQuery = ReservationIncidentsQuery(
      reservationId: widget.reservationId!,
      page: _incidentPage,
      size: _incidentPageSize,
    );
    final incidentsAsync = ref.watch(
      reservationIncidentsProvider(incidentsQuery),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.t('soporte_e_incidencias'))),
      body: reservationAsync.when(
        data: (reservation) => _buildBody(context, reservation, incidentsAsync),
        loading: () => LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message:
              '${context.l10n.t('incident_reservation_load_failed')}: $error',
          onRetry: () =>
              ref.invalidate(reservationByIdProvider(widget.reservationId!)),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Reservation? reservation,
    AsyncValue<ReservationIncidentsPage> incidentsAsync,
  ) {
    final session = ref.watch(sessionControllerProvider);
    final canAccessBackoffice = session.canAccessAdmin;
    final reservationStatus = reservation?.status;
    final createsOperationalIncident =
        reservationStatus != null &&
        _isOperationalIncidentState(reservationStatus);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                canAccessBackoffice && createsOperationalIncident
                    ? Icons.report_problem_outlined
                    : Icons.support_agent_outlined,
              ),
              title: Text(
                canAccessBackoffice && createsOperationalIncident
                    ? context.l10n.t('incident_operational_title')
                    : context.l10n.t('incident_support_ticket_title'),
              ),
              subtitle: Text(
                canAccessBackoffice && createsOperationalIncident
                    ? context.l10n.t('incident_operational_subtitle')
                    : context.l10n.t('incident_support_ticket_subtitle'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (reservation != null)
            Card(
              child: ListTile(
                title: Text(context.l10n.t('reserva_vinculada')),
                subtitle: Text(
                  '${context.l10n.t('incident_reservation_id_prefix')} ${reservation.id} - ${reservation.warehouse.name}\n'
                  '${context.l10n.t('incident_current_status')}: ${reservation.status.localizedLabel(context)}',
                ),
                trailing: OutlinedButton(
                  onPressed: () => context.go('/reservation/${reservation.id}'),
                  child: Text(context.l10n.t('ver')),
                ),
              ),
            ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: category,
            items: [
              DropdownMenuItem(
                value: 'damage',
                child: Text(context.l10n.t('danio')),
              ),
              DropdownMenuItem(
                value: 'delay',
                child: Text(context.l10n.t('retraso')),
              ),
              DropdownMenuItem(
                value: 'wrong-item',
                child: Text(context.l10n.t('objeto_equivocado')),
              ),
              DropdownMenuItem(
                value: 'payment',
                child: Text(context.l10n.t('pago')),
              ),
              DropdownMenuItem(
                value: 'other',
                child: Text(context.l10n.t('otro')),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => category = value);
              }
            },
            decoration: InputDecoration(
              labelText: context.l10n.t('incident_category'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: context.l10n.t('incident_comment'),
              hintText: context.l10n.t('incident_comment_hint'),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: includePhotos,
            title: Text(context.l10n.t('adjuntar_evidencia_fotografica')),
            subtitle: Text(
              _selectedImage == null
                  ? context.l10n.t('incident_image_requirements')
                  : '${context.l10n.t('incident_image_selected')}: ${_selectedImage!.filename}',
            ),
            onChanged: submitting
                ? null
                : (value) {
                    setState(() {
                      includePhotos = value;
                      if (!value) {
                        _selectedImage = null;
                      }
                    });
                  },
          ),
          if (includePhotos) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: submitting ? null : _pickImage,
                  icon: Icon(Icons.upload_file_outlined),
                  label: Text(
                    _selectedImage == null
                        ? context.l10n.t('incident_select_image')
                        : context.l10n.t('incident_change_image'),
                  ),
                ),
                if (_selectedImage != null)
                  OutlinedButton.icon(
                    onPressed: submitting
                        ? null
                        : () => setState(() => _selectedImage = null),
                    icon: const Icon(Icons.close),
                    label: Text(context.l10n.t('quitar')),
                  ),
              ],
            ),
            if (_selectedImage != null) ...[
              SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  _selectedImage!.bytes,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: submitting ? null : () => _submit(reservation),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(
              submitting
                  ? context.l10n.t('incident_sending')
                  : context.l10n.t('incident_send_ticket'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.t('incident_generated_tickets'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          incidentsAsync.when(
            data: (pageData) {
              final items = pageData.items;
              if (items.isEmpty) {
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.inbox_outlined),
                    title: Text(
                      context.l10n.t('aun_no_hay_tickets_para_esta_reserva'),
                    ),
                    subtitle: Text(
                      context.l10n.t('incident_empty_history_hint'),
                    ),
                    trailing: pageData.hasPrevious
                        ? OutlinedButton.icon(
                            onPressed: () => setState(
                              () => _incidentPage = _incidentPage - 1,
                            ),
                            icon: const Icon(Icons.chevron_left),
                            label: Text(context.l10n.t('previous')),
                          )
                        : null,
                  ),
                );
              }
              return Column(
                children: [
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TicketCard(
                        item: item,
                        viewerLanguage: session.locale.languageCode,
                        backofficeMode: canAccessBackoffice,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
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
                              ? () => setState(
                                  () => _incidentPage = _incidentPage - 1,
                                )
                              : null,
                          icon: const Icon(Icons.chevron_left),
                          label: Text(context.l10n.t('previous')),
                        ),
                        FilledButton.icon(
                          onPressed: pageData.hasNext
                              ? () => setState(
                                  () => _incidentPage = _incidentPage + 1,
                                )
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
            loading: () => Card(
              child: ListTile(
                leading: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text(context.l10n.t('cargando_tickets')),
              ),
            ),
            error: (error, _) => Card(
              child: ListTile(
                leading: Icon(Icons.warning_amber_outlined),
                title: Text(context.l10n.t('no_se_pudo_cargar_el_historial')),
                subtitle: Text(error.toString()),
                trailing: OutlinedButton(
                  onPressed: () => ref.invalidate(
                    reservationIncidentsProvider(
                      ReservationIncidentsQuery(
                        reservationId: widget.reservationId!,
                        page: _incidentPage,
                        size: _incidentPageSize,
                      ),
                    ),
                  ),
                  child: Text(context.l10n.t('reintentar')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final selected = await pickEvidenceImage();
    if (!mounted) return;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('incident_image_pick_unavailable')),
        ),
      );
      return;
    }
    setState(() => _selectedImage = selected);
  }

  Future<void> _submit(Reservation? reservation) async {
    final session = ref.read(sessionControllerProvider);
    final selectedLocale = session.locale.languageCode;
    final translator = ref.read(incidentTranslationServiceProvider);
    final customerLanguage = _normalizeLanguage(
      session.user?.preferredLanguage ?? selectedLocale,
    );

    final reservationId = int.tryParse(widget.reservationId ?? '');
    if (reservationId == null) {
      _showSnackBar(context.l10n.t('incident_invalid_reservation'));
      return;
    }

    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      _showSnackBar(context.l10n.t('incident_comment_required'));
      return;
    }
    if (comment.length < 8) {
      _showSnackBar(context.l10n.t('incident_comment_min_length'));
      return;
    }
    if (includePhotos && _selectedImage == null) {
      _showSnackBar(context.l10n.t('incident_image_required_when_enabled'));
      return;
    }

    setState(() => submitting = true);
    try {
      String? evidenceUrl;
      if (includePhotos && _selectedImage != null) {
        evidenceUrl = await _uploadEvidence(
          reservationId: reservationId,
          observation: comment,
        );
      }

      final sourceLanguage = translator.detectLikelySourceLanguage(
        message: comment,
        fallbackLanguage: customerLanguage,
      );
      final translation = translator.translate(
        message: comment,
        sourceLanguage: sourceLanguage,
        customerLanguage: customerLanguage,
      );
      final commentInSpanish = IncidentI18nCodec.withLanguageMarker(
        textInSpanish:
            '[${_categoryLabel(category)}] ${translation.messageInSpanish}',
        customerLanguage: translation.customerLanguage,
      );

      final response = await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>(
            '/incidents',
            data: {
              'reservationId': reservationId,
              'description': _buildDescription(
                commentInSpanish: commentInSpanish,
                evidenceUrl: evidenceUrl,
              ),
              'originalLanguage': translation.sourceLanguage,
            },
          );

      ref.invalidate(reservationByIdProvider(widget.reservationId!));
      ref.invalidate(myReservationsProvider);
      ref.invalidate(adminReservationsProvider);
      ref.invalidate(adminReservationListProvider);
      setState(() => _incidentPage = 0);
      ref.invalidate(
        reservationIncidentsProvider(
          ReservationIncidentsQuery(
            reservationId: widget.reservationId!,
            page: 0,
            size: _incidentPageSize,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _commentController.clear();
        includePhotos = true;
        _selectedImage = null;
      });

      final incidentId = response.data?['id']?.toString() ?? '-';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reservation != null &&
                    _isOperationalIncidentState(reservation.status)
                ? '${context.l10n.t('incident_created_success')}: #$incidentId'
                : '${context.l10n.t('incident_support_created_success')}: #$incidentId',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        '${context.l10n.t('incident_send_failed')}: ${_errorMessage(error)}',
      );
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  Future<String> _uploadEvidence({
    required int reservationId,
    required String observation,
  }) async {
    final missingUrlMessage = context.l10n.t('incident_image_url_missing');
    final image = _selectedImage;
    if (image == null) {
      throw StateError(context.l10n.t('incident_no_image_selected'));
    }

    final response = await ref
        .read(dioProvider)
        .post<Map<String, dynamic>>(
          '/inventory/evidences/upload',
          data: FormData.fromMap({
            'reservationId': reservationId,
            'type': 'incident-${category.trim()}',
            'observation': _truncate(observation, 240),
            'file': MultipartFile.fromBytes(
              image.bytes,
              filename: image.filename,
              contentType: MediaType.parse(image.mimeType),
            ),
          }),
        );

    final data = response.data ?? <String, dynamic>{};
    final url =
        data['imageUrl']?.toString() ??
        data['photoUrl']?.toString() ??
        data['url']?.toString();
    if (url == null || url.trim().isEmpty) {
      throw StateError(missingUrlMessage);
    }
    return url.trim();
  }

  String _buildDescription({
    required String commentInSpanish,
    String? evidenceUrl,
  }) {
    final suffix = evidenceUrl == null || evidenceUrl.isEmpty
        ? ''
        : '\nEVIDENCIA: $evidenceUrl';
    final availableForComment = 500 - suffix.length;
    final safeComment = availableForComment <= 0
        ? ''
        : _truncate(commentInSpanish, availableForComment);
    return '$safeComment$suffix';
  }

  String _categoryLabel(String rawCategory) {
    switch (rawCategory) {
      case 'damage':
        return 'Damage';
      case 'delay':
        return 'Delay';
      case 'wrong-item':
        return 'Wrong item';
      case 'payment':
        return 'Payment';
      default:
        return 'Other';
    }
  }

  String _truncate(String value, int max) {
    if (value.length <= max) return value;
    if (max <= 3) return value.substring(0, max);
    return '${value.substring(0, max - 3).trimRight()}...';
  }

  bool _isOperationalIncidentState(ReservationStatus status) {
    return status == ReservationStatus.checkinPending ||
        status == ReservationStatus.stored ||
        status == ReservationStatus.readyForPickup ||
        status == ReservationStatus.outForDelivery;
  }

  String _errorMessage(Object error) {
    return AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key));
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _normalizeLanguage(String rawLanguage) {
    final normalized = rawLanguage.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'es';
    }
    if (normalized.length <= 2) {
      return normalized;
    }
    return normalized.substring(0, 2);
  }
}

class _TicketCard extends ConsumerWidget {
  const _TicketCard({
    required this.item,
    required this.viewerLanguage,
    required this.backofficeMode,
  });

  final ClientIncidentItem item;
  final String viewerLanguage;
  final bool backofficeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translator = ref.read(incidentTranslationServiceProvider);
    final description = item.localizedDescription(
      viewerLanguage: viewerLanguage,
      backofficeMode: backofficeMode,
      translator: translator,
    );
    final resolution = item.localizedResolution(
      viewerLanguage: viewerLanguage,
      backofficeMode: backofficeMode,
      translator: translator,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${context.l10n.t('incident_ticket')}: #${item.id}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(label: Text(item.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(description),
            const SizedBox(height: 8),
            Text(
              '${context.l10n.t('incident_created_at')}: ${PeruTime.formatDateTime(item.createdAt)}',
            ),
            if (item.evidenceUrl != null) ...[
              const SizedBox(height: 12),
              AppSmartImage(
                source: item.evidenceUrl,
                height: 180,
                width: double.infinity,
                borderRadius: BorderRadius.circular(12),
              ),
            ],
            if (resolution.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('${context.l10n.t('incident_resolution')}: $resolution'),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => IncidentConversationDialog(
                      incidentId: int.tryParse(item.id) ?? 0,
                      ticketLabel:
                          '${context.l10n.t('incident_ticket')} #${item.id}',
                      status: item.status,
                      allowReply: true,
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Conversacion'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ClientIncidentItem {
  const ClientIncidentItem({
    required this.id,
    required this.reservationId,
    required this.status,
    required this.description,
    required this.createdAt,
    this.resolution,
  });

  final String id;
  final String reservationId;
  final String status;
  final String description;
  final DateTime createdAt;
  final String? resolution;

  String get cleanDescription => IncidentI18nCodec.stripMarker(
    description
        .replaceAll(_evidencePattern, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim(),
  );

  String get customerLanguage =>
      IncidentI18nCodec.customerLanguageFrom(description, fallback: 'es');

  String localizedDescription({
    required String viewerLanguage,
    required bool backofficeMode,
    required IncidentTranslationService translator,
  }) {
    if (cleanDescription.isEmpty) {
      return cleanDescription;
    }
    if (backofficeMode || _normalizeLang(viewerLanguage) == 'es') {
      return cleanDescription;
    }
    return translator
        .translate(
          message: cleanDescription,
          sourceLanguage: 'es',
          customerLanguage: _normalizeLang(viewerLanguage),
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
    if (backofficeMode || _normalizeLang(viewerLanguage) == 'es') {
      return clean;
    }
    return translator
        .translate(
          message: clean,
          sourceLanguage: 'es',
          customerLanguage: _normalizeLang(viewerLanguage),
        )
        .messageForCustomerLanguage;
  }

  String? get evidenceUrl {
    final match = _evidencePattern.firstMatch(description);
    return match?.group(1)?.trim();
  }

  factory ClientIncidentItem.fromJson(Map<String, dynamic> json) {
    return ClientIncidentItem(
      id: json['id']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      description: json['description']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      resolution: json['resolution']?.toString(),
    );
  }

  static final RegExp _evidencePattern = RegExp(
    r'EVIDENCIA:\s*(\S+)',
    caseSensitive: false,
  );

  static String _normalizeLang(String language) {
    final normalized = language.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'es';
    }
    if (normalized.length <= 2) {
      return normalized;
    }
    return normalized.substring(0, 2);
  }
}

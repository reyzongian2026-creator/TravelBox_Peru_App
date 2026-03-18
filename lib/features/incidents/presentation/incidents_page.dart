import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../reservation/presentation/reservation_providers.dart';
import '../data/evidence_picker.dart';
import '../data/selected_evidence_image.dart';

final reservationIncidentsProvider =
    FutureProvider.family<List<ClientIncidentItem>, String>((
      ref,
      reservationId,
    ) async {
      ref.watch(reservationRealtimeEventCursorProvider);
      final dio = ref.read(dioProvider);
      final response = await dio.get<List<dynamic>>('/incidents');
      return (response.data ?? const [])
          .map(
            (item) => ClientIncidentItem.fromJson(item as Map<String, dynamic>),
          )
          .where((item) => item.reservationId == reservationId)
          .toList();
    });

class IncidentsPage extends ConsumerStatefulWidget {
  IncidentsPage({super.key, this.reservationId});

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
            message: 'Debes ingresar desde una reserva para abrir un ticket.',
          ),
        ),
      );
    }

    final reservationAsync = ref.watch(
      reservationByIdProvider(widget.reservationId!),
    );
    final incidentsAsync = ref.watch(
      reservationIncidentsProvider(widget.reservationId!),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.t('soporte_e_incidencias'))),
      body: reservationAsync.when(
        data: (reservation) => _buildBody(context, reservation, incidentsAsync),
        loading: () => LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: 'No se pudo cargar la reserva: $error',
          onRetry: () =>
              ref.invalidate(reservationByIdProvider(widget.reservationId!)),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Reservation? reservation,
    AsyncValue<List<ClientIncidentItem>> incidentsAsync,
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
                    ? 'Incidencia operativa'
                    : 'Ticket de soporte',
              ),
              subtitle: Text(
                canAccessBackoffice && createsOperationalIncident
                    ? 'Al enviarla, la reserva pasara a estado INCIDENT para gestion interna.'
                    : 'Tu mensaje llegara al panel de soporte y podras adjuntar evidencia.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (reservation != null)
            Card(
              child: ListTile(
                title: Text(context.l10n.t('reserva_vinculada')),
                subtitle: Text(
                  'ID ${reservation.id} - ${reservation.warehouse.name}\n'
                  'Estado actual: ${reservation.status.label}',
                ),
                trailing: OutlinedButton(
                  onPressed: () => context.go('/reservation/${reservation.id}'),
                  child: Text(context.l10n.t('ver')),
                ),
              ),
            ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: category,
            items: [
              DropdownMenuItem(value: 'damage', child: Text(context.l10n.t('danio'))),
              DropdownMenuItem(value: 'delay', child: Text(context.l10n.t('retraso'))),
              DropdownMenuItem(
                value: 'wrong-item',
                child: Text(context.l10n.t('objeto_equivocado')),
              ),
              DropdownMenuItem(value: 'payment', child: Text(context.l10n.t('pago'))),
              DropdownMenuItem(value: 'other', child: Text(context.l10n.t('otro'))),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => category = value);
              }
            },
            decoration: InputDecoration(labelText: 'Categoria'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Comentario',
              hintText:
                  'Describe lo ocurrido. Si es pago pendiente, indica si ya pagaste en caja.',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: includePhotos,
            title: Text(context.l10n.t('adjuntar_evidencia_fotografica')),
            subtitle: Text(
              _selectedImage == null
                  ? 'Sube una imagen JPG, PNG o WEBP de hasta 5MB.'
                  : 'Imagen seleccionada: ${_selectedImage!.filename}',
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
                        ? 'Seleccionar imagen'
                        : 'Cambiar imagen',
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
            child: Text(submitting ? 'Enviando...' : 'Enviar ticket'),
          ),
          const SizedBox(height: 20),
          Text(
            'Tickets generados',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          incidentsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.inbox_outlined),
                    title: Text(context.l10n.t('aun_no_hay_tickets_para_esta_reserva')),
                    subtitle: Text(
                      'Cuando envies uno, aparecera aqui con su estado.',
                    ),
                  ),
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TicketCard(item: item),
                      ),
                    )
                    .toList(),
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
                    reservationIncidentsProvider(widget.reservationId!),
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
        const SnackBar(
          content: Text(
            'No se selecciono ninguna imagen o no esta disponible.',
          ),
        ),
      );
      return;
    }
    setState(() => _selectedImage = selected);
  }

  Future<void> _submit(Reservation? reservation) async {
    final reservationId = int.tryParse(widget.reservationId ?? '');
    if (reservationId == null) {
      _showSnackBar('Reserva invalida para abrir ticket.');
      return;
    }

    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      _showSnackBar('Describe el caso para continuar.');
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

      final response = await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>(
            '/incidents',
            data: {
              'reservationId': reservationId,
              'description': _buildDescription(
                comment: comment,
                evidenceUrl: evidenceUrl,
              ),
            },
          );

      ref.invalidate(reservationByIdProvider(widget.reservationId!));
      ref.invalidate(myReservationsProvider);
      ref.invalidate(adminReservationsProvider);
      ref.invalidate(adminReservationListProvider);
      ref.invalidate(reservationIncidentsProvider(widget.reservationId!));

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
                ? 'Incidencia #$incidentId registrada correctamente.'
                : 'Ticket de soporte #$incidentId enviado correctamente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('No se pudo enviar el ticket: ${_errorMessage(error)}');
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
    final image = _selectedImage;
    if (image == null) {
      throw StateError('No hay imagen seleccionada.');
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
      throw StateError('No se recibio URL de la evidencia.');
    }
    return url.trim();
  }

  String _buildDescription({required String comment, String? evidenceUrl}) {
    final prefix = '[${_categoryLabel(category)}] ';
    final suffix = evidenceUrl == null || evidenceUrl.isEmpty
        ? ''
        : '\nEVIDENCIA: $evidenceUrl';
    final availableForComment = 500 - prefix.length - suffix.length;
    final safeComment = availableForComment <= 0
        ? ''
        : _truncate(comment, availableForComment);
    return '$prefix$safeComment$suffix';
  }

  String _categoryLabel(String rawCategory) {
    switch (rawCategory) {
      case 'damage':
        return 'Danio';
      case 'delay':
        return 'Retraso';
      case 'wrong-item':
        return 'Objeto equivocado';
      case 'payment':
        return 'Pago';
      default:
        return 'Otro';
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
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final details = data['details'];
        final message = data['message']?.toString().trim();
        if (details is List && details.isNotEmpty) {
          return details.map((item) => item.toString()).join(' | ');
        }
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!.trim();
      }
    }
    return error.toString();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.item});

  final ClientIncidentItem item;

  @override
  Widget build(BuildContext context) {
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
                    'Ticket #${item.id}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(label: Text(item.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(item.cleanDescription),
            const SizedBox(height: 8),
            Text(
              'Creado: ${PeruTime.formatDateTime(item.createdAt)}',
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
            if (item.resolution != null &&
                item.resolution!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Resolucion: ${item.resolution}'),
            ],
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

  String get cleanDescription => description
      .replaceAll(_evidencePattern, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

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
}


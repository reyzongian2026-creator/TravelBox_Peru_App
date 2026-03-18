import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/state/qr_handoff_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/internal_message_translator.dart';
import '../../../shared/widgets/operation_guide.dart';
import '../../incidents/data/evidence_picker.dart';
import '../../incidents/data/selected_evidence_image.dart';
import '../../reservation/data/reservation_repository_impl.dart';
import '../../reservation/presentation/reservation_providers.dart';

final opsReservationsProvider = FutureProvider<List<Reservation>>((ref) async {
  ref.watch(reservationRealtimeEventCursorProvider);
  final session = ref.watch(sessionControllerProvider);
  final repository = ref.read(reservationRepositoryProvider);

  if (session.canAccessAdmin || session.isAdmin) {
    return repository.getAllReservations(size: 150);
  }

  if (session.isCourier) {
    final dio = ref.read(dioProvider);
    final response = await dio.get<List<dynamic>>(
      '/delivery-orders',
      queryParameters: {'activeOnly': false, 'scope': 'mine'},
    );
    final items = response.data ?? const [];
    final reservationIds = items
        .map((item) => (item as Map<String, dynamic>)['reservationId'])
        .whereType<Object>()
        .map((id) => id.toString())
        .toSet()
        .toList();

    final reservations = <Reservation>[];
    for (final reservationId in reservationIds) {
      final item = await repository.getReservationById(reservationId);
      if (item != null) {
        reservations.add(item);
      }
    }
    return reservations;
  }

  final userId = session.user?.id;
  if (userId == null) {
    return const [];
  }
  return repository.getReservationsByUser(userId);
});

class OpsQrHandoffPage extends ConsumerStatefulWidget {
  OpsQrHandoffPage({
    super.key,
    this.currentRoute = '/ops/qr-handoff',
    this.initialScannedValue,
  });

  final String currentRoute;
  final String? initialScannedValue;

  @override
  ConsumerState<OpsQrHandoffPage> createState() => _OpsQrHandoffPageState();
}

class _OpsQrHandoffPageState extends ConsumerState<OpsQrHandoffPage> {
  final _scanController = TextEditingController();
  final _deliveryCustomerMessageController = TextEditingController(
    text: 'Hola, por favor presenta tu QR para validar tu reserva y maleta.',
  );
  final _pickupPinInputController = TextEditingController();
  final _deliveryPinInputController = TextEditingController();
  String _customerLanguage = 'es';
  String _messageSourceLanguage = 'es';
  int _bagUnits = 1;
  String? _selectedReservationId;
  bool _processing = false;
  int _lastRealtimeCursor = -1;
  String? _pendingAutoScanValue;
  bool _autoScanScheduled = false;

  @override
  void initState() {
    super.initState();
    final initialScan = widget.initialScannedValue?.trim();
    if (initialScan != null && initialScan.isNotEmpty) {
      _pendingAutoScanValue = initialScan;
      _scanController.text = initialScan;
    }
    Future<void>.microtask(
      () => ref.read(qrHandoffControllerProvider.notifier).refreshApprovals(),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _deliveryCustomerMessageController.dispose();
    _pickupPinInputController.dispose();
    _deliveryPinInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final realtimeCursor = ref.watch(reservationRealtimeEventCursorProvider);
    if (_lastRealtimeCursor != realtimeCursor) {
      final shouldReload = _lastRealtimeCursor >= 0;
      _lastRealtimeCursor = realtimeCursor;
      if (shouldReload) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ref.invalidate(opsReservationsProvider);
          final controller = ref.read(qrHandoffControllerProvider.notifier);
          controller.refreshApprovals();
          final reservationId = _selectedReservationId;
          if (reservationId != null && reservationId.isNotEmpty) {
            controller.syncCase(reservationId);
          }
        });
      }
    }
    final reservationsAsync = ref.watch(opsReservationsProvider);
    final session = ref.watch(sessionControllerProvider);
    final canApproveOperator = session.canAccessAdmin || session.isAdmin;

    return AppShellScaffold(
      title: 'Operacion QR y PIN',
      currentRoute: widget.currentRoute,
      child: reservationsAsync.when(
        data: (reservations) {
          if (reservations.isEmpty) {
            return EmptyStateView(
              message:
                  'No hay reservas visibles para tu perfil. Crea una reserva o toma un servicio primero.',
              actionLabel: 'Recargar',
              onAction: () => ref.invalidate(opsReservationsProvider),
            );
          }

          final selectedReservation = _resolveSelectedReservation(reservations);
          final handoffState = ref.watch(qrHandoffControllerProvider);
          final selectedCase = selectedReservation == null
              ? null
              : handoffState.casesByReservationId[selectedReservation.id];

          _scheduleAutoScanIfNeeded(reservations);

          return LayoutBuilder(
            builder: (context, constraints) {
              final compactVerticalLayout = constraints.maxHeight < 720;
              return DefaultTabController(
                length: 4,
                child: Column(
                  children: [
                    _buildHeroHeader(
                      context: context,
                      selectedReservation: selectedReservation,
                      selectedCase: selectedCase,
                      compact: compactVerticalLayout,
                    ),
                    if (!compactVerticalLayout)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: OperationGuideSummaryCard(
                          guide: resolveOperationGuide('/ops/qr-handoff')!,
                          compact: true,
                        ),
                      ),
                    const TabBar(
                      tabs: [
                        Tab(
                          icon: Icon(Icons.qr_code_scanner),
                          text: 'Escanear',
                        ),
                        Tab(
                          icon: Icon(Icons.storefront_outlined),
                          text: 'Presencial',
                        ),
                        Tab(
                          icon: Icon(Icons.local_shipping_outlined),
                          text: 'Delivery',
                        ),
                        Tab(
                          icon: Icon(Icons.notifications_active_outlined),
                          text: 'Aprobaciones',
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildScanTab(reservations, selectedReservation),
                          _buildPresentialTab(
                            selectedReservation,
                            selectedCase,
                          ),
                          _buildDeliveryTab(selectedReservation, selectedCase),
                          _buildApprovalsTab(
                            selectedReservation: selectedReservation,
                            selectedCase: selectedCase,
                            canApproveOperator: canApproveOperator,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: 'No se pudo cargar módulo QR/PIN: $error',
          onRetry: () => ref.invalidate(opsReservationsProvider),
        ),
      ),
    );
  }

  Widget _buildHeroHeader({
    required BuildContext context,
    required Reservation? selectedReservation,
    required QrHandoffCase? selectedCase,
    required bool compact,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, compact ? 6 : 10),
      padding: EdgeInsets.all(compact ? 13 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B8B8C), Color(0xFF2A9BC0)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QR + Pin + validaciones de equipaje',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 20 : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedReservation == null
                ? 'Escanea o ingresa un QR para vincular una reserva y continuar.'
                : 'Reserva seleccionada: ${selectedReservation.code} - ${selectedCase?.stage.label ?? 'sin etapa'}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.94)),
          ),
        ],
      ),
    );
  }

  Widget _buildScanTab(
    List<Reservation> reservations,
    Reservation? selectedReservation,
  ) {
    final selectedCase = selectedReservation == null
        ? null
        : ref
              .watch(qrHandoffControllerProvider)
              .casesByReservationId[selectedReservation.id];
    final languageEntries = const <String, String>{
      'es': 'Español',
      'en': 'English',
      'de': 'Deutsch',
      'fr': 'Français',
      'it': 'Italiano',
      'pt': 'Português',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _scanController,
          decoration: const InputDecoration(
            labelText: 'Escanear QR o código',
            hintText: 'Ejemplo: TRAVELBOX|RESERVATION|TBX-12345 o TBX-12345',
            prefixIcon: Icon(Icons.qr_code_scanner),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _processing
                  ? null
                  : () => _onScanReservation(reservations: reservations),
              icon: const Icon(Icons.search),
              label: Text(context.l10n.t('buscar_reserva')),
            ),
            OutlinedButton.icon(
              onPressed: _processing
                  ? null
                  : () => ref.invalidate(opsReservationsProvider),
              icon: Icon(Icons.refresh),
              label: Text(context.l10n.t('recargar')),
            ),
          ],
        ),
        SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _customerLanguage,
          decoration: const InputDecoration(
            labelText: 'Idioma del cliente para mensajes',
          ),
          items: languageEntries.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _customerLanguage = value);
            }
          },
        ),
        const SizedBox(height: 14),
        if (selectedReservation == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Aún no hay reserva seleccionada. Escanea el QR del cliente para continuar.',
              ),
            ),
          )
        else ...[
          _ReservationContextCard(
            reservation: selectedReservation,
            stageLabel: selectedCase?.stage.label ?? 'Sin etapa',
          ),
          const SizedBox(height: 12),
          _QrPairCard(
            title: 'QR cliente',
            subtitle: 'Se usa para ubicar reserva y validar identidad inicial.',
            payload:
                selectedCase?.customerQrPayload ??
                'TRAVELBOX|RESERVATION|${selectedReservation.code}',
          ),
          const SizedBox(height: 12),
          _QrPairCard(
            title: 'QR maleta',
            subtitle:
                'Etiqueta operativa para pegar a la maleta y hacer match con la reserva.',
            payload: selectedCase?.bagTagQrPayload,
            emptyLabel:
                'Aún no hay ID de maleta. Genera etiqueta para registrar custodia.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(context.l10n.t('bultos')),
              SizedBox(width: 8),
              DropdownButton<int>(
                value: _bagUnits,
                items: List.generate(
                  10,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text('${index + 1}'),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _bagUnits = value);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _processing
                    ? null
                    : () => _tagLuggageForReservation(selectedReservation),
                icon: const Icon(Icons.local_offer_outlined),
                label: Text(context.l10n.t('generar_id_maleta')),
              ),
              FilledButton.tonalIcon(
                onPressed: _processing
                    ? null
                    : () => _markStoredAtWarehouse(selectedReservation),
                icon: Icon(Icons.inventory_2_outlined),
                label: Text(context.l10n.t('registrar_en_almacn')),
              ),
              FilledButton.icon(
                onPressed: _processing
                    ? null
                    : () => _markReadyForPickup(selectedReservation),
                icon: Icon(Icons.key_outlined),
                label: Text(context.l10n.t('lista_para_recojo__pin')),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPresentialTab(
    Reservation? selectedReservation,
    QrHandoffCase? selectedCase,
  ) {
    if (selectedReservation == null || selectedCase == null) {
      return EmptyStateView(
        message: 'Selecciona una reserva en la pestaña Escanear.',
      );
    }

    final translatedPreview = translateAdminMessage(
      messageInSpanish:
          'Tu reserva está lista para recojo. Presenta tu QR y PIN de seguridad.',
      targetLanguage: selectedCase.customerLanguage,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ReservationContextCard(
          reservation: selectedReservation,
          stageLabel: selectedCase.stage.label,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flujo presencial',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text('ID maleta: ${selectedCase.bagTagId ?? 'No generado'}'),
                Text('PIN activo: ${selectedCase.pickupPin ?? 'No generado'}'),
                const SizedBox(height: 8),
                Text(
                  'Mensaje cliente (${selectedCase.customerLanguage.toUpperCase()}): $translatedPreview',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _processing
                  ? null
                  : () => _runAction(() async {
                      await ref
                          .read(qrHandoffControllerProvider.notifier)
                          .regeneratePickupPin(selectedReservation.id);
                    }),
              icon: const Icon(Icons.password_outlined),
              label: Text(context.l10n.t('regenerar_pin')),
            ),
            OutlinedButton.icon(
              onPressed: _processing
                  ? null
                  : () => _markReadyForPickup(selectedReservation),
              icon: Icon(Icons.inventory_2_outlined),
              label: Text(context.l10n.t('reforzar_listo_para_recojo')),
            ),
          ],
        ),
        SizedBox(height: 16),
        TextField(
          controller: _pickupPinInputController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'PIN entregado por cliente',
            hintText: 'Ingresa el PIN para confirmar entrega presencial',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _processing
              ? null
              : () => _confirmPresentialDelivery(selectedReservation.id),
          icon: const Icon(Icons.check_circle_outline),
          label: Text(context.l10n.t('confirmar_entrega_presencial')),
        ),
      ],
    );
  }

  Widget _buildDeliveryTab(
    Reservation? selectedReservation,
    QrHandoffCase? selectedCase,
  ) {
    if (selectedReservation == null || selectedCase == null) {
      return EmptyStateView(
        message: 'Selecciona una reserva en la pestaña Escanear.',
      );
    }

    final translation = translateBidirectionalMessage(
      originalMessage: _deliveryCustomerMessageController.text,
      sourceLanguage: _messageSourceLanguage,
      customerLanguage: selectedCase.customerLanguage,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ReservationContextCard(
          reservation: selectedReservation,
          stageLabel: selectedCase.stage.label,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: selectedCase.identityValidated,
          onChanged: _processing
              ? null
              : (value) => _runAction(() async {
                  await ref
                      .read(qrHandoffControllerProvider.notifier)
                      .setDeliveryIdentityValidated(
                        reservationId: selectedReservation.id,
                        value: value,
                      );
                }),
          title: Text(context.l10n.t('validar_identidad_de_quien_recibe')),
          subtitle: Text(
            'El courier verifica nombre/documento antes de entregar.',
          ),
        ),
        SwitchListTile(
          value: selectedCase.luggageMatched,
          onChanged: _processing
              ? null
              : (value) => _runAction(() async {
                  await ref
                      .read(qrHandoffControllerProvider.notifier)
                      .setDeliveryLuggageMatched(
                        reservationId: selectedReservation.id,
                        value: value,
                      );
                }),
          title: Text(context.l10n.t('validar_que_maleta_e_id_coincidan')),
          subtitle: Text('ID esperado: ${selectedCase.bagTagId ?? '-'}'),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _deliveryCustomerMessageController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText:
                'Mensaje de cliente (${languageLabel(_messageSourceLanguage)})',
            hintText:
                'Ej. Hello, please show your QR to validate your reservation and luggage.',
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _messageSourceLanguage,
          decoration: const InputDecoration(
            labelText: 'Idioma original del mensaje',
          ),
          items: const ['es', 'en', 'de', 'fr', 'it', 'pt']
              .map(
                (code) => DropdownMenuItem(
                  value: code,
                  child: Text(languageLabel(code)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _messageSourceLanguage = value);
          },
        ),
        const SizedBox(height: 8),
        Card(
          color: const Color(0xFFF5FAFF),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Vista operador (ES):\n${translation.messageInSpanish}\n\n'
              'Vista cliente (${selectedCase.customerLanguage.toUpperCase()}):\n${translation.messageForCustomerLanguage}',
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: _processing
              ? null
              : () =>
                    _requestOperatorApproval(selectedReservation, selectedCase),
          icon: const Icon(Icons.campaign_outlined),
          label: Text(context.l10n.t('solicitar_aprobacin_al_operador')),
        ),
        SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(context.l10n.t('pin_para_cierre_delivery')),
            subtitle: Text(
              selectedCase.operatorApprovalGranted
                  ? 'PIN aprobado: ${selectedCase.pickupPin ?? '-'}'
                  : 'Aún no aprobado por operador/admin.',
            ),
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _deliveryPinInputController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'PIN confirmado por cliente',
            hintText: 'Courier valida el PIN recibido para cerrar entrega',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _processing
              ? null
              : () => _confirmDeliveryWithPin(selectedReservation.id),
          icon: const Icon(Icons.verified_outlined),
          label: Text(context.l10n.t('completar_entrega_delivery')),
        ),
      ],
    );
  }

  Widget _buildApprovalsTab({
    required Reservation? selectedReservation,
    required QrHandoffCase? selectedCase,
    required bool canApproveOperator,
  }) {
    final handoffState = ref.watch(qrHandoffControllerProvider);
    final notifications = handoffState.approvalNotifications;

    if (notifications.isEmpty) {
      return EmptyStateView(
        message: 'No hay solicitudes de aprobación pendientes.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = notifications[index];
        final isRelated = selectedReservation?.id == item.reservationId;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      item.reservationCode,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Chip(
                      label: Text(item.status.label),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (isRelated)
                      Chip(
                        label: Text(context.l10n.t('reserva_activa')),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                SizedBox(height: 6),
                Text('Operador: ${item.messageForOperator}'),
                const SizedBox(height: 4),
                Text(
                  'Cliente (traducido): ${item.messageForCustomerTranslated}',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canApproveOperator &&
                        item.status == OpsApprovalStatus.pending)
                      FilledButton.icon(
                        onPressed: _processing
                            ? null
                            : () => _approveNotification(item),
                        icon: const Icon(Icons.verified_user_outlined),
                        label: Text(context.l10n.t('aprobar_y_generar_pin')),
                      ),
                    OutlinedButton.icon(
                      onPressed: _processing
                          ? null
                          : () => _runAction(
                              () async => ref
                                  .read(qrHandoffControllerProvider.notifier)
                                  .dismissNotification(item.id),
                            ),
                      icon: Icon(Icons.notifications_off_outlined),
                      label: Text(context.l10n.t('ocultar')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Reservation? _resolveSelectedReservation(List<Reservation> reservations) {
    final selectedId = _selectedReservationId;
    if (selectedId == null) {
      return null;
    }
    for (final item in reservations) {
      if (item.id == selectedId) {
        return item;
      }
    }
    return null;
  }

  void _scheduleAutoScanIfNeeded(List<Reservation> reservations) {
    final pending = _pendingAutoScanValue?.trim();
    if (pending == null || pending.isEmpty) {
      return;
    }
    if (_autoScanScheduled || _processing) {
      return;
    }
    _autoScanScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _onScanReservation(reservations: reservations);
      if (!mounted) return;
      setState(() {
        _pendingAutoScanValue = null;
      });
      _autoScanScheduled = false;
    });
  }

  Future<void> _onScanReservation({
    required List<Reservation> reservations,
  }) async {
    final scanned = _scanController.text.trim();
    if (scanned.isEmpty) {
      _showMessage('Ingresa o escanea un código QR primero.');
      return;
    }
    final controller = ref.read(qrHandoffControllerProvider.notifier);
    final reservation = controller.findReservationByQr(
      scannedValue: scanned,
      reservations: reservations,
    );
    if (reservation == null) {
      _showMessage('No se encontro reserva para el QR ingresado.');
      return;
    }
    await _runAction(() async {
      final caseItem = await controller.validateReservationQr(
        reservation: reservation,
        customerLanguage: _customerLanguage,
        scannedValue: scanned,
      );
      setState(() {
        _selectedReservationId = caseItem.reservationId;
        _bagUnits = reservation.bagCount.clamp(1, 10);
        _messageSourceLanguage = caseItem.customerLanguage;
      });
      _showMessage('Reserva ${reservation.code} vinculada por QR.');
    });
  }

  Future<void> _markStoredAtWarehouse(Reservation reservation) async {
    final caseItem = ref
        .read(qrHandoffControllerProvider)
        .casesByReservationId[reservation.id];
    final validationError = _validateStoreInWarehouseAction(
      reservation: reservation,
      caseItem: caseItem,
    );
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }
    final expectedPhotos = (caseItem?.bagUnits ?? reservation.bagCount).clamp(
      1,
      20,
    );
    final bagPhotos = await _collectBagPhotos(expectedPhotos);
    if (!mounted || bagPhotos == null) {
      return;
    }

    await _runAction(() async {
      final response = await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>(
            '/ops/qr-handoff/reservations/${reservation.id}/store-with-photos',
            data: FormData.fromMap({
              'notes': 'Ingreso a almacén con fotos por bulto.',
              'files': bagPhotos
                  .map(
                    (image) => MultipartFile.fromBytes(
                      image.bytes,
                      filename: image.filename,
                      contentType: MediaType.parse(image.mimeType),
                    ),
                  )
                  .toList(),
            }),
          );
      final payload = response.data ?? const <String, dynamic>{};
      if (payload.isNotEmpty) {
        await ref
            .read(qrHandoffControllerProvider.notifier)
            .syncCase(reservation.id);
      }
      ref.invalidate(opsReservationsProvider);
      ref.invalidate(reservationByIdProvider(reservation.id));
      ref.invalidate(myReservationsProvider);
      ref.invalidate(adminReservationsProvider);
      ref.invalidate(adminReservationListProvider);
      _showMessage('Reserva ${reservation.code} registrada en almacén.');
    });
  }

  Future<void> _markReadyForPickup(Reservation reservation) async {
    final caseItem = ref
        .read(qrHandoffControllerProvider)
        .casesByReservationId[reservation.id];
    final validationError = _validateReadyForPickupAction(
      reservation: reservation,
      caseItem: caseItem,
    );
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    await _runAction(() async {
      final caseItem = await ref
          .read(qrHandoffControllerProvider.notifier)
          .markReadyForPickup(reservation.id);
      ref.invalidate(opsReservationsProvider);
      _showMessage(
        'PIN ${caseItem.pickupPin} generado. La reserva está lista para recojo.',
      );
    });
  }

  Future<void> _confirmPresentialDelivery(String reservationId) async {
    final pin = _pickupPinInputController.text.trim();
    if (pin.isEmpty) {
      _showMessage('Ingresa el PIN del cliente para confirmar entrega.');
      return;
    }
    if (!_isSixDigitPin(pin)) {
      _showMessage('El PIN debe tener 6 dígitos numéricos.');
      return;
    }

    final caseItem = ref
        .read(qrHandoffControllerProvider)
        .casesByReservationId[reservationId];
    if (caseItem == null) {
      _showMessage('Primero escanea y valida el QR de la reserva.');
      return;
    }

    await _runAction(() async {
      final validated = await ref
          .read(qrHandoffControllerProvider.notifier)
          .validatePickupPin(reservationId: reservationId, typedPin: pin);
      if (!validated) {
        _showMessage('PIN incorrecto. Verifica con el cliente.');
        return;
      }
      ref.invalidate(opsReservationsProvider);
      _pickupPinInputController.clear();
      _showMessage('Entrega presencial confirmada y reserva completada.');
    });
  }

  Future<void> _requestOperatorApproval(
    Reservation reservation,
    QrHandoffCase caseItem,
  ) async {
    await _runAction(() async {
      final messageEs = _deliveryCustomerMessageController.text.trim();
      final translation = translateBidirectionalMessage(
        originalMessage: messageEs,
        sourceLanguage: _messageSourceLanguage,
        customerLanguage: caseItem.customerLanguage,
      );
      await ref
          .read(qrHandoffControllerProvider.notifier)
          .requestOperatorApproval(
            reservationId: reservation.id,
            reservationCode: reservation.code,
            messageForOperator:
                'Courier solicita aprobación para entrega final de ${reservation.code}.',
            messageForCustomerInSpanish: translation.messageInSpanish,
            customerLanguage: caseItem.customerLanguage,
          );
      await ref
          .read(reservationRepositoryProvider)
          .updateStatus(
            reservationId: reservation.id,
            status: ReservationStatus.outForDelivery,
            message:
                'Solicitud de aprobación enviada al operador. Mensaje cliente: ${translation.messageForCustomerLanguage}',
          );
      ref.invalidate(opsReservationsProvider);
      _showMessage(
        'Solicitud enviada al operador. Cliente recibirá mensaje traducido.',
      );
    });
  }

  Future<void> _approveNotification(OpsApprovalNotification item) async {
    await _runAction(() async {
      final caseItem = await ref
          .read(qrHandoffControllerProvider.notifier)
          .approveOperatorHandoff(notificationId: item.id);
      _showMessage(
        'Aprobacion concedida para ${item.reservationCode}. PIN ${caseItem.pickupPin}.',
      );
    });
  }

  Future<void> _confirmDeliveryWithPin(String reservationId) async {
    final pin = _deliveryPinInputController.text.trim();
    if (pin.isEmpty) {
      _showMessage('Ingresa el PIN final para cerrar la entrega.');
      return;
    }
    if (!_isSixDigitPin(pin)) {
      _showMessage('El PIN debe tener 6 dígitos numéricos.');
      return;
    }

    final caseItem = ref
        .read(qrHandoffControllerProvider)
        .casesByReservationId[reservationId];
    if (caseItem == null) {
      _showMessage('Primero escanea y valida el QR de la reserva.');
      return;
    }
    if (!caseItem.identityValidated) {
      _showMessage('Falta validar identidad del receptor.');
      return;
    }
    if (!caseItem.luggageMatched) {
      _showMessage('Falta validar coincidencia de maleta e ID.');
      return;
    }
    if (!caseItem.operatorApprovalGranted) {
      _showMessage('Falta aprobación del operador/admin.');
      return;
    }

    await _runAction(() async {
      final ok = await ref
          .read(qrHandoffControllerProvider.notifier)
          .completeDeliveryWithPin(reservationId: reservationId, typedPin: pin);
      if (!ok) {
        _showMessage(
          'No se pudo completar: verifica identidad, maleta y aprobación operador.',
        );
        return;
      }
      ref.invalidate(opsReservationsProvider);
      _deliveryPinInputController.clear();
      _showMessage('Entrega delivery completada correctamente.');
    });
  }

  Future<void> _tagLuggageForReservation(Reservation reservation) async {
    final validationError = _validateBagTagAction(reservation);
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    await _runAction(() async {
      await ref
          .read(qrHandoffControllerProvider.notifier)
          .tagLuggage(reservation: reservation, bagUnits: _bagUnits);
      _showMessage(
        'ID de maleta generado para ${reservation.code} ($_bagUnits bulto(s)).',
      );
    });
  }

  String? _validateBagTagAction(Reservation reservation) {
    if (_bagUnits < 1 || _bagUnits > 20) {
      return 'Selecciona entre 1 y 20 bultos para generar la etiqueta.';
    }
    if (_isReservationClosed(reservation.status)) {
      return 'No puedes registrar maleta para una reserva ${reservation.status.label.toLowerCase()}.';
    }
    if (reservation.status == ReservationStatus.pendingPayment ||
        reservation.status == ReservationStatus.draft) {
      return 'La reserva aún no está habilitada para registrar maleta.';
    }
    return null;
  }

  String? _validateStoreInWarehouseAction({
    required Reservation reservation,
    required QrHandoffCase? caseItem,
  }) {
    if (caseItem == null) {
      return 'Primero escanea el QR de la reserva.';
    }
    if ((caseItem.bagTagId ?? '').trim().isEmpty) {
      return 'Primero genera el ID/QR de maleta antes de registrar en almacén.';
    }
    if (reservation.status == ReservationStatus.stored) {
      return 'Esta reserva ya figura registrada en almacén.';
    }
    if (reservation.status != ReservationStatus.confirmed &&
        reservation.status != ReservationStatus.checkinPending) {
      return 'No se puede registrar en almacén con estado ${reservation.status.label}.';
    }
    return null;
  }

  String? _validateReadyForPickupAction({
    required Reservation reservation,
    required QrHandoffCase? caseItem,
  }) {
    if (caseItem == null) {
      return 'Primero escanea el QR de la reserva.';
    }
    if ((caseItem.bagTagId ?? '').trim().isEmpty) {
      return 'Primero genera el ID/QR de maleta.';
    }
    if (reservation.status != ReservationStatus.stored &&
        reservation.status != ReservationStatus.readyForPickup) {
      return 'No se puede generar PIN de recojo con estado ${reservation.status.label}.';
    }
    return null;
  }

  bool _isReservationClosed(ReservationStatus status) {
    return status == ReservationStatus.completed ||
        status == ReservationStatus.cancelled ||
        status == ReservationStatus.expired;
  }

  bool _isSixDigitPin(String value) {
    return RegExp(r'^\d{6}$').hasMatch(value.trim());
  }

  Future<List<SelectedEvidenceImage>?> _collectBagPhotos(int bagUnits) {
    return showDialog<List<SelectedEvidenceImage>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BagPhotoDialog(requiredPhotos: bagUnits),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await action();
    } catch (error) {
      final readable = AppErrorFormatter.readable(error);
      _showMessage('No se pudo completar la accion: $readable');
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _ReservationContextCard extends StatelessWidget {
  _ReservationContextCard({
    required this.reservation,
    required this.stageLabel,
  });

  final Reservation reservation;
  final String stageLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reservation.code,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${reservation.warehouse.name} - ${reservation.warehouse.city}',
            ),
            Text('Bultos: ${reservation.bagCount}'),
            Text('Estado reserva: ${reservation.status.label}'),
            Text('Estado QR/PIN: $stageLabel'),
          ],
        ),
      ),
    );
  }
}

class _QrPairCard extends StatelessWidget {
  const _QrPairCard({
    required this.title,
    required this.subtitle,
    required this.payload,
    this.emptyLabel,
  });

  final String title;
  final String subtitle;
  final String? payload;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final value = payload?.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8FB),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: value == null || value.isEmpty
                  ? const Icon(Icons.qr_code_2_outlined)
                  : QrImageView(
                      data: value,
                      size: 98,
                      backgroundColor: Colors.white,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                  const SizedBox(height: 6),
                  Text(
                    value == null || value.isEmpty
                        ? (emptyLabel ?? '-')
                        : value,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BagPhotoDialog extends StatefulWidget {
  const _BagPhotoDialog({required this.requiredPhotos});

  final int requiredPhotos;

  @override
  State<_BagPhotoDialog> createState() => _BagPhotoDialogState();
}

class _BagPhotoDialogState extends State<_BagPhotoDialog> {
  late final List<SelectedEvidenceImage?> _selected =
      List<SelectedEvidenceImage?>.filled(widget.requiredPhotos, null);
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    final completed = _selected.every((item) => item != null);
    return AlertDialog(
      title: Text(context.l10n.t('fotos_del_equipaje')),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Debes registrar ${widget.requiredPhotos} foto(s), una por cada bulto. Estas imágenes quedarán cerradas al confirmar el ingreso a almacén.',
              ),
              SizedBox(height: 14),
              ...List.generate(widget.requiredPhotos, (index) {
                final current = _selected[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bulto ${index + 1}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          if (current != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                current.bytes,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F7F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD4DCE3),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Aún no hay imagen seleccionada',
                              ),
                            ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _picking
                                    ? null
                                    : () => _pickForIndex(index),
                                icon: const Icon(Icons.upload_file_outlined),
                                label: Text(
                                  current == null
                                      ? 'Seleccionar imagen'
                                      : 'Cambiar imagen',
                                ),
                              ),
                              if (current != null)
                                OutlinedButton.icon(
                                  onPressed: _picking
                                      ? null
                                      : () => setState(
                                          () => _selected[index] = null,
                                        ),
                                  icon: const Icon(Icons.close),
                                  label: Text(context.l10n.t('quitar')),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _picking ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.t('cancelar')),
        ),
        FilledButton(
          onPressed: _picking || !completed
              ? null
              : () => Navigator.of(
                  context,
                ).pop(_selected.whereType<SelectedEvidenceImage>().toList()),
          child: Text(
            completed
                ? 'Confirmar ${widget.requiredPhotos} fotos'
                : 'Faltan fotos',
          ),
        ),
      ],
    );
  }

  Future<void> _pickForIndex(int index) async {
    setState(() => _picking = true);
    try {
      final selected = await pickEvidenceImage();
      if (!mounted || selected == null) {
        return;
      }
      setState(() => _selected[index] = selected);
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }
}


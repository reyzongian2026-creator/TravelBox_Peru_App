import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/state/luggage_photo_memory_store.dart';
import '../../../shared/state/qr_handoff_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/internal_message_translator.dart';
import '../../../shared/utils/status_localizer.dart';
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
  const OpsQrHandoffPage({
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
  late final TextEditingController _deliveryCustomerMessageController;
  final _pickupPinInputController = TextEditingController();
  final _deliveryPinInputController = TextEditingController();
  String _customerLanguage = 'es';
  String _messageSourceLanguage = 'es';
  int _bagUnits = 1;
  String? _selectedReservationId;
  bool _processing = false;
  double? _storeUploadProgress;
  int _lastRealtimeCursor = -1;
  String? _pendingAutoScanValue;
  bool _autoScanScheduled = false;

  @override
  void initState() {
    super.initState();
    _deliveryCustomerMessageController = TextEditingController();
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
      title: context.l10n.t('ops_qr_title'),
      currentRoute: widget.currentRoute,
      child: reservationsAsync.when(
        data: (reservations) {
          if (reservations.isEmpty) {
            return EmptyStateView(
              message: context.l10n.t('ops_qr_empty_reservations'),
              actionLabel: context.l10n.t('recargar'),
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
                    if (!compactVerticalLayout &&
                        session.locale.languageCode.toLowerCase() == 'es')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: OperationGuideSummaryCard(
                          guide: resolveOperationGuide('/ops/qr-handoff')!,
                          compact: true,
                        ),
                      ),
                    TabBar(
                      tabs: [
                        Tab(
                          icon: Icon(Icons.qr_code_scanner),
                          text: context.l10n.t('ops_qr_tab_scan'),
                        ),
                        Tab(
                          icon: Icon(Icons.storefront_outlined),
                          text: context.l10n.t('ops_qr_tab_presential'),
                        ),
                        Tab(
                          icon: Icon(Icons.local_shipping_outlined),
                          text: context.l10n.t('delivery'),
                        ),
                        Tab(
                          icon: Icon(Icons.notifications_active_outlined),
                          text: context.l10n.t('ops_qr_tab_approvals'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, tabBarConstraints) {
                          return TabBarView(
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
                          );
                        },
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
          message: '${context.l10n.t('ops_qr_load_failed')}: $error',
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
            context.l10n.t('admin_dashboard_qr_pin_subtitle'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 20 : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedReservation == null
                ? context.l10n.t('ops_qr_header_hint_empty')
                : '${context.l10n.t('ops_qr_header_selected_prefix')}: '
                      '${selectedReservation.code} - '
                      '${_stageLabel(context, selectedCase?.stage)}',
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
    final languageEntries = <String, String>{
      'es': context.l10n.t('spanish'),
      'en': context.l10n.t('english'),
      'de': context.l10n.t('deutsch'),
      'fr': context.l10n.t('francais'),
      'it': context.l10n.t('italiano'),
      'pt': context.l10n.t('portugues'),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _scanController,
          decoration: InputDecoration(
            labelText: context.l10n.t('ops_qr_scan_input_label'),
            hintText: context.l10n.t('ops_qr_scan_input_hint'),
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
          decoration: InputDecoration(
            labelText: context.l10n.t('ops_qr_customer_language_for_messages'),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.t('ops_qr_no_selected_reservation_hint'),
              ),
            ),
          )
        else ...[
          _ReservationContextCard(
            reservation: selectedReservation,
            stageLabel: _stageLabel(context, selectedCase?.stage),
          ),
          const SizedBox(height: 12),
          _QrPairCard(
            title: context.l10n.t('ops_qr_customer_qr_title'),
            subtitle: context.l10n.t('ops_qr_customer_qr_subtitle'),
            payload:
                selectedCase?.customerQrPayload ??
                'TRAVELBOX|RESERVATION|${selectedReservation.code}',
          ),
          const SizedBox(height: 12),
          _QrPairCard(
            title: context.l10n.t('ops_qr_bag_qr_title'),
            subtitle: context.l10n.t('ops_qr_bag_qr_subtitle'),
            payload: selectedCase?.bagTagQrPayload,
            emptyLabel: context.l10n.t('ops_qr_bag_qr_empty'),
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
          if (_storeUploadProgress != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _storeUploadProgress),
            const SizedBox(height: 6),
            Text(
              '${context.l10n.t('ops_qr_uploading_photos_prefix')}: '
              '${((_storeUploadProgress ?? 0) * 100).toStringAsFixed(0)}%',
            ),
          ],
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
        message: context.l10n.t('ops_qr_select_reservation_scan_tab'),
      );
    }

    final translatedPreview = translateAdminMessage(
      messageInSpanish: context.l10n.t('ops_qr_customer_ready_for_pickup_msg'),
      targetLanguage: selectedCase.customerLanguage,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ReservationContextCard(
          reservation: selectedReservation,
          stageLabel: _stageLabel(context, selectedCase.stage),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('ops_qr_presential_flow_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.l10n.t('reservation_bag_id')}: '
                  '${selectedCase.bagTagId ?? context.l10n.t('ops_qr_not_generated')}',
                ),
                Text(
                  '${context.l10n.t('reservation_pin_active_prefix')}: '
                  '${selectedCase.pickupPin ?? context.l10n.t('ops_qr_not_generated')}',
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.l10n.t('ops_qr_customer_message_prefix')} '
                  '(${selectedCase.customerLanguage.toUpperCase()}): $translatedPreview',
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
          decoration: InputDecoration(
            labelText: context.l10n.t('ops_qr_pin_from_customer_label'),
            hintText: context.l10n.t('ops_qr_pin_from_customer_hint'),
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
        message: context.l10n.t('ops_qr_select_reservation_scan_tab'),
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
          stageLabel: _stageLabel(context, selectedCase.stage),
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
          subtitle: Text(context.l10n.t('ops_qr_delivery_identity_hint')),
        ),
        SwitchListTile(
          value: selectedCase.luggageMatched,
          onChanged: _processing || !selectedCase.identityValidated
              ? null
              : (value) => _runAction(() async {
                  if (!selectedCase.identityValidated) {
                    _showMessage(context.l10n.t('ops_qr_validate_identity_first'));
                    return;
                  }
                  await ref
                      .read(qrHandoffControllerProvider.notifier)
                      .setDeliveryLuggageMatched(
                        reservationId: selectedReservation.id,
                        value: value,
                      );
                }),
          title: Text(context.l10n.t('validar_que_maleta_e_id_coincidan')),
          subtitle: Text(
            !selectedCase.identityValidated
                ? context.l10n.t('ops_qr_validate_identity_first')
                : '${context.l10n.t('ops_qr_expected_id_prefix')}: ${selectedCase.bagTagId ?? '-'}',
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _deliveryCustomerMessageController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText:
                '${context.l10n.t('ops_qr_customer_message_label')} '
                '(${languageLabel(_messageSourceLanguage)})',
            hintText: context.l10n.t('ops_qr_customer_message_hint'),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _messageSourceLanguage,
          decoration: InputDecoration(
            labelText: context.l10n.t('ops_qr_message_source_language_label'),
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
              '${context.l10n.t('ops_qr_operator_view_prefix')} (ES):\n'
              '${translation.messageInSpanish}\n\n'
              '${context.l10n.t('ops_qr_customer_view_prefix')} '
              '(${selectedCase.customerLanguage.toUpperCase()}):\n'
              '${translation.messageForCustomerLanguage}',
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
                  ? '${context.l10n.t('ops_qr_pin_approved_prefix')}: '
                        '${selectedCase.pickupPin ?? '-'}'
                  : context.l10n.t('ops_qr_pin_not_approved_yet'),
            ),
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _deliveryPinInputController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.l10n.t('ops_qr_pin_confirmed_by_customer_label'),
            hintText: context.l10n.t('ops_qr_pin_confirmed_by_customer_hint'),
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
        message: context.l10n.t('ops_qr_no_pending_approvals'),
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
                      label: Text(_approvalStatusLabel(context, item.status)),
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
                Text(
                  '${context.l10n.t('ops_qr_operator_message_prefix')}: '
                  '${item.messageForOperator}',
                ),
                const SizedBox(height: 4),
                Text(
                  '${context.l10n.t('ops_qr_customer_translated_prefix')}: '
                  '${item.messageForCustomerTranslated}',
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
      _showMessage(context.l10n.t('ops_qr_scan_or_enter_code_first'));
      return;
    }
    final controller = ref.read(qrHandoffControllerProvider.notifier);
    final reservation = controller.findReservationByQr(
      scannedValue: scanned,
      reservations: reservations,
    );
    if (reservation == null) {
      _showMessage(context.l10n.t('ops_qr_reservation_not_found_for_qr'));
      return;
    }
    await _runAction(() async {
      final caseItem = await controller.validateReservationQr(
        reservation: reservation,
        customerLanguage: _customerLanguage,
        scannedValue: scanned,
      );
      if (!mounted) return;
      setState(() {
        _selectedReservationId = caseItem.reservationId;
        _bagUnits = reservation.bagCount.clamp(1, 10);
        _messageSourceLanguage = caseItem.customerLanguage;
      });
      _showMessage(
        '${context.l10n.t('ops_qr_reservation_linked_prefix')} '
        '${reservation.code}.',
      );
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
      setState(() {
        _storeUploadProgress = 0;
      });
      final session = ref.read(sessionControllerProvider);
      ref
          .read(luggagePhotoMemoryStoreProvider.notifier)
          .addWarehouseBagPhotos(
            reservation: reservation,
            photos: bagPhotos
                .map(
                  (image) => MemoryBagPhotoInput(
                    bytes: image.bytes,
                    mimeType: image.mimeType,
                    filename: image.filename,
                  ),
                )
                .toList(growable: false),
            capturedByUserId: session.user?.id,
            capturedByName: session.user?.name,
          );
      setState(() {
        _storeUploadProgress = 0.65;
      });
      await ref
          .read(qrHandoffControllerProvider.notifier)
          .markStoredAtWarehouse(reservation.id);
      if (!mounted) return;
      ref.invalidate(opsReservationsProvider);
      ref.invalidate(reservationByIdProvider(reservation.id));
      ref.invalidate(myReservationsProvider);
      ref.invalidate(adminReservationsProvider);
      ref.invalidate(adminReservationListProvider);
      _showMessage(
        '${context.l10n.t('ops_qr_reservation_registered_warehouse_prefix')} '
        '${reservation.code}.',
      );
      if (mounted) {
        setState(() {
          _storeUploadProgress = null;
        });
      }
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
      if (!mounted) return;
      ref.invalidate(opsReservationsProvider);
      _showMessage(
        '${context.l10n.t('ops_qr_pin_generated_prefix')} '
        '${caseItem.pickupPin}. ${context.l10n.t('ops_qr_customer_ready_for_pickup_msg')}',
      );
    });
  }

  Future<void> _confirmPresentialDelivery(String reservationId) async {
    final pin = _pickupPinInputController.text.trim();
    if (pin.isEmpty) {
      _showMessage(context.l10n.t('ops_qr_enter_customer_pin_to_confirm'));
      return;
    }
    if (!_isSixDigitPin(pin)) {
      _showMessage(context.l10n.t('ops_qr_pin_must_have_six_digits'));
      return;
    }

    final caseItem = ref
        .read(qrHandoffControllerProvider)
        .casesByReservationId[reservationId];
    if (caseItem == null) {
      _showMessage(context.l10n.t('ops_qr_scan_and_validate_first'));
      return;
    }

    await _runAction(() async {
      final validated = await ref
          .read(qrHandoffControllerProvider.notifier)
          .validatePickupPin(reservationId: reservationId, typedPin: pin);
      if (!mounted) return;
      if (!validated) {
        _showMessage(context.l10n.t('ops_qr_pin_incorrect'));
        return;
      }
      ref.invalidate(opsReservationsProvider);
      _pickupPinInputController.clear();
      _showMessage(context.l10n.t('ops_qr_presential_delivery_completed'));
    });
  }

  Future<void> _requestOperatorApproval(
    Reservation reservation,
    QrHandoffCase caseItem,
  ) async {
    await _runAction(() async {
      if (!mounted) return;
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
                '${context.l10n.t('ops_qr_courier_request_approval_prefix')} '
                '${reservation.code}.',
            messageForCustomerInSpanish: translation.messageInSpanish,
            customerLanguage: caseItem.customerLanguage,
          );
      if (!mounted) return;
      ref.invalidate(opsReservationsProvider);
      _showMessage(context.l10n.t('ops_qr_request_sent_translated_notice'));
    });
  }

  Future<void> _approveNotification(OpsApprovalNotification item) async {
    await _runAction(() async {
      final caseItem = await ref
          .read(qrHandoffControllerProvider.notifier)
          .approveOperatorHandoff(notificationId: item.id);
      if (!mounted) return;
      _showMessage(
        '${context.l10n.t('ops_qr_approval_granted_prefix')} '
        '${item.reservationCode}. PIN ${caseItem.pickupPin}.',
      );
    });
  }

  Future<void> _confirmDeliveryWithPin(String reservationId) async {
    final pin = _deliveryPinInputController.text.trim();
    if (pin.isEmpty) {
      _showMessage(context.l10n.t('ops_qr_enter_final_pin'));
      return;
    }
    if (!_isSixDigitPin(pin)) {
      _showMessage(context.l10n.t('ops_qr_pin_must_have_six_digits'));
      return;
    }

    final caseItem = ref
        .read(qrHandoffControllerProvider)
        .casesByReservationId[reservationId];
    if (caseItem == null) {
      _showMessage(context.l10n.t('ops_qr_scan_and_validate_first'));
      return;
    }
    if (!caseItem.identityValidated) {
      _showMessage(context.l10n.t('ops_qr_missing_identity_validation'));
      return;
    }
    if (!caseItem.luggageMatched) {
      _showMessage(context.l10n.t('ops_qr_missing_luggage_match_validation'));
      return;
    }
    if (!caseItem.operatorApprovalGranted) {
      _showMessage(context.l10n.t('ops_qr_missing_operator_approval'));
      return;
    }

    await _runAction(() async {
      final ok = await ref
          .read(qrHandoffControllerProvider.notifier)
          .completeDeliveryWithPin(reservationId: reservationId, typedPin: pin);
      if (!mounted) return;
      if (!ok) {
        _showMessage(
          context.l10n.t('ops_qr_complete_delivery_validation_failed'),
        );
        return;
      }
      ref.invalidate(opsReservationsProvider);
      _deliveryPinInputController.clear();
      _showMessage(context.l10n.t('ops_qr_delivery_completed_ok'));
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
      if (!mounted) return;
      _showMessage(
        '${context.l10n.t('ops_qr_bag_id_generated_prefix')} '
        '${reservation.code} ($_bagUnits ${context.l10n.t('bultos').toLowerCase()}).',
      );
    });
  }

  String? _validateBagTagAction(Reservation reservation) {
    if (_bagUnits < 1 || _bagUnits > 20) {
      return context.l10n.t('ops_qr_select_units_between_1_20');
    }
    if (_isReservationClosed(reservation.status)) {
      return '${context.l10n.t('ops_qr_bag_tag_not_allowed_prefix')} '
          '${reservation.status.localizedLabel(context).toLowerCase()}.';
    }
    if (reservation.status == ReservationStatus.pendingPayment ||
        reservation.status == ReservationStatus.draft) {
      return context.l10n.t('ops_qr_reservation_not_enabled_for_bag');
    }
    return null;
  }

  String? _validateStoreInWarehouseAction({
    required Reservation reservation,
    required QrHandoffCase? caseItem,
  }) {
    if (caseItem == null) {
      return context.l10n.t('ops_qr_scan_reservation_qr_first');
    }
    if ((caseItem.bagTagId ?? '').trim().isEmpty) {
      return context.l10n.t('ops_qr_generate_bag_qr_before_store');
    }
    if (reservation.status == ReservationStatus.stored) {
      return context.l10n.t('ops_qr_already_stored');
    }
    if (reservation.status != ReservationStatus.confirmed &&
        reservation.status != ReservationStatus.checkinPending) {
      return '${context.l10n.t('ops_qr_store_not_allowed_prefix')} '
          '${reservation.status.localizedLabel(context)}.';
    }
    return null;
  }

  String? _validateReadyForPickupAction({
    required Reservation reservation,
    required QrHandoffCase? caseItem,
  }) {
    if (caseItem == null) {
      return context.l10n.t('ops_qr_scan_reservation_qr_first');
    }
    if ((caseItem.bagTagId ?? '').trim().isEmpty) {
      return context.l10n.t('ops_qr_generate_bag_qr_first');
    }
    if (reservation.status != ReservationStatus.stored &&
        reservation.status != ReservationStatus.readyForPickup) {
      return '${context.l10n.t('ops_qr_pickup_pin_not_allowed_prefix')} '
          '${reservation.status.localizedLabel(context)}.';
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
      if (!mounted) return;
      final readable = AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key));
      _showMessage(
        '${context.l10n.t('ops_qr_action_failed_prefix')}: $readable',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _storeUploadProgress = null;
        });
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

String _stageLabel(BuildContext context, QrHandoffStage? stage) {
  switch (stage) {
    case QrHandoffStage.qrValidated:
      return context.l10n.t('reservation_stage_qr_validated');
    case QrHandoffStage.bagTagged:
      return context.l10n.t('reservation_stage_bag_tagged');
    case QrHandoffStage.storedAtWarehouse:
      return context.l10n.t('reservation_stage_stored_at_warehouse');
    case QrHandoffStage.readyForPickup:
      return context.l10n.t('reservation_stage_ready_for_pickup');
    case QrHandoffStage.pickupPinValidated:
      return context.l10n.t('reservation_stage_pickup_pin_validated');
    case QrHandoffStage.deliveryIdentityValidated:
      return context.l10n.t('reservation_stage_delivery_identity_validated');
    case QrHandoffStage.deliveryLuggageValidated:
      return context.l10n.t('reservation_stage_delivery_luggage_validated');
    case QrHandoffStage.deliveryApprovalPending:
      return context.l10n.t('reservation_stage_delivery_approval_pending');
    case QrHandoffStage.deliveryApprovalGranted:
      return context.l10n.t('reservation_stage_delivery_approval_granted');
    case QrHandoffStage.deliveryCompleted:
      return context.l10n.t('reservation_stage_delivery_done');
    case QrHandoffStage.draft:
      return context.l10n.t('reservation_stage_draft');
    case null:
      return context.l10n.t('ops_qr_stage_not_available');
  }
}

String _approvalStatusLabel(BuildContext context, OpsApprovalStatus status) {
  switch (status) {
    case OpsApprovalStatus.pending:
      return context.l10n.t('ops_qr_approval_status_pending');
    case OpsApprovalStatus.approved:
      return context.l10n.t('ops_qr_approval_status_approved');
    case OpsApprovalStatus.rejected:
      return context.l10n.t('ops_qr_approval_status_rejected');
  }
}

class _ReservationContextCard extends StatelessWidget {
  const _ReservationContextCard({
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
            Text('${context.l10n.t('bultos')}: ${reservation.bagCount}'),
            Text(
              '${context.l10n.t('reservation_status')}: '
              '${reservation.status.localizedLabel(context)}',
            ),
            Text('${context.l10n.t('ops_qr_stage_prefix')}: $stageLabel'),
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
    final media = MediaQuery.of(context);
    final maxDialogWidth = media.size.width >= 980
        ? 720.0
        : media.size.width * 0.94;
    final maxDialogHeight = media.size.height * 0.78;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      title: Text(context.l10n.t('fotos_del_equipaje')),
      content: SizedBox(
        width: maxDialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDialogHeight),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${context.l10n.t('ops_qr_photo_dialog_intro_prefix')} '
                  '${widget.requiredPhotos} ${context.l10n.t('ops_qr_photo_units_suffix')}',
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
                              '${context.l10n.t('reservation_bag_unit_prefix')} ${index + 1}',
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
                                child: Text(
                                  context.l10n.t('ops_qr_photo_none_selected'),
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
                                        ? context.l10n.t('ops_qr_photo_select')
                                        : context.l10n.t('ops_qr_photo_change'),
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
                ? '${context.l10n.t('ops_qr_photo_confirm_prefix')} '
                      '${widget.requiredPhotos} ${context.l10n.t('photos')}'
                : context.l10n.t('ops_qr_photo_missing'),
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

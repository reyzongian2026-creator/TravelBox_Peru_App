import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/state/luggage_photo_memory_store.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../shared/utils/status_localizer.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../../shared/widgets/cancellation_preview_dialog.dart';
import '../../../shared/widgets/critical_operation_overlay.dart';
import '../../incidents/data/evidence_picker.dart';
import '../../payments/data/payment_repository.dart';
import '../data/reservation_repository_impl.dart';
import 'reservation_providers.dart';

final reservationPaymentStatusProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((
      ref,
      reservationId,
    ) async {
      ref.watch(reservationRealtimeEventCursorProvider);
      final dio = ref.read(dioProvider);
      try {
        final response = await dio.get<Map<String, dynamic>>(
          '/payments/status',
          queryParameters: {'reservationId': reservationId},
        );
        return response.data;
      } on DioException catch (error) {
        final statusCode = error.response?.statusCode ?? 0;
        if (statusCode == 404 || statusCode == 405) {
          return null;
        }
        rethrow;
      }
    });

class ReservationDetailPage extends ConsumerWidget {
  const ReservationDetailPage({
    super.key,
    required this.reservationId,
    this.fallbackRoute = '/reservations',
    this.lockBackNavigation = false,
  });

  final String reservationId;
  final String fallbackRoute;
  final bool lockBackNavigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationAsync = ref.watch(reservationByIdProvider(reservationId));

    return PopScope(
      canPop: !lockBackNavigation,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !lockBackNavigation || !context.mounted) {
          return;
        }
        context.go(fallbackRoute);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton(
            fallbackRoute: fallbackRoute,
            preferFallback: lockBackNavigation,
          ),
          title: Text(context.l10n.t('reservation_detail')),
        ),
        body: reservationAsync.when(
          data: (reservation) {
            if (reservation == null) {
              return EmptyStateView(
                message: context.l10n.t('reservation_not_found'),
              );
            }
            final session = ref.watch(sessionControllerProvider);
            final canOperate = session.canAccessAdmin;
            final operational = reservation.operationalDetail;
            final canUploadClientHandoffPhoto = _canUploadClientHandoffPhoto(
              reservation: reservation,
              session: session,
            );
            final bagTagId = operational?.bagTagId;
            final pickupPinText = _pickupPinText(context, operational);
            final qrSource = _reservationQrSource(reservation);
            final showTrackingAction = _shouldShowTrackingAction(reservation);
            final paymentStatus = ref.watch(
              reservationPaymentStatusProvider(reservationId),
            );
            final paymentSnapshot = paymentStatus.asData?.value;
            final requiresRefundForCancel = _requiresRefundForCancellation(
              paymentSnapshot,
            );
            final canCancelReservation = _canCancelReservation(
              reservation.status,
            );
            final responsive = context.responsive;
            final content = ListView(
              padding: responsive.pageInsets(
                top: responsive.verticalPadding,
                bottom: 24,
              ),
              children: [
                Card(
                  child: ListTile(
                    title: Text(reservation.warehouse.name),
                    subtitle: Text(
                      '${reservation.warehouse.address}\n${context.l10n.t('my_reservations_code_prefix')} ${reservation.code}',
                    ),
                    trailing: Chip(
                      label: Text(reservation.status.localizedLabel(context)),
                      side: BorderSide(color: reservation.status.color),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(context.l10n.t('pickup_delivery_credentials')),
                    subtitle: Text(
                      '${context.l10n.t('reservation_qr_id_prefix')}: ${reservation.code}\n'
                      '${context.l10n.t('reservation_bag_id')}: '
                      '${bagTagId ?? context.l10n.t('reservation_bag_id_pending')}\n'
                      '${context.l10n.t('reservation_pin_active_prefix')}: $pickupPinText',
                    ),
                  ),
                ),
                SizedBox(height: 12),
                if (qrSource != null)
                  _ReservationQrCard(
                    source: qrSource,
                    reservation: reservation,
                  ),
                if (qrSource != null) const SizedBox(height: 12),
                if (operational != null)
                  _OperationalDetailCard(
                    operational: operational,
                    reservationStatus: reservation.status,
                    isCourier: session.isCourier,
                  ),
                if (operational != null) const SizedBox(height: 12),
                if (operational != null &&
                    (operational.canViewLuggagePhotos ||
                        operational.luggagePhotosLocked))
                  _WarehouseLuggageSection(operational: operational),
                if (operational != null &&
                    (operational.canViewLuggagePhotos ||
                        operational.luggagePhotosLocked))
                  const SizedBox(height: 12),
                if (canUploadClientHandoffPhoto)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.add_a_photo_outlined),
                      title: Text(
                        context.l10n.t(
                          'reservation_initial_luggage_photo_title',
                        ),
                      ),
                      subtitle: Text(
                        context.l10n.t(
                          'reservation_initial_luggage_photo_subtitle',
                        ),
                      ),
                      trailing: FilledButton.tonalIcon(
                        onPressed: () => _uploadClientHandoffPhoto(
                          context: context,
                          ref: ref,
                          reservation: reservation,
                        ),
                        icon: const Icon(Icons.upload_outlined),
                        label: Text(context.l10n.t('upload')),
                      ),
                    ),
                  ),
                if (canUploadClientHandoffPhoto) const SizedBox(height: 12),
                paymentStatus.when(
                  data: (payment) {
                    if (payment == null) return const SizedBox.shrink();
                    final paymentState =
                        payment['paymentStatus']?.toString() ??
                        payment['status']?.toString() ??
                        '-';
                    final flow = payment['paymentFlow']?.toString() ?? '-';
                    final method = payment['paymentMethod']?.toString() ?? '-';
                    final paymentStateLabel = paymentStatusLabel(
                      context,
                      paymentState,
                    );
                    final localizedMethod = paymentMethodLabel(context, method);
                    final pendingOffline =
                        paymentState.toUpperCase() == 'PENDING' &&
                        flow.toUpperCase().contains('OFFLINE');
                    return Column(
                      children: [
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.payments_outlined),
                            title: Text(
                              '${context.l10n.t('reservation_payment')}: $paymentStateLabel',
                            ),
                            subtitle: Text(
                              '${context.l10n.t('reservation_flow_method')}: $flow\n'
                              '${context.l10n.t('reservation_method')}: $localizedMethod',
                            ),
                          ),
                        ),
                        if (pendingOffline)
                          Card(
                            child: ListTile(
                              leading: Icon(Icons.info_outline),
                              title: Text(
                                context.l10n.t('pago_pendiente_de_aprobacion'),
                              ),
                              subtitle: Text(
                                context.l10n.t(
                                  'reservation_pending_payment_qr_warning',
                                ),
                              ),
                            ),
                          ),
                        if (reservation.latePickupSurcharge > 0)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                Icons.access_time,
                                color: Colors.orange,
                              ),
                              title: Text(
                                context.l10n.t('reservation_late_pickup_surcharge'),
                              ),
                              subtitle: Text(
                                context.l10n.t(
                                  'reservation_late_pickup_surcharge_description',
                                ),
                              ),
                              trailing: Text(
                                'S/${reservation.latePickupSurcharge.toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (error, _) => const SizedBox.shrink(),
                ),
                if (paymentStatus.hasValue) SizedBox(height: 12),
                if (!canCancelReservation)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(context.l10n.t('reservation_cancel')),
                      subtitle: Text(
                        _cancelBlockedReason(context, reservation.status),
                      ),
                    ),
                  ),
                if (!canCancelReservation) const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(reservationByIdProvider(reservationId));
                        ref.invalidate(
                          reservationPaymentStatusProvider(reservationId),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.t('update')),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  context.l10n.t('timeline'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 8),
                ...reservation.timeline.map(
                  (event) => _TimelineTile(event: event),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canOperate)
                      if (reservation.status == ReservationStatus.confirmed ||
                          reservation.status == ReservationStatus.checkinPending)
                        FilledButton.tonalIcon(
                          onPressed: () => context.push(
                            '/ops/qr-handoff?scan=${Uri.encodeComponent(reservation.code)}',
                          ),
                          icon: Icon(Icons.inventory_2_outlined),
                          label: Text(context.l10n.t('registrar_ingreso_qr')),
                        ),
                    if (reservation.status == ReservationStatus.stored ||
                        reservation.status == ReservationStatus.readyForPickup)
                      if (reservation.dropoffRequested)
                        FilledButton.tonal(
                          onPressed: () =>
                              context.push('/delivery/$reservationId'),
                          child: Text(context.l10n.t('request_delivery')),
                        ),
                    if (reservation.status == ReservationStatus.confirmed)
                      if (reservation.pickupRequested)
                        FilledButton.tonal(
                          onPressed: () => context.push(
                            '/delivery/$reservationId?type=PICKUP',
                          ),
                          child: Text(context.l10n.t('request_pickup')),
                        ),
                    if (canCancelReservation)
                      FilledButton.tonalIcon(
                        onPressed: () => _cancelOrRefundReservation(
                          context: context,
                          ref: ref,
                          reservation: reservation,
                          requiresRefund: requiresRefundForCancel,
                        ),
                        icon: Icon(Icons.cancel_outlined),
                        label: Text(
                          requiresRefundForCancel
                              ? context.l10n.t('reservation_refund_and_cancel')
                              : context.l10n.t('reservation_cancel'),
                        ),
                      ),
                    if (showTrackingAction)
                      FilledButton.tonal(
                        onPressed: () =>
                            context.push('/tracking/$reservationId'),
                        child: Text(_trackingActionLabel(context, reservation)),
                      ),
                    OutlinedButton(
                      onPressed: () => context.push(
                        '/incidents?reservationId=$reservationId',
                      ),
                      child: Text(
                        canOperate
                            ? context.l10n.t('reservation_report_incident')
                            : context.l10n.t('reservation_contact_support'),
                      ),
                    ),
                  ],
                ),
              ],
            );

            final isWideWeb =
                kIsWeb && MediaQuery.of(context).size.width >= 1000;
            if (!isWideWeb) {
              return content;
            }

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 980),
                child: content,
              ),
            );
          },
          loading: () => const LoadingStateView(),
          error: (error, _) => ErrorStateView(
            message: '${context.l10n.t('reservation_load_failed')}: $error',
            onRetry: () =>
                ref.invalidate(reservationByIdProvider(reservationId)),
          ),
        ),
      ),
    );
  }

  bool _canUploadClientHandoffPhoto({
    required Reservation reservation,
    required SessionState session,
  }) {
    final userId = session.user?.id;
    if (userId == null || userId != reservation.userId) {
      return false;
    }
    if (!reservation.pickupRequested) {
      return false;
    }
    return reservation.status == ReservationStatus.confirmed ||
        reservation.status == ReservationStatus.checkinPending;
  }

  Future<void> _uploadClientHandoffPhoto({
    required BuildContext context,
    required WidgetRef ref,
    required Reservation reservation,
  }) async {
    final selected = await pickEvidenceImage();
    if (selected == null || !context.mounted) {
      return;
    }

    try {
      final session = ref.read(sessionControllerProvider);
      ref
          .read(luggagePhotoMemoryStoreProvider.notifier)
          .addClientHandoffPhoto(
            reservation: reservation,
            bytes: selected.bytes,
            mimeType: selected.mimeType,
            filename: selected.filename,
            capturedByUserId: session.user?.id,
            capturedByName: session.user?.name,
          );
      ref.invalidate(reservationByIdProvider(reservationId));
      ref.invalidate(myReservationsProvider);
      ref.invalidate(adminReservationsProvider);
      ref.invalidate(adminReservationListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('reservation_photo_uploaded'))),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.l10n.t('reservation_photo_upload_failed')}: $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _cancelOrRefundReservation({
    required BuildContext context,
    required WidgetRef ref,
    required Reservation reservation,
    required bool requiresRefund,
  }) async {
    if (requiresRefund) {
      // Step 1: Get cancellation preview from backend
      final paymentRepo = ref.read(paymentRepositoryProvider);
      Map<String, dynamic> preview;
      try {
        preview = await paymentRepo.getCancellationPreview(
          reservationId: int.parse(reservationId),
        );
      } catch (error) {
        if (!context.mounted) return;
        final readable = AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener vista previa: $readable')),
        );
        return;
      }

      if (!context.mounted) return;

      // Step 2: Show cancellation preview dialog
      final confirmed = await CancellationPreviewDialog.show(
        context: context,
        preview: preview,
      );

      if (confirmed != true || !context.mounted) return;

      // Step 3: Execute cancellation with blocking overlay
      OverlayEntry? overlay;
      try {
        overlay = CriticalOperationOverlay.show(
          context,
          message: 'Procesando cancelación y reembolso...',
          submessage: 'Esto puede tardar unos segundos',
        );

        await paymentRepo.confirmCancellation(
          reservationId: int.parse(reservationId),
          reason: context.l10n.t('reservation_timeline_cancel_requested_refund_app'),
        );
      } catch (error) {
        if (overlay != null) CriticalOperationOverlay.dismiss(overlay);
        if (!context.mounted) return;
        final readable = AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.l10n.t('reservation_cancel_failed')}: $readable',
            ),
          ),
        );
        return;
      }
      if (overlay != null) CriticalOperationOverlay.dismiss(overlay);
    } else {
      // No refund needed — simple cancel via existing repository
      final reason = context.l10n.t('reservation_timeline_cancel_requested_app');
      try {
        await ref
            .read(reservationRepositoryProvider)
            .refundAndCancelReservation(
              reservationId: reservationId,
              reason: reason,
            );
      } catch (error) {
        if (!context.mounted) return;
        final readable = AppErrorFormatter.readable(error, (String key, {Map<String, dynamic>? params}) => context.l10n.t(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.l10n.t('reservation_cancel_failed')}: $readable',
            ),
          ),
        );
        return;
      }
    }

    ref.invalidate(reservationByIdProvider(reservationId));
    ref.invalidate(reservationPaymentStatusProvider(reservationId));
    ref.invalidate(myReservationsProvider);
    ref.invalidate(adminReservationsProvider);
    ref.invalidate(adminReservationListProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          requiresRefund
              ? context.l10n.t('reservation_refund_cancel_success')
              : context.l10n.t('reservation_cancel_success'),
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final ReservationTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: event.status.color),
        title: Text(event.status.localizedLabel(context)),
        subtitle: Text(
          '${timelineMessageLabel(context, event.message)}\n'
          '${PeruTime.formatDateTime(event.timestamp)}',
        ),
      ),
    );
  }
}

String _pickupPinText(
  BuildContext context,
  ReservationOperationalDetail? operational,
) {
  if (operational == null) {
    return context.l10n.t('reservation_pickup_pin_pending_or_validated');
  }
  final visiblePin = operational.pickupPin?.trim();
  if (visiblePin != null && visiblePin.isNotEmpty) {
    return visiblePin;
  }
  if (operational.pickupPinGenerated) {
    return operational.pickupPinVisible
        ? context.l10n.t('reservation_pickup_pin_generated_pending_secure')
        : context.l10n.t('reservation_pickup_pin_role_protected');
  }
  return context.l10n.t('reservation_pickup_pin_pending_or_validated');
}

class _OperationalDetailCard extends StatelessWidget {
  const _OperationalDetailCard({
    required this.operational,
    required this.reservationStatus,
    required this.isCourier,
  });

  final ReservationOperationalDetail operational;
  final ReservationStatus reservationStatus;
  final bool isCourier;

  @override
  Widget build(BuildContext context) {
    final stage = _operationalStageLabel(
      context,
      operational,
      reservationStatus,
    );
    final checkinAt = operational.checkinAt;
    final checkinLabel = checkinAt == null
        ? context.l10n.t('pending')
        : PeruTime.formatDateTime(checkinAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.t('reservation_operational_status'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    '${context.l10n.t('reservation_qr_pin_stage')}: $stage',
                  ),
                ),
                Chip(
                  label: Text(
                    '${context.l10n.t('reservation_bag_units')}: '
                    '${operational.bagUnits}',
                  ),
                ),
                Chip(
                  label: Text(
                    '${context.l10n.t('reservation_luggage_photos')}: '
                    '${operational.storedLuggagePhotos}/'
                    '${operational.expectedLuggagePhotos}',
                  ),
                ),
                if (operational.luggagePhotosLocked)
                  Chip(
                    label: Text(context.l10n.t('registro_de_almacen_cerrado')),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${context.l10n.t('reservation_warehouse_checkin')}: '
              '$checkinLabel',
            ),
            if (operational.bagTagId?.trim().isNotEmpty == true)
              Text(
                '${context.l10n.t('reservation_bag_id')}: '
                '${operational.bagTagId}',
              ),
            if (!isCourier && operational.pickupPinGenerated)
              Text(
                operational.pickupPinVisible &&
                        operational.pickupPin?.trim().isNotEmpty == true
                    ? context.l10n.t('reservation_pickup_pin_available')
                    : context.l10n.t('reservation_pickup_pin_restricted'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReservationQrCard extends StatelessWidget {
  const _ReservationQrCard({required this.source, required this.reservation});

  final String source;
  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final paymentPending =
        reservation.status == ReservationStatus.pendingPayment;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.t('reservation_qr_title'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              paymentPending
                  ? context.l10n.t('reservation_qr_pending_payment_subtitle')
                  : context.l10n.t('reservation_qr_ready_subtitle'),
            ),
            const SizedBox(height: 12),
            Center(
              child: AppSmartImage(
                source: source,
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                borderRadius: BorderRadius.circular(18),
                fallback: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2F5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.qr_code_2, size: 64),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseLuggageSection extends StatelessWidget {
  const _WarehouseLuggageSection({required this.operational});

  final ReservationOperationalDetail operational;

  @override
  Widget build(BuildContext context) {
    final photos = operational.luggagePhotos;
    final responsive = context.responsive;
    final photoCardWidth = responsive.isMobile
        ? (responsive.width - (responsive.horizontalPadding * 2) - 34)
              .clamp(180.0, 280.0)
              .toDouble()
        : 220.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.t('reservation_warehouse_record_title'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(context.l10n.t('reservation_warehouse_record_subtitle')),
            const SizedBox(height: 12),
            if (!operational.canViewLuggagePhotos)
              Text(context.l10n.t('reservation_warehouse_photos_restricted'))
            else if (photos.isEmpty)
              Text(
                operational.luggagePhotosLocked
                    ? context.l10n.t(
                        'reservation_warehouse_photos_not_available',
                      )
                    : context.l10n.t('reservation_warehouse_photos_pending'),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: photos
                    .map(
                      (photo) => _LuggagePhotoCard(
                        photo: photo,
                        width: photoCardWidth,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _LuggagePhotoCard extends StatelessWidget {
  const _LuggagePhotoCard({required this.photo, required this.width});

  final ReservationLuggagePhoto photo;
  final double width;

  @override
  Widget build(BuildContext context) {
    final imageHeight = (width * 0.66).clamp(136.0, 170.0).toDouble();
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AppSmartImage(
              source: photo.imageUrl,
              height: imageHeight,
              width: width,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _photoTitle(context, photo),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            _photoSourceLabel(context, photo.type),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (photo.capturedByName?.trim().isNotEmpty == true)
            Text(
              '${context.l10n.t('reservation_recorded_by_prefix')} ${photo.capturedByName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

String _photoTitle(BuildContext context, ReservationLuggagePhoto photo) {
  final bagUnitIndex = photo.bagUnitIndex;
  if (bagUnitIndex != null && bagUnitIndex > 0) {
    return '${context.l10n.t('reservation_bag_unit_prefix')} $bagUnitIndex';
  }
  final normalizedType = photo.type.trim().toUpperCase();
  if (normalizedType == 'CLIENT_HANDOFF_PHOTO') {
    return context.l10n.t('reservation_photo_initial_client');
  }
  return context.l10n.t('reservation_photo_luggage_generic');
}

String _photoSourceLabel(BuildContext context, String rawType) {
  final normalized = rawType.trim().toUpperCase();
  if (normalized == 'CLIENT_HANDOFF_PHOTO') {
    return context.l10n.t('reservation_photo_source_client');
  }
  if (normalized == 'CHECKIN_BAG_PHOTO') {
    return context.l10n.t('reservation_photo_source_warehouse');
  }
  return context.l10n.t('reservation_photo_source_operations');
}

String? _reservationQrSource(Reservation reservation) {
  final dataUrl = reservation.qrDataUrl?.trim();
  if (dataUrl != null && dataUrl.isNotEmpty) {
    return dataUrl;
  }
  final imageUrl = reservation.qrImageUrl?.trim();
  if (imageUrl != null && imageUrl.isNotEmpty) {
    return imageUrl;
  }
  return null;
}

bool _shouldShowTrackingAction(Reservation reservation) {
  if (reservation.pickupRequested || reservation.dropoffRequested) {
    return true;
  }
  switch (reservation.status) {
    case ReservationStatus.checkinPending:
    case ReservationStatus.stored:
    case ReservationStatus.outForDelivery:
    case ReservationStatus.readyForPickup:
    case ReservationStatus.completed:
      return true;
    case ReservationStatus.draft:
    case ReservationStatus.pendingPayment:
    case ReservationStatus.confirmed:
    case ReservationStatus.cancelled:
    case ReservationStatus.incident:
    case ReservationStatus.expired:
      return false;
  }
}

String _trackingActionLabel(BuildContext context, Reservation reservation) {
  if (reservation.status == ReservationStatus.checkinPending) {
    return context.l10n.t('reservation_tracking_pickup');
  }
  if (reservation.status == ReservationStatus.outForDelivery ||
      reservation.dropoffRequested) {
    return context.l10n.t('reservation_tracking_delivery');
  }
  return context.l10n.t('reservation_tracking_logistics');
}

bool _canCancelReservation(ReservationStatus status) {
  return status == ReservationStatus.draft ||
      status == ReservationStatus.pendingPayment ||
      status == ReservationStatus.confirmed ||
      status == ReservationStatus.checkinPending ||
      status == ReservationStatus.incident;
}

bool _requiresRefundForCancellation(Map<String, dynamic>? payment) {
  if (payment == null) {
    return false;
  }
  final status = payment['paymentStatus']?.toString().trim().toUpperCase();
  final method = payment['paymentMethod']?.toString().trim().toUpperCase();
  if (status != 'CONFIRMED') {
    return false;
  }
  return method == 'CARD' ||
      method == 'YAPE' ||
      method == 'PLIN' ||
      method == 'WALLET';
}

String _cancelBlockedReason(BuildContext context, ReservationStatus status) {
  switch (status) {
    case ReservationStatus.completed:
      return context.l10n.t('reservation_cancel_blocked_completed');
    case ReservationStatus.cancelled:
      return context.l10n.t('reservation_cancel_blocked_cancelled');
    case ReservationStatus.expired:
      return context.l10n.t('reservation_cancel_blocked_expired');
    case ReservationStatus.stored:
    case ReservationStatus.readyForPickup:
    case ReservationStatus.outForDelivery:
      return context.l10n.t('reservation_cancel_blocked_in_operation');
    case ReservationStatus.draft:
    case ReservationStatus.pendingPayment:
    case ReservationStatus.confirmed:
    case ReservationStatus.checkinPending:
    case ReservationStatus.incident:
      return context.l10n.t('reservation_cancel_blocked_status');
  }
}

String _operationalStageLabel(
  BuildContext context,
  ReservationOperationalDetail operational,
  ReservationStatus reservationStatus,
) {
  final rawStage = operational.stage?.trim().toUpperCase();
  if (rawStage != null && rawStage.isNotEmpty) {
    return operationalStageLabel(context, rawStage);
  }

  if (operational.pickupPinGenerated) {
    return context.l10n.t('reservation_stage_pin_generated');
  }
  if (operational.checkinAt != null) {
    return context.l10n.t('reservation_stage_stored_at_warehouse');
  }
  return reservationStatus.localizedLabel(context);
}

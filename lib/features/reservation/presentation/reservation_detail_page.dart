import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../incidents/data/evidence_picker.dart';
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
  ReservationDetailPage({
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
                      '${reservation.warehouse.address}\nCodigo ${reservation.code}',
                    ),
                    trailing: Chip(
                      label: Text(reservation.status.label),
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
                      'QR/ID reserva: ${reservation.code}\n'
                      'ID maleta: ${bagTagId ?? 'Se asigna al ingresar equipaje'}\n'
                      'PIN vigente: $pickupPinText',
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
                    final paymentStateLabel = _paymentStatusLabel(paymentState);
                    final paymentMethodLabel = _paymentMethodLabel(method);
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
                              'Flujo: $flow\nMétodo: $paymentMethodLabel',
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
                                'El QR de check-in aún no debe usarse. Primero se debe validar el cobro en caja desde el panel del operador.',
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
                        child: Text(_trackingActionLabel(reservation)),
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

    final progress = ValueNotifier<double>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.t('reservation_uploading_evidence')),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value <= 0 ? null : value),
                const SizedBox(height: 10),
                Text(
                  value <= 0
                      ? context.l10n.t('reservation_preparing_file')
                      : '${context.l10n.t('reservation_progress')} '
                            '${(value * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>(
            '/inventory/evidences/upload',
            data: FormData.fromMap({
              'reservationId': reservation.id,
              'type': 'CLIENT_HANDOFF_PHOTO',
              'observation': 'Foto inicial tomada por cliente.',
              'file': MultipartFile.fromBytes(
                selected.bytes,
                filename: selected.filename,
                contentType: MediaType.parse(selected.mimeType),
              ),
            }),
            onSendProgress: (sent, total) {
              if (total <= 0) {
                return;
              }
              progress.value = (sent / total).clamp(0, 1);
            },
          );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ref.invalidate(reservationByIdProvider(reservationId));
      ref.invalidate(myReservationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('reservation_photo_uploaded'))),
        );
      }
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.l10n.t('reservation_photo_upload_failed')}: $error',
            ),
          ),
        );
      }
    } finally {
      progress.dispose();
    }
  }

  Future<void> _cancelOrRefundReservation({
    required BuildContext context,
    required WidgetRef ref,
    required Reservation reservation,
    required bool requiresRefund,
  }) async {
    final reason = requiresRefund
        ? 'Cancelacion con reembolso solicitada desde la app.'
        : 'Cancelacion solicitada desde la app.';
    try {
      await ref
          .read(reservationRepositoryProvider)
          .refundAndCancelReservation(
            reservationId: reservationId,
            reason: reason,
          );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10n.t('reservation_cancel_failed')}: $error',
          ),
        ),
      );
      return;
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
        title: Text(event.status.label),
        subtitle: Text(
          '${event.message}\n${PeruTime.formatDateTime(event.timestamp)}',
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
    final stage = _operationalStageLabel(operational, reservationStatus);
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
              'QR de reserva',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              paymentPending
                  ? 'El QR ya está generado, pero solo debe usarse cuando el pago quede confirmado.'
                  : 'Presenta este QR cuando el operador valide el ingreso o la entrega.',
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
              'Registro en almacén',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Incluye foto inicial del cliente y fotos del ingreso al almacén para validar estado de entrega y recepción.',
            ),
            const SizedBox(height: 12),
            if (!operational.canViewLuggagePhotos)
              const Text(
                'Tu perfil no puede ver las fotos, pero el registro ya quedó cerrado en almacén.',
              )
            else if (photos.isEmpty)
              Text(
                operational.luggagePhotosLocked
                    ? 'No hay fotos visibles cargadas para esta reserva.'
                    : 'Aún no se registran las fotos del equipaje.',
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
            _photoTitle(photo),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            _photoSourceLabel(photo.type),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (photo.capturedByName?.trim().isNotEmpty == true)
            Text(
              'Registrado por ${photo.capturedByName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

String _photoTitle(ReservationLuggagePhoto photo) {
  final bagUnitIndex = photo.bagUnitIndex;
  if (bagUnitIndex != null && bagUnitIndex > 0) {
    return 'Bulto $bagUnitIndex';
  }
  final normalizedType = photo.type.trim().toUpperCase();
  if (normalizedType == 'CLIENT_HANDOFF_PHOTO') {
    return 'Foto inicial del cliente';
  }
  return 'Foto de equipaje';
}

String _photoSourceLabel(String rawType) {
  final normalized = rawType.trim().toUpperCase();
  if (normalized == 'CLIENT_HANDOFF_PHOTO') {
    return 'Origen: cliente';
  }
  if (normalized == 'CHECKIN_BAG_PHOTO') {
    return 'Origen: ingreso a almacén';
  }
  return 'Origen: evidencia operativa';
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

String _trackingActionLabel(Reservation reservation) {
  if (reservation.status == ReservationStatus.checkinPending) {
    return 'Ver tracking de recojo';
  }
  if (reservation.status == ReservationStatus.outForDelivery ||
      reservation.dropoffRequested) {
    return 'Ver tracking de entrega';
  }
  return 'Ver tracking logístico';
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

String _paymentStatusLabel(String rawStatus) {
  switch (rawStatus.trim().toUpperCase()) {
    case 'CONFIRMED':
      return 'Confirmado';
    case 'PENDING':
      return 'Pendiente';
    case 'REJECTED':
      return 'Rechazado';
    case 'CANCELLED':
      return 'Cancelado';
    case 'REFUNDED':
      return 'Reembolsado';
    case 'FAILED':
      return 'Fallido';
    default:
      return rawStatus;
  }
}

String _paymentMethodLabel(String rawMethod) {
  switch (rawMethod.trim().toUpperCase()) {
    case 'CARD':
      return 'tarjeta';
    case 'CASH':
      return 'efectivo';
    case 'COUNTER':
      return 'en caja';
    case 'YAPE':
      return 'yape';
    case 'PLIN':
      return 'plin';
    case 'WALLET':
      return 'wallet/plin';
    default:
      return rawMethod;
  }
}

String _operationalStageLabel(
  ReservationOperationalDetail operational,
  ReservationStatus reservationStatus,
) {
  final rawStage = operational.stage?.trim().toUpperCase();
  switch (rawStage) {
    case 'QR_VALIDATED':
      return 'QR validado';
    case 'BAG_TAGGED':
      return 'ID de equipaje generado';
    case 'STORED_AT_WAREHOUSE':
      return 'Equipaje en almacén';
    case 'READY_FOR_PICKUP':
      return 'PIN listo para recojo';
    case 'PICKUP_PIN_VALIDATED':
      return 'Recojo validado con PIN';
    case 'DELIVERY_IDENTITY_VALIDATED':
      return 'Identidad validada';
    case 'DELIVERY_LUGGAGE_VALIDATED':
      return 'Equipaje validado';
    case 'DELIVERY_APPROVAL_PENDING':
      return 'Aprobación de entrega pendiente';
    case 'DELIVERY_APPROVAL_GRANTED':
      return 'Entrega aprobada';
    case 'DELIVERY_COMPLETED':
      return 'Entrega completada';
    case 'DRAFT':
      return 'Caso QR/PIN creado';
  }

  if (operational.pickupPinGenerated) {
    return 'PIN generado';
  }
  if (operational.checkinAt != null) {
    return 'Equipaje en almacén';
  }
  switch (reservationStatus) {
    case ReservationStatus.pendingPayment:
      return 'Pendiente de pago';
    case ReservationStatus.confirmed:
      return 'QR listo para ingreso';
    case ReservationStatus.checkinPending:
      return 'Recojo solicitado';
    case ReservationStatus.stored:
      return 'Equipaje en almacén';
    case ReservationStatus.outForDelivery:
      return 'Entrega en ruta';
    case ReservationStatus.readyForPickup:
      return 'Listo para recojo';
    case ReservationStatus.completed:
      return 'Proceso completado';
    case ReservationStatus.cancelled:
      return 'Reserva cancelada';
    case ReservationStatus.incident:
      return 'En revisión por incidencia';
    case ReservationStatus.expired:
      return 'Reserva expirada';
    case ReservationStatus.draft:
      return 'Reserva en borrador';
  }
}

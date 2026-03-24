import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../notifications/domain/app_notification.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/state/notification_center_controller.dart';
import '../../../shared/utils/status_localizer.dart';
import '../../../shared/widgets/app_smart_image.dart';
import 'reservation_providers.dart';

final reservationSuccessPaymentStatusProvider =
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

class ReservationSuccessPage extends ConsumerWidget {
  const ReservationSuccessPage({super.key, required this.reservationId});

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservation = ref.watch(reservationByIdProvider(reservationId));
    final paymentStatus = ref.watch(
      reservationSuccessPaymentStatusProvider(reservationId),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/reservations'),
        title: Text(context.l10n.t('reservation_status')),
      ),
      body: reservation.when(
        data: (item) {
          if (item == null) {
            return EmptyStateView(
              message: context.l10n.t('reservation_not_found'),
            );
          }
          final notifications = ref.watch(notificationCenterControllerProvider);
          final pickupPin = _latestNotificationPayloadValue(
            notifications.items,
            item.id,
            'pickupPin',
          );
          final bagTagId = _latestNotificationPayloadValue(
            notifications.items,
            item.id,
            'bagTagId',
          );
          final pendingOffline =
              item.status == ReservationStatus.pendingPayment;
          final canTrackDelivery =
              item.status == ReservationStatus.outForDelivery ||
              item.status == ReservationStatus.checkinPending;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '${context.l10n.t('my_reservations_code_prefix')} ${item.code}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (pendingOffline)
                        _PendingQrPlaceholder(code: item.code)
                      else
                        _ReservationQrView(
                          reservation: item,
                          fallbackUrl:
                              '${AppEnv.apiBaseUrl}/reservations/${item.id}/qr',
                        ),
                      const SizedBox(height: 8),
                      Text(
                        pendingOffline
                            ? context.l10n.t(
                                'reservation_success_qr_pending_message',
                              )
                            : context.l10n.t(
                                'reservation_success_qr_checkin_only_message',
                              ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.qr_code_2_outlined),
                  title: Text(context.l10n.t('identification_data')),
                  subtitle: Text(
                    '${context.l10n.t('reservation_qr_id_prefix')}: ${item.code}\n'
                    '${context.l10n.t('reservation_bag_id')}: '
                    '${bagTagId ?? context.l10n.t('reservation_bag_id_pending')}\n'
                    '${context.l10n.t('reservation_pin_active_prefix')}: '
                    '${pickupPin ?? context.l10n.t('reservation_pickup_pin_pending_or_validated')}',
                  ),
                ),
              ),
              SizedBox(height: 12),
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
                  final methodLabel = paymentMethodLabel(context, method);
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: Text(
                        '${context.l10n.t('reservation_payment')}: $paymentStateLabel',
                      ),
                      subtitle: Text(
                        '${context.l10n.t('reservation_flow_method')}: $flow\n'
                        '${context.l10n.t('reservation_method')}: $methodLabel',
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              if (pendingOffline) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text(
                      context.l10n.t('como_dejar_de_estar_pendiente'),
                    ),
                    subtitle: Text(
                      context.l10n.t('reservation_success_pending_steps'),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: Text(item.warehouse.name),
                  subtitle: Text(
                    '${item.warehouse.address}\n${context.l10n.t('reservation_status')}: ${item.status.localizedLabel(context)}',
                  ),
                  trailing: Text('S/${item.totalPrice.toStringAsFixed(2)}'),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canTrackDelivery)
                    FilledButton(
                      onPressed: () => context.push('/tracking/${item.id}'),
                      child: Text(
                        item.status == ReservationStatus.checkinPending
                            ? context.l10n.t('reservation_tracking_pickup')
                            : context.l10n.t('tracking'),
                      ),
                    ),
                  if (!canTrackDelivery &&
                      (item.status == ReservationStatus.confirmed ||
                          item.status == ReservationStatus.checkinPending))
                    FilledButton.tonal(
                      onPressed: () =>
                          context.push('/delivery/${item.id}?type=PICKUP'),
                      child: Text(context.l10n.t('request_pickup')),
                    ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(reservationByIdProvider(reservationId));
                      ref.invalidate(
                        reservationSuccessPaymentStatusProvider(reservationId),
                      );
                    },
                    icon: Icon(Icons.refresh),
                    label: Text(context.l10n.t('update_status')),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/reservations'),
                    child: Text(context.l10n.t('go_my_reservations')),
                  ),
                  if (!canTrackDelivery)
                    OutlinedButton(
                      onPressed: () => context.push('/reservation/${item.id}'),
                      child: Text(context.l10n.t('view_detail')),
                    ),
                ],
              ),
            ],
          );
        },
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: '${context.l10n.t('reservation_load_failed')}: $error',
          onRetry: () => ref.invalidate(reservationByIdProvider(reservationId)),
        ),
      ),
    );
  }
}

class _PendingQrPlaceholder extends StatelessWidget {
  const _PendingQrPlaceholder({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6D6D6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_top_rounded, size: 44),
          const SizedBox(height: 10),
          Text(
            context.l10n.t('reservation_success_qr_pending_label'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(code, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _ReservationQrView extends StatelessWidget {
  const _ReservationQrView({
    required this.reservation,
    required this.fallbackUrl,
  });

  final Reservation reservation;
  final String fallbackUrl;

  @override
  Widget build(BuildContext context) {
    final qrUrl =
        reservation.qrDataUrl ?? reservation.qrImageUrl ?? fallbackUrl;
    return AppSmartImage(
      source: qrUrl,
      width: 220,
      height: 220,
      fit: BoxFit.contain,
      fallback: QrImageView(
        data: reservation.code,
        size: 220,
        backgroundColor: Colors.white,
      ),
    );
  }
}

String? _latestNotificationPayloadValue(
  List<AppNotification> notifications,
  String reservationId,
  String key,
) {
  for (final item in notifications) {
    final payloadReservationId = item.payload['reservationId']?.toString();
    if (payloadReservationId != reservationId) {
      continue;
    }
    final value = item.payload[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

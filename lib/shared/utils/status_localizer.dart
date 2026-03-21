import 'package:flutter/widgets.dart';

import '../../core/l10n/app_localizations.dart';
import '../models/reservation.dart';

extension ReservationStatusLocalizationX on ReservationStatus {
  String localizedLabel(BuildContext context) {
    return context.l10n.t(_reservationStatusKey(code));
  }
}

String reservationStatusCodeLabel(BuildContext context, String rawStatus) {
  final normalized = rawStatus.trim().toUpperCase();
  return context.l10n.t(_reservationStatusKey(normalized));
}

String paymentStatusLabel(BuildContext context, String rawStatus) {
  final normalized = rawStatus.trim().toUpperCase();
  return switch (normalized) {
    'CONFIRMED' => context.l10n.t('payment_status_confirmed'),
    'PENDING' => context.l10n.t('payment_status_pending'),
    'REJECTED' => context.l10n.t('payment_status_rejected'),
    'CANCELLED' => context.l10n.t('payment_status_cancelled'),
    'REFUNDED' => context.l10n.t('payment_status_refunded'),
    'FAILED' => context.l10n.t('payment_status_failed'),
    _ => rawStatus,
  };
}

String paymentMethodLabel(BuildContext context, String rawMethod) {
  final normalized = rawMethod.trim().toUpperCase();
  return switch (normalized) {
    'CARD' => context.l10n.t('payment_method_card'),
    'CASH' => context.l10n.t('payment_method_cash'),
    'COUNTER' => context.l10n.t('payment_method_counter'),
    'YAPE' => context.l10n.t('payment_method_yape'),
    'PLIN' => context.l10n.t('payment_method_plin'),
    'WALLET' => context.l10n.t('payment_method_wallet'),
    _ => rawMethod,
  };
}

String notificationStatusLabel(BuildContext context, String rawStatus) {
  final normalized = rawStatus.trim().toUpperCase();
  return switch (normalized) {
    'SENT' => context.l10n.t('notification_status_sent'),
    'SEEN' => context.l10n.t('notification_status_seen'),
    'READ' => context.l10n.t('notification_status_seen'),
    'FAILED' => context.l10n.t('notification_status_failed'),
    'PENDING' => context.l10n.t('notification_status_pending'),
    _ => rawStatus,
  };
}

String deliveryStatusLabel(BuildContext context, String rawStatus) {
  final normalized = rawStatus.trim().toUpperCase();
  return switch (normalized) {
    'REQUESTED' => context.l10n.t('delivery_status_requested'),
    'ASSIGNED' => context.l10n.t('delivery_status_assigned'),
    'IN_TRANSIT' => context.l10n.t('delivery_status_in_transit'),
    'DELIVERED' => context.l10n.t('delivery_status_delivered'),
    'CANCELLED' => context.l10n.t('delivery_status_cancelled'),
    _ => rawStatus,
  };
}

String operationalStageLabel(BuildContext context, String rawStage) {
  final normalized = rawStage.trim().toUpperCase();
  return switch (normalized) {
    'QR_VALIDATED' => context.l10n.t('reservation_stage_qr_validated'),
    'BAG_TAGGED' => context.l10n.t('reservation_stage_bag_tagged'),
    'STORED_AT_WAREHOUSE' => context.l10n.t(
      'reservation_stage_stored_at_warehouse',
    ),
    'READY_FOR_PICKUP' => context.l10n.t('reservation_stage_ready_for_pickup'),
    'PICKUP_PIN_VALIDATED' => context.l10n.t(
      'reservation_stage_pickup_pin_validated',
    ),
    'DELIVERY_IDENTITY_VALIDATED' => context.l10n.t(
      'reservation_stage_delivery_identity_validated',
    ),
    'DELIVERY_LUGGAGE_VALIDATED' => context.l10n.t(
      'reservation_stage_delivery_luggage_validated',
    ),
    'DELIVERY_APPROVAL_PENDING' => context.l10n.t(
      'reservation_stage_delivery_approval_pending',
    ),
    'DELIVERY_APPROVAL_GRANTED' => context.l10n.t(
      'reservation_stage_delivery_approval_granted',
    ),
    'DELIVERY_COMPLETED' => context.l10n.t('reservation_stage_delivery_done'),
    'DRAFT' => context.l10n.t('reservation_stage_draft'),
    _ => rawStage,
  };
}

String _reservationStatusKey(String statusCode) {
  final normalized = statusCode.trim().toUpperCase();
  return switch (normalized) {
    'DRAFT' => 'reservation_status_draft',
    'PENDING_PAYMENT' => 'reservation_status_pending_payment',
    'CONFIRMED' => 'reservation_status_confirmed',
    'CHECKIN_PENDING' => 'reservation_status_checkin_pending',
    'STORED' => 'reservation_status_stored',
    'OUT_FOR_DELIVERY' => 'reservation_status_out_for_delivery',
    'READY_FOR_PICKUP' => 'reservation_status_ready_for_pickup',
    'COMPLETED' => 'reservation_status_completed',
    'CANCELLED' => 'reservation_status_cancelled',
    'INCIDENT' => 'reservation_status_incident',
    'EXPIRED' => 'reservation_status_expired',
    _ => statusCode,
  };
}

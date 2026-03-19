class AppConstants {
  static const appName = 'TravelBox';
  static const apiVersion = 'v1';
  static const sessionTimeoutMinutes = 45;

  static const reservationStates = [
    'DRAFT',
    'PENDING_PAYMENT',
    'CONFIRMED',
    'CHECKIN_PENDING',
    'STORED',
    'OUT_FOR_DELIVERY',
    'READY_FOR_PICKUP',
    'COMPLETED',
    'CANCELLED',
    'INCIDENT',
  ];
}

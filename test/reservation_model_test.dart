import 'package:flutter_test/flutter_test.dart';
import 'package:travelbox_peru_app/shared/models/reservation.dart';

void main() {
  group('ReservationStatus', () {
    test('maps backend code correctly', () {
      expect(
        reservationStatusFromCode('CONFIRMED'),
        ReservationStatus.confirmed,
      );
      expect(
        reservationStatusFromCode('READY_FOR_PICKUP'),
        ReservationStatus.readyForPickup,
      );
      expect(reservationStatusFromCode('UNKNOWN'), ReservationStatus.draft);
    });

    test('exposes user label', () {
      expect(ReservationStatus.incident.label, 'Incidencia');
      expect(ReservationStatus.completed.label, 'Completada');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:travelbox_peru_app/features/reservation/domain/reservation_repository.dart';
import 'package:travelbox_peru_app/shared/models/warehouse.dart';

void main() {
  test('ReservationDraft estimate includes extras', () {
    final warehouse = Warehouse(
      id: 'wh-1',
      name: 'Test',
      address: 'Address',
      city: 'Lima',
      district: 'Miraflores',
      latitude: -12.0,
      longitude: -77.0,
      openingHours: '08:00 - 22:00',
      priceFromPerHour: 10,
      pricePerHourSmall: 8,
      pricePerHourMedium: 10,
      pricePerHourLarge: 12,
      pricePerHourExtraLarge: 14,
      pickupFee: 14,
      dropoffFee: 14,
      insuranceFee: 7.5,
      score: 4.8,
      availableSlots: 20,
      extraServices: const [],
    );

    final draft = ReservationDraft(
      warehouse: warehouse,
      bagCount: 2,
      startAt: DateTime(2026, 1, 10, 10),
      endAt: DateTime(2026, 1, 10, 14),
      size: 'M',
      extraInsurance: true,
      pickupRequested: false,
      dropoffRequested: true,
    );

    // 4h * 2 bags * 10 + 7.5 + 14 = 101.5
    expect(draft.estimatePrice(), 101.5);
  });
}

import '../models/reservation.dart';
import '../models/warehouse.dart';

class DemoData {
  static List<Warehouse> warehouses = const [
    Warehouse(
      id: 'wh-lim-mir-01',
      name: 'TravelBox Miraflores',
      address: 'Av. Jose Larco 812',
      city: 'Lima',
      district: 'Miraflores',
      latitude: -12.126347,
      longitude: -77.030072,
      openingHours: '06:00 - 23:00',
      priceFromPerHour: 10.0,
      pricePerHourSmall: 8.5,
      pricePerHourMedium: 10.0,
      pricePerHourLarge: 12.0,
      pricePerHourExtraLarge: 14.0,
      pickupFee: 14.0,
      dropoffFee: 14.0,
      insuranceFee: 7.5,
      score: 4.8,
      availableSlots: 32,
      extraServices: ['Basic insurance', 'Delivery', 'Locker XL'],
    ),
    Warehouse(
      id: 'wh-lim-bar-02',
      name: 'TravelBox Barranco',
      address: 'Jiron Perez Roca 450',
      city: 'Lima',
      district: 'Barranco',
      latitude: -12.148103,
      longitude: -77.020508,
      openingHours: '07:00 - 22:00',
      priceFromPerHour: 9.0,
      pricePerHourSmall: 7.8,
      pricePerHourMedium: 9.0,
      pricePerHourLarge: 10.5,
      pricePerHourExtraLarge: 12.0,
      pickupFee: 13.0,
      dropoffFee: 13.0,
      insuranceFee: 7.5,
      score: 4.7,
      availableSlots: 18,
      extraServices: ['Delivery', 'Photo evidence'],
    ),
    Warehouse(
      id: 'wh-cus-cen-01',
      name: 'TravelBox Cusco Centro',
      address: 'Calle Plateros 310',
      city: 'Cusco',
      district: 'Centro Historico',
      latitude: -13.516869,
      longitude: -71.978272,
      openingHours: '06:00 - 21:00',
      priceFromPerHour: 11.5,
      pricePerHourSmall: 9.5,
      pricePerHourMedium: 11.5,
      pricePerHourLarge: 13.5,
      pricePerHourExtraLarge: 15.0,
      pickupFee: 16.0,
      dropoffFee: 16.0,
      insuranceFee: 8.0,
      score: 4.9,
      availableSlots: 21,
      extraServices: ['Premium insurance', 'Hotel pickup'],
    ),
  ];

  static Warehouse? findWarehouse(String id) {
    try {
      return warehouses.firstWhere((warehouse) => warehouse.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<ReservationTimelineEvent> initialTimeline() {
    return [
      ReservationTimelineEvent(
        status: ReservationStatus.confirmed,
        timestamp: DateTime.now(),
        message: 'Reservation confirmed and QR generated',
      ),
    ];
  }
}

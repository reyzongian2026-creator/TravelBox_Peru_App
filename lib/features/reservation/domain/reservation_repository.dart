import '../../../shared/models/reservation.dart';
import '../../../shared/models/warehouse.dart';

class ReservationDraft {
  const ReservationDraft({
    required this.warehouse,
    required this.bagCount,
    required this.startAt,
    required this.endAt,
    required this.size,
    required this.extraInsurance,
    required this.pickupRequested,
    required this.dropoffRequested,
  });

  final Warehouse warehouse;
  final int bagCount;
  final DateTime startAt;
  final DateTime endAt;
  final String size;
  final bool extraInsurance;
  final bool pickupRequested;
  final bool dropoffRequested;

  int billableHours() {
    return endAt.difference(startAt).inHours.clamp(1, 96);
  }

  double storageSubtotal() {
    final hours = billableHours();
    return warehouse.rateForSize(size) * bagCount * hours;
  }

  double insuranceCost() {
    return extraInsurance ? warehouse.insuranceFee : 0;
  }

  double pickupCost() {
    return pickupRequested ? warehouse.pickupFee : 0;
  }

  double dropoffCost() {
    return dropoffRequested ? warehouse.dropoffFee : 0;
  }

  double estimatePrice() {
    return storageSubtotal() + insuranceCost() + pickupCost() + dropoffCost();
  }
}

abstract class ReservationRepository {
  Future<Reservation> createReservation({
    required String userId,
    required ReservationDraft draft,
    String paymentMethod = 'card',
    String? sourceTokenId,
    String? customerEmail,
  });

  Future<List<Reservation>> getReservationsByUser(String userId);

  Future<List<Reservation>> getAllReservations({
    ReservationStatus? status,
    String? query,
    int size = 50,
  });

  Future<Reservation?> getReservationById(String reservationId);

  Future<Reservation> updateStatus({
    required String reservationId,
    required ReservationStatus status,
    required String message,
  });

  Future<void> refundAndCancelReservation({
    required String reservationId,
    required String reason,
  });

  Future<void> requestLogisticsOrder({
    required String reservationId,
    required String type,
    required String address,
    String? zone,
    double? latitude,
    double? longitude,
    String? message,
  });
}


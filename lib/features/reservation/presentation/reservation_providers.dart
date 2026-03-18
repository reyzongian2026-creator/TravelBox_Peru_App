import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/reservation.dart';
import '../../../shared/state/realtime_app_event_cursor_provider.dart';
import '../../../shared/state/session_controller.dart';
import '../data/reservation_repository_impl.dart';

final reservationRealtimeEventCursorProvider = Provider<int>((ref) {
  return ref.watch(realtimeAppEventCursorProvider);
});

final myReservationsProvider = FutureProvider<List<Reservation>>((ref) async {
  ref.watch(reservationRealtimeEventCursorProvider);
  final userId = ref.watch(sessionControllerProvider).user?.id;
  if (userId == null) {
    return const [];
  }
  return ref.read(reservationRepositoryProvider).getReservationsByUser(userId);
});

final reservationByIdProvider = FutureProvider.family<Reservation?, String>((
  ref,
  reservationId,
) {
  ref.watch(reservationRealtimeEventCursorProvider);
  return ref
      .read(reservationRepositoryProvider)
      .getReservationById(reservationId);
});

final adminReservationSearchProvider = StateProvider<String>((ref) => '');

final adminReservationStatusFilterProvider = StateProvider<ReservationStatus?>(
  (ref) => null,
);

final adminReservationListProvider = FutureProvider<List<Reservation>>((ref) {
  ref.watch(reservationRealtimeEventCursorProvider);
  final query = ref.watch(adminReservationSearchProvider).trim();
  final status = ref.watch(adminReservationStatusFilterProvider);
  return ref
      .read(reservationRepositoryProvider)
      .getAllReservations(
        status: status,
        query: query.isEmpty ? null : query,
        size: 100,
      );
});

final adminReservationsProvider = FutureProvider<List<Reservation>>((ref) {
  ref.watch(reservationRealtimeEventCursorProvider);
  return ref.read(reservationRepositoryProvider).getAllReservations(size: 100);
});


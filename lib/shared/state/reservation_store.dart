import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reservation.dart';
import 'session_controller.dart';

const _reservationsKey = 'travelbox.reservations.v1';

final reservationStoreProvider =
    StateNotifierProvider<ReservationStore, List<Reservation>>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ReservationStore(prefs);
    });

class ReservationStore extends StateNotifier<List<Reservation>> {
  ReservationStore(this._prefs) : super(const []) {
    _restore();
  }

  final SharedPreferences _prefs;

  void _restore() {
    final raw = _prefs.getString(_reservationsKey);
    if (raw == null) {
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      state = decoded
          .map((item) => Reservation.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = const [];
    }
  }

  Future<void> _persist() {
    final encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    return _prefs.setString(_reservationsKey, encoded);
  }

  Future<void> upsert(Reservation reservation) async {
    final copy = [...state];
    final index = copy.indexWhere((item) => item.id == reservation.id);
    if (index >= 0) {
      copy[index] = reservation;
    } else {
      copy.insert(0, reservation);
    }
    state = copy;
    await _persist();
  }

  Future<void> replaceForUser(
    String userId,
    List<Reservation> reservations,
  ) async {
    final preserved = state.where((item) => item.userId != userId).toList();
    state = [...reservations, ...preserved];
    await _persist();
  }

  Reservation? findById(String id) {
    try {
      return state.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}

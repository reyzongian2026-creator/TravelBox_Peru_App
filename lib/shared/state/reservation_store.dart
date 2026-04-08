import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reservation.dart';
import 'session_controller.dart';

const _reservationsKey = 'travelbox.reservations.v2';
const _oldReservationsKey = 'travelbox.reservations.v1';
const _maxCachedItems = 10;

final reservationStoreProvider =
    StateNotifierProvider<ReservationStore, List<Reservation>>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ReservationStore(prefs);
    });

class ReservationStore extends StateNotifier<List<Reservation>> {
  ReservationStore(this._prefs) : super(const []) {
    _migrateAndRestore();
  }

  final SharedPreferences _prefs;

  void _migrateAndRestore() {
    // Remove old v1 key that accumulated unlimited data
    if (_prefs.containsKey(_oldReservationsKey)) {
      _prefs.remove(_oldReservationsKey);
    }
    final raw = _prefs.getString(_reservationsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      state = decoded
          .take(_maxCachedItems)
          .map((item) => Reservation.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = const [];
    }
  }

  Future<void> _persist() async {
    try {
      final capped = state.take(_maxCachedItems).toList();
      final encoded = jsonEncode(capped.map((e) => e.toJson()).toList());
      await _prefs.setString(_reservationsKey, encoded);
    } catch (e) {
      // QuotaExceededError on web — clear cache and retry with minimal data
      debugPrint('[ReservationStore] persist failed (QuotaExceeded?): $e');
      try {
        await _prefs.remove(_reservationsKey);
      } catch (_) {}
    }
  }

  Future<void> upsert(Reservation reservation) async {
    final copy = [...state];
    final index = copy.indexWhere((item) => item.id == reservation.id);
    if (index >= 0) {
      copy[index] = reservation;
    } else {
      copy.insert(0, reservation);
    }
    state = copy.take(_maxCachedItems).toList();
    await _persist();
  }

  Future<void> replaceForUser(
    String userId,
    List<Reservation> reservations,
  ) async {
    // Only keep the current page items — don't accumulate
    state = reservations.take(_maxCachedItems).toList();
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    try {
      await _prefs.remove(_reservationsKey);
    } catch (_) {}
  }

  Reservation? findById(String id) {
    try {
      return state.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}

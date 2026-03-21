import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reservation.dart';

final luggagePhotoMemoryStoreProvider =
    StateNotifierProvider<
      LuggagePhotoMemoryStore,
      Map<String, LuggagePhotoMemoryEntry>
    >((ref) {
      return LuggagePhotoMemoryStore();
    });

class LuggagePhotoMemoryEntry {
  const LuggagePhotoMemoryEntry({
    required this.photos,
    required this.luggagePhotosLocked,
    required this.expectedPhotos,
  });

  final List<ReservationLuggagePhoto> photos;
  final bool luggagePhotosLocked;
  final int expectedPhotos;

  LuggagePhotoMemoryEntry copyWith({
    List<ReservationLuggagePhoto>? photos,
    bool? luggagePhotosLocked,
    int? expectedPhotos,
  }) {
    return LuggagePhotoMemoryEntry(
      photos: photos ?? this.photos,
      luggagePhotosLocked: luggagePhotosLocked ?? this.luggagePhotosLocked,
      expectedPhotos: expectedPhotos ?? this.expectedPhotos,
    );
  }
}

class LuggagePhotoMemoryStore
    extends StateNotifier<Map<String, LuggagePhotoMemoryEntry>> {
  LuggagePhotoMemoryStore() : super(const {});

  void addClientHandoffPhoto({
    required Reservation reservation,
    required List<int> bytes,
    required String mimeType,
    required String filename,
    String? capturedByUserId,
    String? capturedByName,
  }) {
    final now = DateTime.now();
    final photo = ReservationLuggagePhoto(
      id: 'mem-client-${now.microsecondsSinceEpoch}',
      type: 'CLIENT_HANDOFF_PHOTO',
      bagUnitIndex: null,
      imageUrl: _toDataUrl(bytes: bytes, mimeType: mimeType),
      capturedAt: now,
      capturedByUserId: capturedByUserId,
      capturedByName: capturedByName,
    );
    _merge(
      reservationId: reservation.id,
      incomingPhotos: [photo],
      lockPhotos: false,
      expectedPhotos: reservation.bagCount,
    );
  }

  void addWarehouseBagPhotos({
    required Reservation reservation,
    required List<MemoryBagPhotoInput> photos,
    String? capturedByUserId,
    String? capturedByName,
  }) {
    final now = DateTime.now();
    final mapped = photos
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final input = entry.value;
          return ReservationLuggagePhoto(
            id: 'mem-warehouse-${now.microsecondsSinceEpoch}-$index',
            type: 'CHECKIN_BAG_PHOTO',
            bagUnitIndex: index + 1,
            imageUrl: _toDataUrl(bytes: input.bytes, mimeType: input.mimeType),
            capturedAt: now,
            capturedByUserId: capturedByUserId,
            capturedByName: capturedByName,
          );
        })
        .toList(growable: false);

    _merge(
      reservationId: reservation.id,
      incomingPhotos: mapped,
      lockPhotos: true,
      expectedPhotos: math.max(reservation.bagCount, mapped.length),
    );
  }

  Reservation applyToReservation(Reservation reservation) {
    final entry = state[reservation.id];
    if (entry == null || entry.photos.isEmpty) {
      return reservation;
    }

    final operational = reservation.operationalDetail;
    final merged = _mergePhotos(
      base: operational?.luggagePhotos ?? const [],
      incoming: entry.photos,
    );
    final expected = math.max(
      operational?.expectedLuggagePhotos ?? 0,
      entry.expectedPhotos,
    );
    final storedCount = math.max(
      operational?.storedLuggagePhotos ?? 0,
      merged.length,
    );
    final mergedOperational = ReservationOperationalDetail(
      stage: operational?.stage,
      bagTagId: operational?.bagTagId,
      bagTagQrPayload: operational?.bagTagQrPayload,
      bagUnits: operational?.bagUnits ?? reservation.bagCount,
      pickupPinGenerated: operational?.pickupPinGenerated ?? false,
      pickupPinVisible: operational?.pickupPinVisible ?? false,
      pickupPin: operational?.pickupPin,
      canViewLuggagePhotos: true,
      luggagePhotosLocked:
          (operational?.luggagePhotosLocked ?? false) ||
          entry.luggagePhotosLocked,
      expectedLuggagePhotos: expected,
      storedLuggagePhotos: storedCount,
      checkinAt: operational?.checkinAt,
      lastCheckoutAt: operational?.lastCheckoutAt,
      luggagePhotos: merged,
    );
    return reservation.copyWith(operationalDetail: mergedOperational);
  }

  void _merge({
    required String reservationId,
    required List<ReservationLuggagePhoto> incomingPhotos,
    required bool lockPhotos,
    required int expectedPhotos,
  }) {
    final current = state[reservationId];
    final mergedPhotos = _mergePhotos(
      base: current?.photos ?? const [],
      incoming: incomingPhotos,
    );
    final nextEntry = LuggagePhotoMemoryEntry(
      photos: mergedPhotos,
      luggagePhotosLocked:
          (current?.luggagePhotosLocked ?? false) || lockPhotos,
      expectedPhotos: math.max(current?.expectedPhotos ?? 0, expectedPhotos),
    );
    state = {...state, reservationId: nextEntry};
  }

  List<ReservationLuggagePhoto> _mergePhotos({
    required List<ReservationLuggagePhoto> base,
    required List<ReservationLuggagePhoto> incoming,
  }) {
    final byKey = <String, ReservationLuggagePhoto>{};
    for (final photo in [...base, ...incoming]) {
      byKey[_photoIdentity(photo)] = photo;
    }
    final merged = byKey.values.toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return merged;
  }

  String _photoIdentity(ReservationLuggagePhoto photo) {
    return [
      photo.type.trim().toUpperCase(),
      '${photo.bagUnitIndex ?? 0}',
      photo.imageUrl.trim(),
    ].join('|');
  }

  String _toDataUrl({required List<int> bytes, required String mimeType}) {
    final normalizedMime = mimeType.trim().isEmpty
        ? 'image/jpeg'
        : mimeType.trim();
    return 'data:$normalizedMime;base64,${base64Encode(bytes)}';
  }
}

class MemoryBagPhotoInput {
  const MemoryBagPhotoInput({
    required this.bytes,
    required this.mimeType,
    required this.filename,
  });

  final List<int> bytes;
  final String mimeType;
  final String filename;
}

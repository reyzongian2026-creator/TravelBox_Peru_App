import 'package:flutter/material.dart';

import '../../core/theme/brand_tokens.dart';
import 'warehouse.dart';

enum ReservationStatus {
  draft,
  pendingPayment,
  confirmed,
  checkinPending,
  stored,
  outForDelivery,
  readyForPickup,
  completed,
  cancelled,
  incident,
  expired,
}

extension ReservationStatusX on ReservationStatus {
  String get code {
    switch (this) {
      case ReservationStatus.draft:
        return 'DRAFT';
      case ReservationStatus.pendingPayment:
        return 'PENDING_PAYMENT';
      case ReservationStatus.confirmed:
        return 'CONFIRMED';
      case ReservationStatus.checkinPending:
        return 'CHECKIN_PENDING';
      case ReservationStatus.stored:
        return 'STORED';
      case ReservationStatus.outForDelivery:
        return 'OUT_FOR_DELIVERY';
      case ReservationStatus.readyForPickup:
        return 'READY_FOR_PICKUP';
      case ReservationStatus.completed:
        return 'COMPLETED';
      case ReservationStatus.cancelled:
        return 'CANCELLED';
      case ReservationStatus.incident:
        return 'INCIDENT';
      case ReservationStatus.expired:
        return 'EXPIRED';
    }
  }

  String get label {
    switch (this) {
      case ReservationStatus.draft:
        return 'Borrador';
      case ReservationStatus.pendingPayment:
        return 'Pendiente pago';
      case ReservationStatus.confirmed:
        return 'Confirmada';
      case ReservationStatus.checkinPending:
        return 'Check-in pendiente';
      case ReservationStatus.stored:
        return 'Almacenado';
      case ReservationStatus.outForDelivery:
        return 'En delivery';
      case ReservationStatus.readyForPickup:
        return 'Listo para recojo';
      case ReservationStatus.completed:
        return 'Completada';
      case ReservationStatus.cancelled:
        return 'Cancelada';
      case ReservationStatus.incident:
        return 'Incidencia';
      case ReservationStatus.expired:
        return 'Expirada';
    }
  }

  Color get color {
    switch (this) {
      case ReservationStatus.completed:
        return TravelBoxBrand.statusSuccess;
      case ReservationStatus.cancelled:
      case ReservationStatus.incident:
        return TravelBoxBrand.statusError;
      case ReservationStatus.expired:
        return TravelBoxBrand.statusExpired;
      case ReservationStatus.stored:
      case ReservationStatus.confirmed:
      case ReservationStatus.readyForPickup:
        return TravelBoxBrand.statusPending;
      case ReservationStatus.pendingPayment:
      case ReservationStatus.checkinPending:
      case ReservationStatus.outForDelivery:
      case ReservationStatus.draft:
        return TravelBoxBrand.statusWarning;
    }
  }
}

class ReservationTimelineEvent {
  const ReservationTimelineEvent({
    required this.status,
    required this.timestamp,
    required this.message,
  });

  final ReservationStatus status;
  final DateTime timestamp;
  final String message;

  Map<String, dynamic> toJson() {
    return {
      'status': status.code,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
    };
  }

  factory ReservationTimelineEvent.fromJson(Map<String, dynamic> json) {
    return ReservationTimelineEvent(
      status: reservationStatusFromCode(
        json['status']?.toString() ?? ReservationStatus.draft.code,
      ),
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      message: json['message']?.toString() ?? '',
    );
  }
}

class ReservationLuggagePhoto {
  const ReservationLuggagePhoto({
    required this.id,
    required this.type,
    required this.bagUnitIndex,
    required this.imageUrl,
    required this.capturedAt,
    this.capturedByUserId,
    this.capturedByName,
  });

  final String id;
  final String type;
  final int? bagUnitIndex;
  final String imageUrl;
  final DateTime capturedAt;
  final String? capturedByUserId;
  final String? capturedByName;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'bagUnitIndex': bagUnitIndex,
      'imageUrl': imageUrl,
      'capturedAt': capturedAt.toIso8601String(),
      'capturedByUserId': capturedByUserId,
      'capturedByName': capturedByName,
    };
  }

  factory ReservationLuggagePhoto.fromJson(Map<String, dynamic> json) {
    return ReservationLuggagePhoto(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'CHECKIN_BAG_PHOTO',
      bagUnitIndex: (json['bagUnitIndex'] as num?)?.toInt(),
      imageUrl: json['imageUrl']?.toString() ?? '',
      capturedAt:
          DateTime.tryParse(json['capturedAt']?.toString() ?? '') ??
          DateTime.now(),
      capturedByUserId: json['capturedByUserId']?.toString(),
      capturedByName: json['capturedByName']?.toString(),
    );
  }
}

class ReservationOperationalDetail {
  const ReservationOperationalDetail({
    this.stage,
    this.bagTagId,
    this.bagTagQrPayload,
    this.bagUnits = 1,
    this.pickupPinGenerated = false,
    this.pickupPinVisible = false,
    this.pickupPin,
    this.canViewLuggagePhotos = false,
    this.luggagePhotosLocked = false,
    this.expectedLuggagePhotos = 0,
    this.storedLuggagePhotos = 0,
    this.checkinAt,
    this.lastCheckoutAt,
    this.luggagePhotos = const [],
  });

  final String? stage;
  final String? bagTagId;
  final String? bagTagQrPayload;
  final int bagUnits;
  final bool pickupPinGenerated;
  final bool pickupPinVisible;
  final String? pickupPin;
  final bool canViewLuggagePhotos;
  final bool luggagePhotosLocked;
  final int expectedLuggagePhotos;
  final int storedLuggagePhotos;
  final DateTime? checkinAt;
  final DateTime? lastCheckoutAt;
  final List<ReservationLuggagePhoto> luggagePhotos;

  Map<String, dynamic> toJson() {
    return {
      'stage': stage,
      'bagTagId': bagTagId,
      'bagTagQrPayload': bagTagQrPayload,
      'bagUnits': bagUnits,
      'pickupPinGenerated': pickupPinGenerated,
      'pickupPinVisible': pickupPinVisible,
      'pickupPin': pickupPin,
      'canViewLuggagePhotos': canViewLuggagePhotos,
      'luggagePhotosLocked': luggagePhotosLocked,
      'expectedLuggagePhotos': expectedLuggagePhotos,
      'storedLuggagePhotos': storedLuggagePhotos,
      'checkinAt': checkinAt?.toIso8601String(),
      'lastCheckoutAt': lastCheckoutAt?.toIso8601String(),
      'luggagePhotos': luggagePhotos.map((item) => item.toJson()).toList(),
    };
  }

  factory ReservationOperationalDetail.fromJson(Map<String, dynamic> json) {
    return ReservationOperationalDetail(
      stage: json['stage']?.toString(),
      bagTagId: json['bagTagId']?.toString(),
      bagTagQrPayload: json['bagTagQrPayload']?.toString(),
      bagUnits: (json['bagUnits'] as num?)?.toInt() ?? 1,
      pickupPinGenerated: json['pickupPinGenerated'] as bool? ?? false,
      pickupPinVisible: json['pickupPinVisible'] as bool? ?? false,
      pickupPin: json['pickupPin']?.toString(),
      canViewLuggagePhotos: json['canViewLuggagePhotos'] as bool? ?? false,
      luggagePhotosLocked: json['luggagePhotosLocked'] as bool? ?? false,
      expectedLuggagePhotos:
          (json['expectedLuggagePhotos'] as num?)?.toInt() ?? 0,
      storedLuggagePhotos: (json['storedLuggagePhotos'] as num?)?.toInt() ?? 0,
      checkinAt: DateTime.tryParse(json['checkinAt']?.toString() ?? ''),
      lastCheckoutAt: DateTime.tryParse(
        json['lastCheckoutAt']?.toString() ?? '',
      ),
      luggagePhotos: (json['luggagePhotos'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReservationLuggagePhoto.fromJson)
          .toList(),
    );
  }
}

class Reservation {
  const Reservation({
    required this.id,
    required this.code,
    required this.userId,
    required this.warehouse,
    required this.startAt,
    required this.endAt,
    required this.bagCount,
    required this.totalPrice,
    required this.status,
    required this.timeline,
    this.pickupRequested = false,
    this.dropoffRequested = false,
    this.extraInsurance = false,
    this.latePickupSurcharge = 0,
    this.qrImageUrl,
    this.qrDataUrl,
    this.operationalDetail,
  });

  final String id;
  final String code;
  final String userId;
  final Warehouse warehouse;
  final DateTime startAt;
  final DateTime endAt;
  final int bagCount;
  final double totalPrice;
  final ReservationStatus status;
  final List<ReservationTimelineEvent> timeline;
  final bool pickupRequested;
  final bool dropoffRequested;
  final bool extraInsurance;
  final double latePickupSurcharge;
  final String? qrImageUrl;
  final String? qrDataUrl;
  final ReservationOperationalDetail? operationalDetail;

  Reservation copyWith({
    ReservationStatus? status,
    List<ReservationTimelineEvent>? timeline,
    ReservationOperationalDetail? operationalDetail,
    bool? pickupRequested,
    bool? dropoffRequested,
    bool? extraInsurance,
    double? latePickupSurcharge,
  }) {
    return Reservation(
      id: id,
      code: code,
      userId: userId,
      warehouse: warehouse,
      startAt: startAt,
      endAt: endAt,
      bagCount: bagCount,
      totalPrice: totalPrice,
      status: status ?? this.status,
      timeline: timeline ?? this.timeline,
      pickupRequested: pickupRequested ?? this.pickupRequested,
      dropoffRequested: dropoffRequested ?? this.dropoffRequested,
      extraInsurance: extraInsurance ?? this.extraInsurance,
      latePickupSurcharge: latePickupSurcharge ?? this.latePickupSurcharge,
      qrImageUrl: qrImageUrl,
      qrDataUrl: qrDataUrl,
      operationalDetail: operationalDetail ?? this.operationalDetail,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'userId': userId,
      'warehouse': warehouse.toJson(),
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'bagCount': bagCount,
      'totalPrice': totalPrice,
      'status': status.code,
      'timeline': timeline.map((e) => e.toJson()).toList(),
      'pickupRequested': pickupRequested,
      'dropoffRequested': dropoffRequested,
      'extraInsurance': extraInsurance,
      'latePickupSurcharge': latePickupSurcharge,
      'qrImageUrl': qrImageUrl,
      'qrDataUrl': qrDataUrl,
      'operationalDetail': operationalDetail?.toJson(),
    };
  }

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final status = reservationStatusFromCode(json['status']?.toString() ?? '');
    final startAt =
        DateTime.tryParse(json['startAt']?.toString() ?? '') ?? DateTime.now();
    final endAt =
        DateTime.tryParse(json['endAt']?.toString() ?? '') ?? DateTime.now();
    final parsedTimeline = (json['timeline'] as List<dynamic>? ?? [])
        .map(
          (event) =>
              ReservationTimelineEvent.fromJson(event as Map<String, dynamic>),
        )
        .toList();
    if (parsedTimeline.isEmpty) {
      parsedTimeline.add(
        ReservationTimelineEvent(
          status: status,
          timestamp: DateTime.now(),
          message: _defaultStatusMessage(
            status,
            cancelReason: json['cancelReason']?.toString(),
          ),
        ),
      );
    }

    final warehouseJson =
        json['warehouse'] as Map<String, dynamic>? ??
        _warehouseFromFlatReservation(json);

    return Reservation(
      id: json['id']?.toString() ?? '',
      code:
          json['code']?.toString() ??
          json['qrCode']?.toString() ??
          'TBX-${json['id'] ?? ''}',
      userId: json['userId']?.toString() ?? '',
      warehouse: Warehouse.fromJson(warehouseJson),
      startAt: startAt,
      endAt: endAt,
      bagCount:
          (json['bagCount'] as num?)?.toInt() ??
          (json['estimatedItems'] as num?)?.toInt() ??
          1,
      totalPrice:
          (json['totalPrice'] as num?)?.toDouble() ??
          (json['total'] as num?)?.toDouble() ??
          (json['amount'] as num?)?.toDouble() ??
          0,
      status: status,
      timeline: parsedTimeline,
      pickupRequested: json['pickupRequested'] as bool? ?? false,
      dropoffRequested:
          (json['dropoffRequested'] ?? json['deliveryRequested']) as bool? ??
          false,
      extraInsurance: json['extraInsurance'] as bool? ?? false,
      latePickupSurcharge:
          (json['latePickupSurcharge'] as num?)?.toDouble() ?? 0,
      qrImageUrl: json['qrImageUrl']?.toString(),
      qrDataUrl: json['qrImageDataUrl']?.toString(),
      operationalDetail: json['operationalDetail'] is Map<String, dynamic>
          ? ReservationOperationalDetail.fromJson(
              json['operationalDetail'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

ReservationStatus reservationStatusFromCode(String code) {
  final normalized = code.trim().toUpperCase().replaceAll(' ', '_');
  final plain = normalized.replaceAll('RESERVATIONSTATUS.', '');
  for (final status in ReservationStatus.values) {
    if (status.code == plain) {
      return status;
    }
  }
  return ReservationStatus.draft;
}

String _defaultStatusMessage(ReservationStatus status, {String? cancelReason}) {
  switch (status) {
    case ReservationStatus.pendingPayment:
      return _timelineMessageToken('reservation_timeline_pending_payment');
    case ReservationStatus.confirmed:
      return _timelineMessageToken('reservation_timeline_confirmed');
    case ReservationStatus.checkinPending:
      return _timelineMessageToken('reservation_timeline_checkin_pending');
    case ReservationStatus.stored:
      return _timelineMessageToken('reservation_timeline_stored');
    case ReservationStatus.readyForPickup:
      return _timelineMessageToken('reservation_timeline_ready_for_pickup');
    case ReservationStatus.outForDelivery:
      return _timelineMessageToken('reservation_timeline_out_for_delivery');
    case ReservationStatus.completed:
      return _timelineMessageToken('reservation_timeline_completed');
    case ReservationStatus.cancelled:
      return cancelReason?.trim().isNotEmpty == true
          ? _timelineMessageToken(
              'reservation_timeline_cancelled_reason_prefix',
              cancelReason!.trim(),
            )
          : _timelineMessageToken('reservation_timeline_cancelled');
    case ReservationStatus.incident:
      return _timelineMessageToken('reservation_timeline_incident');
    case ReservationStatus.expired:
      return _timelineMessageToken('reservation_timeline_expired');
    case ReservationStatus.draft:
      return _timelineMessageToken('reservation_timeline_draft');
  }
}

Map<String, dynamic> _warehouseFromFlatReservation(Map<String, dynamic> json) {
  final openHour = json['openHour']?.toString();
  final closeHour = json['closeHour']?.toString();
  final openingHours = (openHour != null && closeHour != null)
      ? '$openHour - $closeHour'
      : null;
  return <String, dynamic>{
    'id': json['warehouseId'] ?? json['warehouse_id'],
    'name': json['warehouseName'] ?? json['warehouse_name'] ?? 'Warehouse',
    'address': json['warehouseAddress'] ?? json['address'] ?? 'No address',
    'city': json['cityName'] ?? json['city'] ?? '',
    'district': json['zoneName'] ?? json['district'] ?? '',
    'latitude': json['warehouseLat'] ?? json['lat'] ?? json['latitude'] ?? 0,
    'longitude': json['warehouseLng'] ?? json['lng'] ?? json['longitude'] ?? 0,
    'openingHours': openingHours ?? json['openingHours'] ?? '08:00 - 22:00',
    'priceFromPerHour': json['priceFromPerHour'] ?? 4.5,
    'score': json['score'] ?? 0,
    'availableSlots':
        json['availableInRange'] ?? json['available'] ?? json['availableSlots'],
    'extraServices': json['extraServices'] ?? <String>[],
    'imageUrl':
        json['coverImageUrl'] ??
        json['imageUrl'] ??
        json['photoUrl'] ??
        json['image'] ??
        json['imagen'],
  };
}

String _timelineMessageToken(String key, [String? argument]) {
  if (argument == null || argument.trim().isEmpty) {
    return '__L10N__:$key';
  }
  return '__L10N__:$key|${argument.trim()}';
}

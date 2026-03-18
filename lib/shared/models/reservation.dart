import 'package:flutter/material.dart';

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
        return const Color(0xFF168F64);
      case ReservationStatus.cancelled:
      case ReservationStatus.incident:
        return const Color(0xFFC43D3D);
      case ReservationStatus.expired:
        return const Color(0xFF6B7280);
      case ReservationStatus.stored:
      case ReservationStatus.confirmed:
      case ReservationStatus.readyForPickup:
        return const Color(0xFF1F6E8C);
      case ReservationStatus.pendingPayment:
      case ReservationStatus.checkinPending:
      case ReservationStatus.outForDelivery:
      case ReservationStatus.draft:
        return const Color(0xFFF29F05);
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
    required this.bagUnitIndex,
    required this.imageUrl,
    required this.capturedAt,
    this.capturedByUserId,
    this.capturedByName,
  });

  final String id;
  final int bagUnitIndex;
  final String imageUrl;
  final DateTime capturedAt;
  final String? capturedByUserId;
  final String? capturedByName;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      bagUnitIndex: (json['bagUnitIndex'] as num?)?.toInt() ?? 0,
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
      storedLuggagePhotos:
          (json['storedLuggagePhotos'] as num?)?.toInt() ?? 0,
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
      qrImageUrl: json['qrImageUrl']?.toString(),
      qrDataUrl: json['qrImageDataUrl']?.toString(),
      operationalDetail:
          json['operationalDetail'] is Map<String, dynamic>
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
      return 'Reserva creada, pendiente de pago.';
    case ReservationStatus.confirmed:
      return 'Pago confirmado.';
    case ReservationStatus.checkinPending:
      return 'Check-in pendiente.';
    case ReservationStatus.stored:
      return 'Equipaje almacenado.';
    case ReservationStatus.readyForPickup:
      return 'Listo para recojo.';
    case ReservationStatus.outForDelivery:
      return 'En ruta de delivery.';
    case ReservationStatus.completed:
      return 'Reserva completada.';
    case ReservationStatus.cancelled:
      return cancelReason?.trim().isNotEmpty == true
          ? 'Cancelada: ${cancelReason!.trim()}'
          : 'Reserva cancelada.';
    case ReservationStatus.incident:
      return 'Incidencia reportada.';
    case ReservationStatus.expired:
      return 'Reserva expirada.';
    case ReservationStatus.draft:
      return 'Borrador de reserva.';
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
    'name': json['warehouseName'] ?? json['warehouse_name'] ?? 'Almacen',
    'address': json['warehouseAddress'] ?? json['address'] ?? 'Sin direccion',
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

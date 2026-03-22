enum PhotoType {
  checkin,
  checkout,
  clientHandoff,
  warehouseReceived,
}

extension PhotoTypeExtension on PhotoType {
  String get value {
    switch (this) {
      case PhotoType.checkin:
        return 'CHECKIN';
      case PhotoType.checkout:
        return 'CHECKOUT';
      case PhotoType.clientHandoff:
        return 'CLIENT_HANDOFF';
      case PhotoType.warehouseReceived:
        return 'WAREHOUSE_RECEIVED';
    }
  }

  String get displayName {
    switch (this) {
      case PhotoType.checkin:
        return 'Foto Check-in';
      case PhotoType.checkout:
        return 'Foto Check-out';
      case PhotoType.clientHandoff:
        return 'Foto del Cliente';
      case PhotoType.warehouseReceived:
        return 'Foto Recepcionada';
    }
  }

  String displayNameWithLocale(dynamic l10n) {
    switch (this) {
      case PhotoType.checkin:
        return l10n.t('photo_type_checkin');
      case PhotoType.checkout:
        return l10n.t('photo_type_checkout');
      case PhotoType.clientHandoff:
        return l10n.t('photo_type_client_handoff');
      case PhotoType.warehouseReceived:
        return l10n.t('photo_type_warehouse_received');
    }
  }

  static PhotoType? fromString(String value) {
    switch (value.toUpperCase()) {
      case 'CHECKIN':
        return PhotoType.checkin;
      case 'CHECKOUT':
        return PhotoType.checkout;
      case 'CLIENT_HANDOFF':
        return PhotoType.clientHandoff;
      case 'WAREHOUSE_RECEIVED':
        return PhotoType.warehouseReceived;
      default:
        return null;
    }
  }
}

class ReservationPhoto {
  final String id;
  final int reservationId;
  final PhotoType type;
  final String imageUrl;
  final String? thumbnailUrl;
  final String uploadedBy;
  final String? uploadedByRole;
  final DateTime createdAt;
  final int? bagIndex;
  final bool isImmutable;

  ReservationPhoto({
    required this.id,
    required this.reservationId,
    required this.type,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.uploadedBy,
    this.uploadedByRole,
    required this.createdAt,
    this.bagIndex,
    this.isImmutable = false,
  });

  factory ReservationPhoto.fromJson(Map<String, dynamic> json) {
    return ReservationPhoto(
      id: json['id']?.toString() ?? '',
      reservationId: (json['reservationId'] as num?)?.toInt() ?? 0,
      type: PhotoTypeExtension.fromString(json['type']?.toString() ?? '') ?? PhotoType.checkin,
      imageUrl: json['imageUrl']?.toString() ?? json['url']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      uploadedBy: json['uploadedBy']?.toString() ?? '',
      uploadedByRole: json['uploadedByRole']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      bagIndex: (json['bagIndex'] as num?)?.toInt(),
      isImmutable: (json['isImmutable'] as bool?) ?? _isTypeImmutable(json['type']?.toString() ?? ''),
    );
  }

  static bool _isTypeImmutable(String type) {
    return type == 'CHECKIN' ||
        type == 'CHECKOUT' ||
        type == 'WAREHOUSE_RECEIVED';
  }

  bool get canDelete {
    if (isImmutable) return false;
    if (type == PhotoType.clientHandoff) return true;
    return false;
  }
}

class ImageUploadResponse {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final String filename;
  final String contentType;
  final int size;
  final DateTime createdAt;

  ImageUploadResponse({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.filename,
    required this.contentType,
    required this.size,
    required this.createdAt,
  });

  factory ImageUploadResponse.fromJson(Map<String, dynamic> json) {
    return ImageUploadResponse(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      filename: json['filename']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? 'image/jpeg',
      size: (json['size'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

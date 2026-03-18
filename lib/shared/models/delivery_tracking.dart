class DeliveryTrackingEventModel {
  const DeliveryTrackingEventModel({
    required this.sequence,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.etaMinutes,
    required this.message,
    required this.createdAt,
  });

  final int sequence;
  final String status;
  final double latitude;
  final double longitude;
  final int etaMinutes;
  final String message;
  final DateTime createdAt;

  factory DeliveryTrackingEventModel.fromJson(Map<String, dynamic> json) {
    return DeliveryTrackingEventModel(
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'REQUESTED',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
      message: json['message']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class DeliveryTrackingModel {
  const DeliveryTrackingModel({
    required this.deliveryOrderId,
    required this.reservationId,
    required this.status,
    required this.driverName,
    required this.driverPhone,
    required this.vehicleType,
    required this.vehiclePlate,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.etaMinutes,
    required this.trackingMode,
    required this.reconnectSuggested,
    required this.lastUpdatedAt,
    required this.events,
  });

  final String deliveryOrderId;
  final String reservationId;
  final String status;
  final String driverName;
  final String driverPhone;
  final String vehicleType;
  final String vehiclePlate;
  final double currentLatitude;
  final double currentLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final int etaMinutes;
  final String trackingMode;
  final bool reconnectSuggested;
  final DateTime lastUpdatedAt;
  final List<DeliveryTrackingEventModel> events;

  bool get isDelivered => status.toUpperCase() == 'DELIVERED';

  factory DeliveryTrackingModel.fromJson(Map<String, dynamic> json) {
    return DeliveryTrackingModel(
      deliveryOrderId: json['deliveryOrderId']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'REQUESTED',
      driverName: json['driverName']?.toString() ?? 'Unidad asignada',
      driverPhone: json['driverPhone']?.toString() ?? '-',
      vehicleType: json['vehicleType']?.toString() ?? '-',
      vehiclePlate: json['vehiclePlate']?.toString() ?? '-',
      currentLatitude: (json['currentLatitude'] as num?)?.toDouble() ?? 0,
      currentLongitude: (json['currentLongitude'] as num?)?.toDouble() ?? 0,
      destinationLatitude:
          (json['destinationLatitude'] as num?)?.toDouble() ?? 0,
      destinationLongitude:
          (json['destinationLongitude'] as num?)?.toDouble() ?? 0,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
      trackingMode: json['trackingMode']?.toString() ?? 'mock',
      reconnectSuggested: json['reconnectSuggested'] as bool? ?? false,
      lastUpdatedAt:
          DateTime.tryParse(json['lastUpdatedAt']?.toString() ?? '') ??
          DateTime.now(),
      events: (json['events'] as List<dynamic>? ?? const [])
          .map(
            (item) => DeliveryTrackingEventModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class GeoRoutePoint {
  const GeoRoutePoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  factory GeoRoutePoint.fromJson(Map<String, dynamic> json) {
    return GeoRoutePoint(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class GeoRouteModel {
  const GeoRouteModel({
    required this.provider,
    required this.fallbackUsed,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });

  final String provider;
  final bool fallbackUsed;
  final double distanceMeters;
  final double durationSeconds;
  final List<GeoRoutePoint> points;

  factory GeoRouteModel.fromJson(Map<String, dynamic> json) {
    return GeoRouteModel(
      provider: json['provider']?.toString() ?? 'mock',
      fallbackUsed: json['fallbackUsed'] as bool? ?? false,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
      points: (json['points'] as List<dynamic>? ?? const [])
          .map((item) => GeoRoutePoint.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

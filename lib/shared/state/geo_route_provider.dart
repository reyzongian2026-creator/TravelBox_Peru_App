import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/geo_route.dart';

final geoRouteProvider = FutureProvider.autoDispose
    .family<GeoRouteModel, GeoRouteRequest>((ref, request) async {
      final dio = ref.read(dioProvider);
      final response = await dio.get<Map<String, dynamic>>(
        '/geo/route',
        queryParameters: request.toQueryParameters(),
      );
      return GeoRouteModel.fromJson(response.data ?? <String, dynamic>{});
    });

class GeoRouteRequest {
  const GeoRouteRequest({
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    this.profile = 'driving',
  });

  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final String profile;

  Map<String, dynamic> toQueryParameters() {
    return {
      'originLat': originLat,
      'originLng': originLng,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'profile': profile,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GeoRouteRequest &&
        _sameCoordinate(originLat, other.originLat) &&
        _sameCoordinate(originLng, other.originLng) &&
        _sameCoordinate(destinationLat, other.destinationLat) &&
        _sameCoordinate(destinationLng, other.destinationLng) &&
        profile == other.profile;
  }

  @override
  int get hashCode => Object.hash(
    _hashCoordinate(originLat),
    _hashCoordinate(originLng),
    _hashCoordinate(destinationLat),
    _hashCoordinate(destinationLng),
    profile,
  );

  static bool _sameCoordinate(double left, double right) {
    return _hashCoordinate(left) == _hashCoordinate(right);
  }

  static int _hashCoordinate(double value) {
    return (value * 100000).round();
  }
}

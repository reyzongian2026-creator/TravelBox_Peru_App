import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/warehouse.dart';
import '../../../shared/utils/app_exception.dart';

abstract class GeoRepository {
  Future<List<Warehouse>> findNearbyWarehouses({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int? baggageSize,
  });

  Future<List<Warehouse>> searchWarehousesNearby({
    required double latitude,
    required double longitude,
    required String query,
    double radiusKm = 10,
    int? baggageSize,
  });

  Future<List<GeoSearchSuggestion>> getSearchSuggestions(String query);

  Future<RouteInfo?> calculateRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  });

  Future<List<GeoCity>> getCities();
  Future<List<GeoZone>> getZones({String? cityId});
}

class GeoSearchSuggestion {
  final String type;
  final String id;
  final String name;
  final String? subtitle;
  final GeoCoordinate? location;

  const GeoSearchSuggestion({
    required this.type,
    required this.id,
    required this.name,
    this.subtitle,
    this.location,
  });

  factory GeoSearchSuggestion.fromJson(Map<String, dynamic> json) {
    return GeoSearchSuggestion(
      type: json['type']?.toString() ?? 'unknown',
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      location: json['location'] != null
          ? GeoCoordinate.fromJson(json['location'] as Map<String, dynamic>)
          : null,
    );
  }
}

class GeoCity {
  final String id;
  final String name;
  final String? country;
  final GeoCoordinate? center;

  const GeoCity({
    required this.id,
    required this.name,
    this.country,
    this.center,
  });

  factory GeoCity.fromJson(Map<String, dynamic> json) {
    return GeoCity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      country: json['country']?.toString(),
      center: json['center'] != null
          ? GeoCoordinate.fromJson(json['center'] as Map<String, dynamic>)
          : null,
    );
  }
}

class GeoZone {
  final String id;
  final String name;
  final String? cityId;
  final GeoCoordinate? center;
  final String? type;

  const GeoZone({
    required this.id,
    required this.name,
    this.cityId,
    this.center,
    this.type,
  });

  factory GeoZone.fromJson(Map<String, dynamic> json) {
    return GeoZone(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      cityId: json['cityId']?.toString(),
      center: json['center'] != null
          ? GeoCoordinate.fromJson(json['center'] as Map<String, dynamic>)
          : null,
      type: json['type']?.toString(),
    );
  }
}

class GeoCoordinate {
  final double latitude;
  final double longitude;

  const GeoCoordinate({
    required this.latitude,
    required this.longitude,
  });

  factory GeoCoordinate.fromJson(Map<String, dynamic> json) {
    return GeoCoordinate(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };
}

class RouteInfo {
  final double distanceKm;
  final int durationMinutes;
  final List<GeoCoordinate> polyline;
  final String? encodedPolyline;

  const RouteInfo({
    required this.distanceKm,
    required this.durationMinutes,
    this.polyline = const [],
    this.encodedPolyline,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    return RouteInfo(
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 
                  (json['distance'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 
                      (json['duration'] as num?)?.toInt() ?? 0,
      polyline: (json['polyline'] as List<dynamic>?)
              ?.map((p) => GeoCoordinate.fromJson(p as Map<String, dynamic>))
              .toList() ?? [],
      encodedPolyline: json['encodedPolyline']?.toString(),
    );
  }
}

final geoRepositoryProvider = Provider<GeoRepository>((ref) {
  return GeoRepositoryImpl(dio: ref.watch(dioProvider));
});

class GeoRepositoryImpl implements GeoRepository {
  final Dio _dio;

  GeoRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<List<Warehouse>> findNearbyWarehouses({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int? baggageSize,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/geo/warehouses/nearby',
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'radius': radiusKm,
          'baggageSize': ?baggageSize,
        },
      );

      final data = response.data;
      if (data == null) return [];

      final itemsRaw = data['warehouses'] ?? data['items'] ?? data['data'] ?? data as List<dynamic>;
      return (itemsRaw as List)
          .map((item) => Warehouse.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<Warehouse>> searchWarehousesNearby({
    required double latitude,
    required double longitude,
    required String query,
    double radiusKm = 10,
    int? baggageSize,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/geo/warehouses/search',
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'query': query,
          'radius': radiusKm,
          'baggageSize': ?baggageSize,
        },
      );

      final data = response.data;
      if (data == null) return [];

      final itemsRaw = data['warehouses'] ?? data['items'] ?? data['data'] ?? data as List<dynamic>;
      return (itemsRaw as List)
          .map((item) => Warehouse.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<GeoSearchSuggestion>> getSearchSuggestions(String query) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/geo/search',
        queryParameters: {
          'query': query,
        },
      );

      final data = response.data;
      if (data == null) return [];

      final itemsRaw = data['suggestions'] ?? data['items'] ?? data['data'] ?? data as List<dynamic>;
      return (itemsRaw as List)
          .map((item) => GeoSearchSuggestion.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<RouteInfo?> calculateRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/geo/route',
        queryParameters: {
          'originLat': originLat,
          'originLng': originLng,
          'destLat': destLat,
          'destLng': destLng,
        },
      );

      final data = response.data;
      if (data == null) return null;

      return RouteInfo.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<GeoCity>> getCities() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/geo/cities',
      );
      final data = response.data;
      if (data == null) return [];
      return data.map((item) => GeoCity.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<GeoZone>> getZones({String? cityId}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/geo/zones',
        queryParameters: {
          'cityId': ?cityId,
        },
      );
      final data = response.data;
      if (data == null) return [];
      return data.map((item) => GeoZone.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

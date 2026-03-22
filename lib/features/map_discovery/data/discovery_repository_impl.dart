import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/warehouse.dart';
import '../../../shared/services/demo_data.dart';
import '../../../shared/utils/app_exception.dart';
import '../domain/discovery_repository.dart';

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepositoryImpl(ref.watch(dioProvider));
});

class DiscoveryRepositoryImpl implements DiscoveryRepository {
  DiscoveryRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<Warehouse>> searchWarehouses({
    String? query,
    double? latitude,
    double? longitude,
    String? baggageSize,
  }) async {
    try {
      final response = await _searchWithBackend(
        query: query,
        baggageSize: baggageSize,
      );
      final items = (response.data ?? [])
          .map((item) => Warehouse.fromJson(item as Map<String, dynamic>))
          .toList();
      if (latitude != null && longitude != null) {
        items.sort(
          (left, right) =>
              Geolocator.distanceBetween(
                latitude,
                longitude,
                left.latitude,
                left.longitude,
              ).compareTo(
                Geolocator.distanceBetween(
                  latitude,
                  longitude,
                  right.latitude,
                  right.longitude,
                ),
              ),
        );
      }
      return items;
    } catch (error) {
      if (!AppEnv.useMockFallback) {
        if (error is DioException) {
          throw AppException.fromDioError(error);
        }
        throw AppException.fromError(error);
      }
      final q = (query ?? '').trim().toLowerCase();
      final items = q.isEmpty
          ? [...DemoData.warehouses]
          : DemoData.warehouses
                .where(
                  (item) =>
                      item.name.toLowerCase().contains(q) ||
                      item.city.toLowerCase().contains(q) ||
                      item.district.toLowerCase().contains(q),
                )
                .toList();
      if (latitude != null && longitude != null) {
        items.sort(
          (left, right) =>
              Geolocator.distanceBetween(
                latitude,
                longitude,
                left.latitude,
                left.longitude,
              ).compareTo(
                Geolocator.distanceBetween(
                  latitude,
                  longitude,
                  right.latitude,
                  right.longitude,
                ),
              ),
        );
      }
      return items;
    }
  }

  Future<Response<List<dynamic>>> _searchWithBackend({
    String? query,
    String? baggageSize,
  }) async {
    try {
      return await _dio.get<List<dynamic>>(
        '/warehouses/search',
        queryParameters: {
          if (query?.isNotEmpty == true) 'query': query,
          if (baggageSize?.isNotEmpty == true) 'baggageSize': baggageSize,
        },
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode ?? 0;
      if (status != 404 && status != 405) {
        throw AppException.fromDioError(error);
      }
      return _dio.get<List<dynamic>>(
        '/geo/warehouses/search',
        queryParameters: {
          if (query?.isNotEmpty == true) 'query': query,
          if (baggageSize?.isNotEmpty == true) 'baggageSize': baggageSize,
        },
      );
    }
  }

  @override
  Future<Warehouse?> getWarehouseById(String warehouseId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/warehouses/$warehouseId',
      );
      final data = response.data;
      if (data == null) return null;
      return Warehouse.fromJson(data);
    } catch (error) {
      if (!AppEnv.useMockFallback) {
        if (error is DioException) {
          throw AppException.fromDioError(error);
        }
        throw AppException.fromError(error);
      }
      return DemoData.findWarehouse(warehouseId);
    }
  }

  @override
  Future<String?> getWarehouseImage(String warehouseId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/warehouses/$warehouseId/image',
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );
      final bytes = response.data as List<int>;
      final base64 = base64Encode(bytes);
      return 'data:image/png;base64,$base64';
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
  Future<List<Warehouse>> findNearbyWarehouses({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    String? baggageSize,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/warehouses/nearby',
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'radius': radiusKm,
          if (baggageSize?.isNotEmpty == true) 'baggageSize': baggageSize,
        },
      );
      final data = response.data;
      if (data == null) return [];
      final itemsRaw = data['warehouses'] ?? data['items'] ?? data['data'] ?? [];
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
  Future<WarehouseAvailabilityResult> searchAvailability({
    double? latitude,
    double? longitude,
    DateTime? startAt,
    DateTime? endAt,
    int? baggageCount,
    String? baggageSize,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/warehouses/availability/search',
        queryParameters: {
          'lat': ?latitude,
          'lng': ?longitude,
          if (startAt != null) 'startAt': startAt.toUtc().toIso8601String(),
          if (endAt != null) 'endAt': endAt.toUtc().toIso8601String(),
          'baggageCount': ?baggageCount,
          if (baggageSize?.isNotEmpty == true) 'baggageSize': baggageSize,
        },
      );
      final data = response.data;
      if (data == null) {
        return const WarehouseAvailabilityResult(
          hasAvailability: false,
          warehouses: [],
          totalCount: 0,
        );
      }
      final itemsRaw = data['warehouses'] ?? data['items'] ?? data['data'] ?? [];
      final warehouses = (itemsRaw as List)
          .map((item) => Warehouse.fromJson(item as Map<String, dynamic>))
          .toList();
      return WarehouseAvailabilityResult(
        hasAvailability: data['hasAvailability'] as bool? ?? warehouses.isNotEmpty,
        warehouses: warehouses,
        totalCount: data['totalCount'] as int? ?? warehouses.length,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const WarehouseAvailabilityResult(
          hasAvailability: false,
          warehouses: [],
          totalCount: 0,
        );
      }
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

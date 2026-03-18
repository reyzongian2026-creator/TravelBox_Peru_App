import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/warehouse.dart';
import '../../../shared/services/demo_data.dart';
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
    } catch (_) {
      if (!AppEnv.useMockFallback) rethrow;
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
      if (status != 404 && status != 405) rethrow;
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
    } catch (_) {
      if (!AppEnv.useMockFallback) rethrow;
      return DemoData.findWarehouse(warehouseId);
    }
  }
}


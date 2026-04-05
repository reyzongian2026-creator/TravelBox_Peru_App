import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_error.dart';

class FavoriteWarehouse {
  final int id;
  final int warehouseId;
  final String warehouseName;
  final String warehouseAddress;
  final String cityName;

  const FavoriteWarehouse({
    required this.id,
    required this.warehouseId,
    required this.warehouseName,
    required this.warehouseAddress,
    required this.cityName,
  });

  factory FavoriteWarehouse.fromJson(Map<String, dynamic> json) {
    return FavoriteWarehouse(
      id: json['id'] as int,
      warehouseId: json['warehouseId'] as int,
      warehouseName: json['warehouseName'] as String? ?? '',
      warehouseAddress: json['warehouseAddress'] as String? ?? '',
      cityName: json['cityName'] as String? ?? '',
    );
  }
}

abstract class FavoritesRepository {
  Future<List<FavoriteWarehouse>> list();
  Future<void> add(int warehouseId);
  Future<void> remove(int warehouseId);
  Future<bool> isFavorite(int warehouseId);
}

class FavoritesRepositoryImpl implements FavoritesRepository {
  final Dio _dio;
  FavoritesRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<List<FavoriteWarehouse>> list() async {
    try {
      final resp = await _dio.get<List<dynamic>>('/favorites');
      return (resp.data ?? [])
          .map((e) => FavoriteWarehouse.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  @override
  Future<void> add(int warehouseId) async {
    try {
      await _dio.post('/favorites/$warehouseId');
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  @override
  Future<void> remove(int warehouseId) async {
    try {
      await _dio.delete('/favorites/$warehouseId');
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  @override
  Future<bool> isFavorite(int warehouseId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/favorites/$warehouseId/check');
      return resp.data?['isFavorite'] == true;
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepositoryImpl(dio: ref.watch(dioProvider)),
);

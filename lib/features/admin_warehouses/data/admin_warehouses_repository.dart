import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class AdminWarehousesRepository {
  Future<List<Warehouse>> getWarehouses();
  Future<PagedResult<Warehouse>> getWarehousesPage({
    int page = 0,
    int size = 20,
    String? search,
    String? city,
    bool? active,
  });
  Future<WarehouseRegistry> getWarehouseRegistry();
  Future<Warehouse> createWarehouse(CreateWarehouseRequest request);
  Future<Warehouse> updateWarehouse(int warehouseId, UpdateWarehouseRequest request);
  Future<String> uploadWarehousePhoto(int warehouseId, String filePath);
  Future<void> deleteWarehouse(int warehouseId);
}

class CreateWarehouseRequest {
  final String name;
  final String address;
  final String city;
  final String country;
  final double latitude;
  final double longitude;
  final String? description;
  final List<OpeningHours>? openingHours;
  final Map<String, dynamic>? pricing;
  final List<String>? amenities;
  final bool active;

  CreateWarehouseRequest({
    required this.name,
    required this.address,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.description,
    this.openingHours,
    this.pricing,
    this.amenities,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'city': city,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        if (description != null) 'description': description,
        if (openingHours != null) 'openingHours': openingHours!.map((e) => e.toJson()).toList(),
        if (pricing != null) 'pricing': pricing,
        if (amenities != null) 'amenities': amenities,
        'active': active,
      };
}

class UpdateWarehouseRequest {
  final String? name;
  final String? address;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? description;
  final List<OpeningHours>? openingHours;
  final Map<String, dynamic>? pricing;
  final List<String>? amenities;
  final bool? active;

  UpdateWarehouseRequest({
    this.name,
    this.address,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.description,
    this.openingHours,
    this.pricing,
    this.amenities,
    this.active,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (description != null) 'description': description,
        if (openingHours != null) 'openingHours': openingHours!.map((e) => e.toJson()).toList(),
        if (pricing != null) 'pricing': pricing,
        if (amenities != null) 'amenities': amenities,
        if (active != null) 'active': active,
      };
}

class OpeningHours {
  final String dayOfWeek;
  final String openTime;
  final String closeTime;
  final bool closed;

  OpeningHours({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    this.closed = false,
  });

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'openTime': openTime,
        'closeTime': closeTime,
        'closed': closed,
      };

  factory OpeningHours.fromJson(Map<String, dynamic> json) {
    return OpeningHours(
      dayOfWeek: json['dayOfWeek']?.toString() ?? '',
      openTime: json['openTime']?.toString() ?? '',
      closeTime: json['closeTime']?.toString() ?? '',
      closed: (json['closed'] as bool?) ?? false,
    );
  }
}

class Warehouse {
  final int id;
  final String name;
  final String address;
  final String city;
  final String country;
  final double latitude;
  final double longitude;
  final String? description;
  final List<OpeningHours>? openingHours;
  final Map<String, dynamic>? pricing;
  final List<String>? amenities;
  final bool active;
  final String? imageUrl;
  final double? rating;
  final int? totalRatings;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Warehouse({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.description,
    this.openingHours,
    this.pricing,
    this.amenities,
    required this.active,
    this.imageUrl,
    this.rating,
    this.totalRatings,
    required this.createdAt,
    this.updatedAt,
  });

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: (json['id'] as int?) ?? 0,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      country: json['country']?.toString() ?? 'Peru',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString(),
      openingHours: (json['openingHours'] as List<dynamic>?)
          ?.map((e) => OpeningHours.fromJson(e as Map<String, dynamic>))
          .toList(),
      pricing: json['pricing'] as Map<String, dynamic>?,
      amenities: (json['amenities'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      active: (json['active'] as bool?) ?? true,
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      totalRatings: json['totalRatings'] as int?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }
}

class WarehouseRegistry {
  final List<String> cities;
  final List<String> countries;
  final int totalWarehouses;
  final int activeWarehouses;
  final int inactiveWarehouses;
  final Map<String, int> warehousesByCity;

  WarehouseRegistry({
    required this.cities,
    required this.countries,
    required this.totalWarehouses,
    required this.activeWarehouses,
    required this.inactiveWarehouses,
    required this.warehousesByCity,
  });

  factory WarehouseRegistry.fromJson(Map<String, dynamic> json) {
    final citiesData = json['cities'] as List<dynamic>?;
    final countriesData = json['countries'] as List<dynamic>?;
    final byCityData = json['warehousesByCity'] as Map<String, dynamic>? ?? json['byCity'] as Map<String, dynamic>?;
    final cityMap = <String, int>{};
    if (byCityData != null) {
      byCityData.forEach((key, value) {
        cityMap[key] = (value as int?) ?? 0;
      });
    }
    return WarehouseRegistry(
      cities: citiesData?.map((e) => e.toString()).toList() ?? [],
      countries: countriesData?.map((e) => e.toString()).toList() ?? ['Peru'],
      totalWarehouses: (json['totalWarehouses'] as int?) ?? json['total'] as int? ?? 0,
      activeWarehouses: (json['activeWarehouses'] as int?) ?? json['active'] as int? ?? 0,
      inactiveWarehouses: (json['inactiveWarehouses'] as int?) ?? json['inactive'] as int? ?? 0,
      warehousesByCity: cityMap,
    );
  }
}

class PagedResult<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  PagedResult({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final contentList =
        json['items'] as List<dynamic>? ??
        json['content'] as List<dynamic>? ??
        [];
    final hasNext = json['hasNext'] as bool? ?? false;
    return PagedResult(
      content: contentList.map((e) => fromJsonT(e as Map<String, dynamic>)).toList(),
      page: (json['page'] as int?) ?? 0,
      size: (json['size'] as int?) ?? json['pageSize'] as int? ?? 20,
      totalElements: (json['totalElements'] as int?) ?? json['total'] as int? ?? 0,
      totalPages: (json['totalPages'] as int?) ?? json['pages'] as int? ?? 0,
      last: (json['last'] as bool?) ?? !hasNext,
    );
  }
}

final adminWarehousesRepositoryProvider = Provider<AdminWarehousesRepository>((ref) {
  return AdminWarehousesRepositoryImpl(dio: ref.watch(dioProvider));
});

class AdminWarehousesRepositoryImpl implements AdminWarehousesRepository {
  final Dio _dio;

  AdminWarehousesRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<List<Warehouse>> getWarehouses() async {
    try {
      final response = await _dio.get<List<dynamic>>('/admin/warehouses');
      final data = response.data;
      if (data == null) return [];
      return data.map((e) => Warehouse.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<PagedResult<Warehouse>> getWarehousesPage({
    int page = 0,
    int size = 20,
    String? search,
    String? city,
    bool? active,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/warehouses/page',
        queryParameters: {
          'page': page,
          'size': size,
          if (search != null && search.isNotEmpty) 'search': search,
          if (city != null && city.isNotEmpty) 'city': city,
          'active': ?active,
        },
      );
      final data = response.data;
      if (data == null) {
        return PagedResult(
          content: [],
          page: page,
          size: size,
          totalElements: 0,
          totalPages: 0,
          last: true,
        );
      }
      return PagedResult.fromJson(data, Warehouse.fromJson);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<WarehouseRegistry> getWarehouseRegistry() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/admin/warehouses/registry');
      final data = response.data;
      if (data == null) {
        return WarehouseRegistry(
          cities: [],
          countries: ['Peru'],
          totalWarehouses: 0,
          activeWarehouses: 0,
          inactiveWarehouses: 0,
          warehousesByCity: {},
        );
      }
      return WarehouseRegistry.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<Warehouse> createWarehouse(CreateWarehouseRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/admin/warehouses',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.errCreateWarehouse, backendMessage: 'Failed to create warehouse');
      }
      return Warehouse.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<Warehouse> updateWarehouse(int warehouseId, UpdateWarehouseRequest request) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/admin/warehouses/$warehouseId',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.errUpdateFailed, backendMessage: 'Failed to update warehouse');
      }
      return Warehouse.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<String> uploadWarehousePhoto(int warehouseId, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/admin/warehouses/$warehouseId/photo',
        data: formData,
      );
      final data = response.data;
      if (data == null || data['url'] == null) {
        throw AppException.withCode(AppErrorCode.errUploadFailed, backendMessage: 'Failed to upload warehouse photo');
      }
      return data['url'].toString();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> deleteWarehouse(int warehouseId) async {
    try {
      await _dio.delete<void>('/admin/warehouses/$warehouseId');
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

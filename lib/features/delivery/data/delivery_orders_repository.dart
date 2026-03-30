import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class DeliveryOrdersRepository {
  Future<DeliveryOrderDetail?> getDeliveryOrderById(String orderId);
  Future<DeliveryTracking> getDeliveryOrderTracking(String orderId);
  Future<List<DeliveryOrderDetail>> getDeliveryOrders({
    String? status,
    int page = 0,
    int size = 20,
  });
  Future<DeliveryTracking> getDeliveryOrderTrackingByReservation(String reservationId);
  Future<void> claimDeliveryOrder(String orderId);
  Future<void> updateDeliveryProgress(String orderId, String status, {String? notes});
}

class DeliveryOrderDetail {
  final String id;
  final String reservationId;
  final String reservationCode;
  final String status;
  final String? assignedCourierId;
  final String? assignedCourierName;
  final String? pickupAddress;
  final String? deliveryAddress;
  final DateTime createdAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DeliveryLocation? currentLocation;
  final List<DeliveryEvent> events;

  const DeliveryOrderDetail({
    required this.id,
    required this.reservationId,
    required this.reservationCode,
    required this.status,
    this.assignedCourierId,
    this.assignedCourierName,
    this.pickupAddress,
    this.deliveryAddress,
    required this.createdAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.currentLocation,
    this.events = const [],
  });

  factory DeliveryOrderDetail.fromJson(Map<String, dynamic> json) {
    return DeliveryOrderDetail(
      id: json['id']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      reservationCode: json['reservationCode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      assignedCourierId: json['assignedCourierId']?.toString(),
      assignedCourierName: json['assignedCourierName']?.toString(),
      pickupAddress: json['pickupAddress']?.toString(),
      deliveryAddress: json['deliveryAddress']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      pickedUpAt: json['pickedUpAt'] != null
          ? DateTime.tryParse(json['pickedUpAt'].toString())
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'].toString())
          : null,
      currentLocation: json['currentLocation'] != null
          ? DeliveryLocation.fromJson(json['currentLocation'] as Map<String, dynamic>)
          : null,
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => DeliveryEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DeliveryLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speed;
  final double? heading;

  const DeliveryLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
    this.heading,
  });

  factory DeliveryLocation.fromJson(Map<String, dynamic> json) {
    return DeliveryLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
    );
  }
}

class DeliveryEvent {
  final String status;
  final String description;
  final DateTime timestamp;
  final String? location;

  const DeliveryEvent({
    required this.status,
    required this.description,
    required this.timestamp,
    this.location,
  });

  factory DeliveryEvent.fromJson(Map<String, dynamic> json) {
    return DeliveryEvent(
      status: json['status']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      location: json['location']?.toString(),
    );
  }
}

class DeliveryTracking {
  final String orderId;
  final String status;
  final String? estimatedArrival;
  final DeliveryLocation? currentLocation;
  final List<DeliveryEvent> events;
  final String? courierName;
  final String? courierPhone;

  const DeliveryTracking({
    required this.orderId,
    required this.status,
    this.estimatedArrival,
    this.currentLocation,
    this.events = const [],
    this.courierName,
    this.courierPhone,
  });

  factory DeliveryTracking.fromJson(Map<String, dynamic> json) {
    return DeliveryTracking(
      orderId: json['orderId']?.toString() ?? json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      estimatedArrival: json['estimatedArrival']?.toString(),
      currentLocation: json['currentLocation'] != null
          ? DeliveryLocation.fromJson(json['currentLocation'] as Map<String, dynamic>)
          : null,
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => DeliveryEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      courierName: json['courierName']?.toString(),
      courierPhone: json['courierPhone']?.toString(),
    );
  }
}

final deliveryOrdersRepositoryProvider = Provider<DeliveryOrdersRepository>((ref) {
  return DeliveryOrdersRepositoryImpl(dio: ref.watch(dioProvider));
});

class DeliveryOrdersRepositoryImpl implements DeliveryOrdersRepository {
  final Dio _dio;

  DeliveryOrdersRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<DeliveryOrderDetail?> getDeliveryOrderById(String orderId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/delivery-orders/$orderId',
      );

      final data = response.data;
      if (data == null) return null;

      return DeliveryOrderDetail.fromJson(data);
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
  Future<DeliveryTracking> getDeliveryOrderTracking(String orderId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/delivery-orders/$orderId/tracking',
      );

      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.errorNotFound, backendMessage: 'Tracking information not found');
      }

      return DeliveryTracking.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<DeliveryOrderDetail>> getDeliveryOrders({
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/delivery-orders',
        queryParameters: {
          'page': page,
          'size': size,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );
      final data = response.data;
      if (data == null) return [];
      return data.map((item) => DeliveryOrderDetail.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<DeliveryTracking> getDeliveryOrderTrackingByReservation(String reservationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/delivery-orders/reservation/$reservationId/tracking',
      );

      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.errorNotFound, backendMessage: 'Tracking information not found');
      }

      return DeliveryTracking.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> claimDeliveryOrder(String orderId) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/delivery-orders/$orderId/claim',
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> updateDeliveryProgress(String orderId, String status, {String? notes}) async {
    try {
      final payload = <String, dynamic>{
        'status': status,
        'notes': notes,
      }..removeWhere((key, value) => value == null);
      await _dio.patch<Map<String, dynamic>>(
        '/delivery-orders/$orderId/progress',
        data: payload,
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

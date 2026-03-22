import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class InventoryRepository {
  Future<CheckinResult> checkin(CheckinRequest request);
  Future<CheckoutResult> checkout(CheckoutRequest request);
  Future<String> uploadEvidence(String incidentId, String filePath, String description);
  Future<List<Evidence>> getEvidences(String reservationId);
  Future<Evidence> createEvidence(EvidenceRequest request);
}

class CheckinRequest {
  final String reservationId;
  final String warehouseId;
  final List<LuggageItem> luggage;
  final String? notes;

  CheckinRequest({
    required this.reservationId,
    required this.warehouseId,
    required this.luggage,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'reservationId': reservationId,
        'warehouseId': warehouseId,
        'luggage': luggage.map((e) => e.toJson()).toList(),
        if (notes != null) 'notes': notes,
      };
}

class CheckoutRequest {
  final String reservationId;
  final String warehouseId;
  final String clientIdentity;
  final List<LuggageItem> luggage;
  final String? notes;

  CheckoutRequest({
    required this.reservationId,
    required this.warehouseId,
    required this.clientIdentity,
    required this.luggage,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'reservationId': reservationId,
        'warehouseId': warehouseId,
        'clientIdentity': clientIdentity,
        'luggage': luggage.map((e) => e.toJson()).toList(),
        if (notes != null) 'notes': notes,
      };
}

class LuggageItem {
  final String tagId;
  final String description;
  final double? weight;
  final double? length;
  final double? width;
  final double? height;
  final String? category;

  LuggageItem({
    required this.tagId,
    required this.description,
    this.weight,
    this.length,
    this.width,
    this.height,
    this.category,
  });

  Map<String, dynamic> toJson() => {
        'tagId': tagId,
        'description': description,
        if (weight != null) 'weight': weight,
        if (length != null) 'length': length,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (category != null) 'category': category,
      };
}

class CheckinResult {
  final String checkinId;
  final String reservationId;
  final String warehouseId;
  final DateTime timestamp;
  final List<LuggageItemResult> luggage;
  final String status;

  CheckinResult({
    required this.checkinId,
    required this.reservationId,
    required this.warehouseId,
    required this.timestamp,
    required this.luggage,
    required this.status,
  });

  factory CheckinResult.fromJson(Map<String, dynamic> json) {
    return CheckinResult(
      checkinId: json['checkinId']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      warehouseId: json['warehouseId']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      luggage: (json['luggage'] as List<dynamic>?)
              ?.map((e) => LuggageItemResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: json['status']?.toString() ?? 'COMPLETED',
    );
  }
}

class CheckoutResult {
  final String checkoutId;
  final String reservationId;
  final String warehouseId;
  final DateTime timestamp;
  final String clientIdentity;
  final List<LuggageItemResult> luggage;
  final String status;

  CheckoutResult({
    required this.checkoutId,
    required this.reservationId,
    required this.warehouseId,
    required this.timestamp,
    required this.clientIdentity,
    required this.luggage,
    required this.status,
  });

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    return CheckoutResult(
      checkoutId: json['checkoutId']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      warehouseId: json['warehouseId']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      clientIdentity: json['clientIdentity']?.toString() ?? '',
      luggage: (json['luggage'] as List<dynamic>?)
              ?.map((e) => LuggageItemResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: json['status']?.toString() ?? 'COMPLETED',
    );
  }
}

class LuggageItemResult {
  final String tagId;
  final String description;
  final String status;

  LuggageItemResult({
    required this.tagId,
    required this.description,
    required this.status,
  });

  factory LuggageItemResult.fromJson(Map<String, dynamic> json) {
    return LuggageItemResult(
      tagId: json['tagId']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OK',
    );
  }
}

class Evidence {
  final String id;
  final String type;
  final String url;
  final String? description;
  final DateTime uploadedAt;
  final String? uploadedBy;

  Evidence({
    required this.id,
    required this.type,
    required this.url,
    this.description,
    required this.uploadedAt,
    this.uploadedBy,
  });

  factory Evidence.fromJson(Map<String, dynamic> json) {
    return Evidence(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      description: json['description']?.toString(),
      uploadedAt: DateTime.tryParse(json['uploadedAt']?.toString() ?? '') ?? DateTime.now(),
      uploadedBy: json['uploadedBy']?.toString(),
    );
  }
}

class EvidenceRequest {
  final String reservationId;
  final String type;
  final String? description;
  final String? filePath;

  EvidenceRequest({
    required this.reservationId,
    required this.type,
    this.description,
    this.filePath,
  });

  Map<String, dynamic> toJson() => {
        'reservationId': reservationId,
        'type': type,
        if (description != null) 'description': description,
      };
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl(dio: ref.watch(dioProvider));
});

class InventoryRepositoryImpl implements InventoryRepository {
  final Dio _dio;

  InventoryRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<CheckinResult> checkin(CheckinRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/inventory/checkin',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.err_checkin_failed, backendMessage: 'Failed to checkin');
      }
      return CheckinResult.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<CheckoutResult> checkout(CheckoutRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/inventory/checkout',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.err_checkout_failed, backendMessage: 'Failed to checkout');
      }
      return CheckoutResult.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<String> uploadEvidence(String incidentId, String filePath, String description) async {
    try {
      final formData = FormData.fromMap({
        'incidentId': incidentId,
        'description': description,
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/inventory/evidences/upload',
        data: formData,
      );
      final data = response.data;
      if (data == null || data['url'] == null) {
        throw AppException.withCode(AppErrorCode.err_upload_failed, backendMessage: 'Failed to upload evidence');
      }
      return data['url'].toString();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<Evidence>> getEvidences(String reservationId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/inventory/evidences',
        queryParameters: {'reservationId': reservationId},
      );
      final data = response.data;
      if (data == null) return [];
      return data.map((e) => Evidence.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<Evidence> createEvidence(EvidenceRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/inventory/evidences',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.err_upload_failed, backendMessage: 'Failed to create evidence');
      }
      return Evidence.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

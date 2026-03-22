import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class OpsQrHandoffRepository {
  Future<ScanResult> scan(String qrCode);
  Future<ReservationCase> getReservationCase(String reservationId);
  Future<TagResult> tagLuggage(String reservationId, List<String> tagIds);
  Future<void> markStored(String reservationId);
  Future<void> markStoredWithPhotos(String reservationId, List<String> photoPaths);
  Future<void> markReadyForPickup(String reservationId);
  Future<PickupConfirmation> confirmPickup(String reservationId, String pin);
  Future<void> setDeliveryIdentityValidated(String reservationId, bool validated);
  Future<void> setDeliveryLuggageMatched(String reservationId, bool matched);
  Future<void> requestDeliveryApproval(String reservationId);
  Future<List<ApprovalItem>> getApprovals();
  Future<void> approveHandoff(String approvalId);
  Future<void> rejectHandoff(String approvalId, String reason);
  Future<void> completeDelivery(String reservationId);
}

class ScanResult {
  final String type;
  final String reservationId;
  final String reservationCode;
  final String status;
  final Map<String, dynamic> data;

  ScanResult({
    required this.type,
    required this.reservationId,
    required this.reservationCode,
    required this.status,
    required this.data,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      type: json['type']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      reservationCode: json['reservationCode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }
}

class ReservationCase {
  final String reservationId;
  final String reservationCode;
  final String status;
  final ClientInfo client;
  final List<LuggageInfo> luggage;
  final List<CaseEvent> events;
  final DeliveryInfo? delivery;
  final bool readyForPickup;
  final bool identityValidated;
  final bool luggageMatched;

  ReservationCase({
    required this.reservationId,
    required this.reservationCode,
    required this.status,
    required this.client,
    required this.luggage,
    required this.events,
    this.delivery,
    required this.readyForPickup,
    required this.identityValidated,
    required this.luggageMatched,
  });

  factory ReservationCase.fromJson(Map<String, dynamic> json) {
    return ReservationCase(
      reservationId: json['reservationId']?.toString() ?? '',
      reservationCode: json['reservationCode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      client: ClientInfo.fromJson(json['client'] as Map<String, dynamic>? ?? {}),
      luggage: (json['luggage'] as List<dynamic>?)
              ?.map((e) => LuggageInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => CaseEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      delivery: json['delivery'] != null
          ? DeliveryInfo.fromJson(json['delivery'] as Map<String, dynamic>)
          : null,
      readyForPickup: (json['readyForPickup'] as bool?) ?? false,
      identityValidated: (json['identityValidated'] as bool?) ?? false,
      luggageMatched: (json['luggageMatched'] as bool?) ?? false,
    );
  }
}

class ClientInfo {
  final String id;
  final String name;
  final String email;
  final String phone;

  ClientInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory ClientInfo.fromJson(Map<String, dynamic> json) {
    return ClientInfo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}

class LuggageInfo {
  final String tagId;
  final String description;
  final String status;
  final double? weight;

  LuggageInfo({
    required this.tagId,
    required this.description,
    required this.status,
    this.weight,
  });

  factory LuggageInfo.fromJson(Map<String, dynamic> json) {
    return LuggageInfo(
      tagId: json['tagId']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      weight: (json['weight'] as num?)?.toDouble(),
    );
  }
}

class CaseEvent {
  final String type;
  final String description;
  final DateTime timestamp;
  final String? performedBy;

  CaseEvent({
    required this.type,
    required this.description,
    required this.timestamp,
    this.performedBy,
  });

  factory CaseEvent.fromJson(Map<String, dynamic> json) {
    return CaseEvent(
      type: json['type']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      performedBy: json['performedBy']?.toString(),
    );
  }
}

class DeliveryInfo {
  final String? courierId;
  final String? courierName;
  final String status;
  final DateTime? requestedAt;
  final DateTime? approvedAt;

  DeliveryInfo({
    this.courierId,
    this.courierName,
    required this.status,
    this.requestedAt,
    this.approvedAt,
  });

  factory DeliveryInfo.fromJson(Map<String, dynamic> json) {
    return DeliveryInfo(
      courierId: json['courierId']?.toString(),
      courierName: json['courierName']?.toString(),
      status: json['status']?.toString() ?? '',
      requestedAt: json['requestedAt'] != null ? DateTime.tryParse(json['requestedAt'].toString()) : null,
      approvedAt: json['approvedAt'] != null ? DateTime.tryParse(json['approvedAt'].toString()) : null,
    );
  }
}

class TagResult {
  final List<String> taggedIds;
  final int totalTagged;

  TagResult({
    required this.taggedIds,
    required this.totalTagged,
  });

  factory TagResult.fromJson(Map<String, dynamic> json) {
    return TagResult(
      taggedIds: (json['taggedIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      totalTagged: (json['totalTagged'] as int?) ?? 0,
    );
  }
}

class PickupConfirmation {
  final bool success;
  final String? message;
  final DateTime? confirmedAt;

  PickupConfirmation({
    required this.success,
    this.message,
    this.confirmedAt,
  });

  factory PickupConfirmation.fromJson(Map<String, dynamic> json) {
    return PickupConfirmation(
      success: (json['success'] as bool?) ?? false,
      message: json['message']?.toString(),
      confirmedAt: json['confirmedAt'] != null ? DateTime.tryParse(json['confirmedAt'].toString()) : null,
    );
  }
}

class ApprovalItem {
  final String approvalId;
  final String reservationId;
  final String reservationCode;
  final String type;
  final String status;
  final ClientInfo client;
  final DateTime requestedAt;
  final String? requestedBy;

  ApprovalItem({
    required this.approvalId,
    required this.reservationId,
    required this.reservationCode,
    required this.type,
    required this.status,
    required this.client,
    required this.requestedAt,
    this.requestedBy,
  });

  factory ApprovalItem.fromJson(Map<String, dynamic> json) {
    return ApprovalItem(
      approvalId: json['approvalId']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      reservationCode: json['reservationCode']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      client: ClientInfo.fromJson(json['client'] as Map<String, dynamic>? ?? {}),
      requestedAt: DateTime.tryParse(json['requestedAt']?.toString() ?? '') ?? DateTime.now(),
      requestedBy: json['requestedBy']?.toString(),
    );
  }
}

final opsQrHandoffRepositoryProvider = Provider<OpsQrHandoffRepository>((ref) {
  return OpsQrHandoffRepositoryImpl(dio: ref.watch(dioProvider));
});

class OpsQrHandoffRepositoryImpl implements OpsQrHandoffRepository {
  final Dio _dio;

  OpsQrHandoffRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<ScanResult> scan(String qrCode) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ops/qr-handoff/scan',
        data: {'qrCode': qrCode},
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.err_no_response, backendMessage: 'Scan failed');
      }
      return ScanResult.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<ReservationCase> getReservationCase(String reservationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/ops/qr-handoff/reservations/$reservationId',
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.error_not_found, backendMessage: 'Reservation case not found');
      }
      return ReservationCase.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<TagResult> tagLuggage(String reservationId, List<String> tagIds) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ops/qr-handoff/reservations/$reservationId/tag',
        data: {'tagIds': tagIds},
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.err_update_failed, backendMessage: 'Tagging failed');
      }
      return TagResult.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> markStored(String reservationId) async {
    try {
      await _dio.post<void>('/ops/qr-handoff/reservations/$reservationId/store');
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> markStoredWithPhotos(String reservationId, List<String> photoPaths) async {
    try {
      final formData = FormData.fromMap({
        'photos': photoPaths.map((path) => MultipartFile.fromFile(path)).toList(),
      });
      await _dio.post<void>(
        '/ops/qr-handoff/reservations/$reservationId/store-with-photos',
        data: formData,
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> markReadyForPickup(String reservationId) async {
    try {
      await _dio.post<void>('/ops/qr-handoff/reservations/$reservationId/ready-for-pickup');
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<PickupConfirmation> confirmPickup(String reservationId, String pin) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ops/qr-handoff/reservations/$reservationId/pickup/confirm',
        data: {'pin': pin},
      );
      final data = response.data;
      if (data == null) {
        return PickupConfirmation(success: false, message: 'Confirmation failed');
      }
      return PickupConfirmation.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> setDeliveryIdentityValidated(String reservationId, bool validated) async {
    try {
      await _dio.patch<void>(
        '/ops/qr-handoff/reservations/$reservationId/delivery/identity',
        data: {'validated': validated},
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> setDeliveryLuggageMatched(String reservationId, bool matched) async {
    try {
      await _dio.patch<void>(
        '/ops/qr-handoff/reservations/$reservationId/delivery/luggage',
        data: {'matched': matched},
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> requestDeliveryApproval(String reservationId) async {
    try {
      await _dio.post<void>('/ops/qr-handoff/reservations/$reservationId/delivery/request-approval');
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<ApprovalItem>> getApprovals() async {
    try {
      final response = await _dio.get<List<dynamic>>('/ops/qr-handoff/approvals');
      final data = response.data;
      if (data == null) return [];
      return data.map((e) => ApprovalItem.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> approveHandoff(String approvalId) async {
    try {
      await _dio.post<void>('/ops/qr-handoff/approvals/$approvalId/approve');
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> rejectHandoff(String approvalId, String reason) async {
    try {
      await _dio.post<void>(
        '/ops/qr-handoff/approvals/$approvalId/reject',
        data: {'reason': reason},
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> completeDelivery(String reservationId) async {
    try {
      await _dio.post<void>('/ops/qr-handoff/reservations/$reservationId/delivery/complete');
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

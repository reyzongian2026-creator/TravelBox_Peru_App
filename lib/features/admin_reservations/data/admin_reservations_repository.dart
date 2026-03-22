import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/utils/app_exception.dart';

abstract class AdminReservationsRepository {
  Future<BulkUpdateResult> bulkUpdateStatus(Set<int> reservationIds, String status);
  Future<String> exportReservations({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? format,
  });
  Future<List<Reservation>> getAllReservations({
    ReservationStatus? status,
    String? query,
    int page = 0,
    int size = 50,
  });
}

class BulkUpdateResult {
  final int processed;
  final int succeeded;
  final int failed;
  final List<int> failedIds;
  final String message;

  BulkUpdateResult({
    required this.processed,
    required this.succeeded,
    required this.failed,
    required this.failedIds,
    required this.message,
  });

  factory BulkUpdateResult.fromJson(Map<String, dynamic> json) {
    return BulkUpdateResult(
      processed: (json['processed'] as int?) ?? 0,
      succeeded: (json['succeeded'] as int?) ?? 0,
      failed: (json['failed'] as int?) ?? 0,
      failedIds: (json['failedIds'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      message: json['message']?.toString() ?? '',
    );
  }
}

final adminReservationsRepositoryProvider = Provider<AdminReservationsRepository>((ref) {
  return AdminReservationsRepositoryImpl(dio: ref.watch(dioProvider));
});

class AdminReservationsRepositoryImpl implements AdminReservationsRepository {
  final Dio _dio;

  AdminReservationsRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<BulkUpdateResult> bulkUpdateStatus(Set<int> reservationIds, String status) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/admin/reservations/bulk/status',
        data: {
          'ids': reservationIds.toList(),
          'status': status,
        },
      );
      final data = response.data;
      if (data == null) {
        return BulkUpdateResult(
          processed: 0,
          succeeded: 0,
          failed: 0,
          failedIds: [],
          message: 'No response from server',
        );
      }
      return BulkUpdateResult.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<String> exportReservations({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? format,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/reservations/export',
        queryParameters: {
          if (startDate != null) 'startDate': '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
          if (endDate != null) 'endDate': '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
          if (status != null && status.isNotEmpty) 'status': status,
          'format': format ?? 'CSV',
        },
      );
      final data = response.data;
      if (data == null || data['url'] == null) {
        throw AppException.withCode(AppErrorCode.err_export_failed, backendMessage: 'Export failed');
      }
      return data['url'].toString();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<Reservation>> getAllReservations({
    ReservationStatus? status,
    String? query,
    int page = 0,
    int size = 50,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/reservations',
        queryParameters: {
          'page': page,
          'size': size,
          if (status != null) 'status': status.code,
          if (query != null && query.isNotEmpty) 'query': query,
        },
      );
      final data = response.data;
      if (data == null) return [];
      final itemsRaw = data['items'] ?? data['content'] ?? data['data'] ?? data['reservations'] ?? [];
      return (itemsRaw as List)
          .map((item) => Reservation.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

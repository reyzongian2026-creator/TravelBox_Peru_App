import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class AdminUsersRepository {
  Future<void> updateUserRoles({
    required String userId,
    required List<String> roles,
  });
  
  Future<BulkOperationResult> bulkDelete(Set<int> ids);
  
  Future<BulkOperationResult> bulkUpdateActive(Set<int> ids, bool active);
  
  Future<BulkOperationResult> bulkUpdateRoles(Set<int> ids, List<String> roles);
  
  String getExportUrl();
}

final adminUsersRepositoryProvider = Provider<AdminUsersRepository>((ref) {
  return AdminUsersRepositoryImpl(dio: ref.watch(dioProvider));
});

class BulkOperationResult {
  final int processed;
  final int succeeded;
  final int failed;
  final String message;
  
  BulkOperationResult({
    required this.processed,
    required this.succeeded,
    required this.failed,
    required this.message,
  });
  
  factory BulkOperationResult.fromJson(Map<String, dynamic> json) {
    return BulkOperationResult(
      processed: json['processed'] as int? ?? 0,
      succeeded: json['succeeded'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}

class AdminUsersRepositoryImpl implements AdminUsersRepository {
  final Dio _dio;

  AdminUsersRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<void> updateUserRoles({
    required String userId,
    required List<String> roles,
  }) async {
    try {
      await _dio.patch<void>(
        '/admin/users/$userId/roles',
        data: {
          'roles': roles,
        },
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
  
  @override
  Future<BulkOperationResult> bulkDelete(Set<int> ids) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/admin/users/bulk/delete',
        data: {'ids': ids.toList()},
      );
      return BulkOperationResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
  
  @override
  Future<BulkOperationResult> bulkUpdateActive(Set<int> ids, bool active) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/admin/users/bulk/active',
        data: {'ids': ids.toList(), 'active': active},
      );
      return BulkOperationResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
  
  @override
  Future<BulkOperationResult> bulkUpdateRoles(Set<int> ids, List<String> roles) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/admin/users/bulk/roles',
        data: {'ids': ids.toList(), 'roles': roles},
      );
      return BulkOperationResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
  
  @override
  String getExportUrl() {
    return '/admin/users/export';
  }
}

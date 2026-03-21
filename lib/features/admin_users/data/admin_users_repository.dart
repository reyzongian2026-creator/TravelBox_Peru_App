import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class AdminUsersRepository {
  Future<void> updateUserRoles({
    required String userId,
    required List<String> roles,
  });
}

final adminUsersRepositoryProvider = Provider<AdminUsersRepository>((ref) {
  return AdminUsersRepositoryImpl(dio: ref.watch(dioProvider));
});

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
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';
import '../domain/sensitive_data_repository.dart';

final sensitiveDataRepositoryProvider = Provider<SensitiveDataRepository>((ref) {
  return SensitiveDataRepositoryImpl(dio: ref.watch(dioProvider));
});

class SensitiveDataRepositoryImpl implements SensitiveDataRepository {
  final Dio _dio;

  SensitiveDataRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<DecryptedData> decryptData(String encryptedData) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sensitive-data/decrypt',
        data: {'encryptedData': encryptedData},
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(
          AppErrorCode.errorNotFound,
          backendMessage: 'No decrypted data returned',
        );
      }
      return DecryptedData(
        type: data['type']?.toString() ?? 'unknown',
        data: data['data'] as Map<String, dynamic>? ?? {},
        expiresAt: data['expiresAt'] != null
            ? DateTime.tryParse(data['expiresAt'].toString())
            : null,
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }
}

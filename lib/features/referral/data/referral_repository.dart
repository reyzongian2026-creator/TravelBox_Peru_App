import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_error.dart';

abstract class ReferralRepository {
  Future<Map<String, dynamic>> getMyReferralCode();
  Future<Map<String, dynamic>> generateReferralCode();
  Future<Map<String, dynamic>> redeemReferralCode(String code);
}

class ReferralRepositoryImpl implements ReferralRepository {
  final Dio _dio;
  ReferralRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<Map<String, dynamic>> getMyReferralCode() async {
    try {
      final resp = await _dio.get('/referrals/my-code');
      return Map<String, dynamic>.from(resp.data as Map);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> generateReferralCode() async {
    try {
      final resp = await _dio.post('/referrals/generate');
      return Map<String, dynamic>.from(resp.data as Map);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> redeemReferralCode(String code) async {
    try {
      final resp = await _dio.post(
        '/referrals/redeem',
        queryParameters: {'code': code},
      );
      return Map<String, dynamic>.from(resp.data as Map);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }
}

final referralRepositoryProvider = Provider<ReferralRepository>(
  (ref) => ReferralRepositoryImpl(dio: ref.watch(dioProvider)),
);

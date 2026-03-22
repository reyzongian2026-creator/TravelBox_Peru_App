import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';
import 'models/photo_model.dart';

abstract class PhotoRepository {
  Future<List<ReservationPhoto>> getReservationPhotos(int reservationId);
  Future<ImageUploadResponse> uploadClientHandoffPhoto(int reservationId, String filePath);
  Future<void> deletePhoto(int reservationId, int photoId);
}

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepositoryImpl(dio: ref.watch(dioProvider));
});

class PhotoRepositoryImpl implements PhotoRepository {
  PhotoRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<ReservationPhoto>> getReservationPhotos(int reservationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reservations/$reservationId',
      );

      final data = response.data;
      if (data == null) {
        return [];
      }

      final operationalDetail = data['operationalDetail'] as Map<String, dynamic>?;
      if (operationalDetail == null) {
        return [];
      }

      final luggagePhotos = operationalDetail['luggagePhotos'] as List<dynamic>?;
      if (luggagePhotos == null) {
        return [];
      }

      return luggagePhotos
          .map((json) => ReservationPhoto.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<ImageUploadResponse> uploadClientHandoffPhoto(
    int reservationId,
    String filePath,
  ) async {
    try {
      final formData = FormData.fromMap({
        'reservationId': reservationId,
        'type': PhotoType.clientHandoff.value,
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/inventory/evidences/upload',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      final data = response.data;
      if (data == null) {
        throw AppException.withCode(
          AppErrorCode.errUploadFailed,
          backendMessage: 'Failed to upload photo',
        );
      }

      return ImageUploadResponse.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> deletePhoto(int reservationId, int photoId) async {
    try {
      await _dio.delete<void>(
        '/inventory/evidences/$photoId',
        queryParameters: {'reservationId': reservationId},
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

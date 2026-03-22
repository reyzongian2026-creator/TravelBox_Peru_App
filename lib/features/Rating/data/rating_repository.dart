import 'package:dio/dio.dart';
import 'package:travelbox_peru_app/core/network/api_client.dart';
import 'package:travelbox_peru_app/features/Rating/data/rating_model.dart';

class RatingRepository {
  final Dio dio;

  RatingRepository({required this.dio});

  Future<RatingModel> createRating({
    required int warehouseId,
    int? reservationId,
    required int stars,
    String? comment,
    String type = 'WAREHOUSE',
  }) async {
    final response = await dio.post(
      '/ratings',
      data: {
        'warehouseId': warehouseId,
        if (reservationId != null) 'reservationId': reservationId,
        'stars': stars,
        if (comment != null) 'comment': comment,
        'type': type,
      },
    );
    return RatingModel.fromJson(response.data);
  }

  Future<List<RatingModel>> getRatingsByWarehouse(int warehouseId) async {
    final response = await dio.get(
      '/ratings/warehouse/$warehouseId',
    );
    final List<dynamic> data = response.data;
    return data.map((e) => RatingModel.fromJson(e)).toList();
  }

  Future<WarehouseRatingSummary> getWarehouseSummary(int warehouseId) async {
    final response = await dio.get(
      '/ratings/warehouse/$warehouseId/summary',
    );
    return WarehouseRatingSummary.fromJson(response.data);
  }

  Future<RatingModel?> getMyRating(int warehouseId) async {
    try {
      final response = await dio.get(
        '/ratings/warehouse/$warehouseId/me',
      );
      if (response.data == null) {
        return null;
      }
      return RatingModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<RatingModel?> getRatingByReservation(int reservationId) async {
    try {
      final response = await dio.get(
        '/ratings/reservation/$reservationId',
      );
      if (response.data == null) {
        return null;
      }
      return RatingModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}

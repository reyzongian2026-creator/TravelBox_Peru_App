import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class AdminDashboardRepository {
  Future<DashboardStats> getDashboardStats(String period);
  Future<DashboardOverview> getDashboardOverview(String period);
  Future<DashboardSummary> getDashboardSummary(String period);
  Future<void> invalidateCache({String? period});
}

class DashboardStats {
  final int totalReservations;
  final int activeReservations;
  final int completedReservations;
  final int cancelledReservations;
  final double completionRate;
  final double revenueTotal;
  final double averageTicket;
  final int uniqueClients;
  final int openIncidents;
  final DateTime generatedAt;

  const DashboardStats({
    required this.totalReservations,
    required this.activeReservations,
    required this.completedReservations,
    required this.cancelledReservations,
    required this.completionRate,
    required this.revenueTotal,
    required this.averageTicket,
    required this.uniqueClients,
    required this.openIncidents,
    required this.generatedAt,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? json;
    return DashboardStats(
      totalReservations: (summary['reservations'] as int?) ?? 0,
      activeReservations: (summary['activeReservations'] as int?) ?? 0,
      completedReservations: (summary['completedReservations'] as int?) ?? 0,
      cancelledReservations: (summary['cancelledReservations'] as int?) ?? 0,
      completionRate: (summary['completionRate'] as num?)?.toDouble() ?? 0.0,
      revenueTotal: (summary['confirmedRevenue'] as num?)?.toDouble() ?? 0.0,
      averageTicket: (summary['averageTicket'] as num?)?.toDouble() ?? 0.0,
      uniqueClients: (summary['uniqueClients'] as int?) ?? 0,
      openIncidents: (summary['openIncidents'] as int?) ?? 0,
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class DashboardOverview {
  final String period;
  final String periodLabel;
  final int totalUsers;
  final int totalWarehouses;
  final int activeReservations;
  final int openIncidents;
  final double totalConfirmedPayments;
  final List<TopWarehousePerformance> topWarehouses;
  final List<TopCityPerformance> topCities;
  final DateTime generatedAt;

  const DashboardOverview({
    required this.period,
    required this.periodLabel,
    required this.totalUsers,
    required this.totalWarehouses,
    required this.activeReservations,
    required this.openIncidents,
    required this.totalConfirmedPayments,
    required this.topWarehouses,
    required this.topCities,
    required this.generatedAt,
  });

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    return DashboardOverview(
      period: json['period']?.toString() ?? 'month',
      periodLabel: json['periodLabel']?.toString() ?? '',
      totalUsers: (json['totalUsers'] as int?) ?? 0,
      totalWarehouses: (json['totalWarehouses'] as int?) ?? 0,
      activeReservations: (json['activeReservations'] as int?) ?? 0,
      openIncidents: (json['openIncidents'] as int?) ?? 0,
      totalConfirmedPayments: (json['confirmedPaymentsAmount'] as num?)?.toDouble() ?? 0.0,
      topWarehouses: (json['topWarehouses'] as List<dynamic>?)
              ?.map((e) => TopWarehousePerformance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topCities: (json['topCities'] as List<dynamic>?)
              ?.map((e) => TopCityPerformance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class TopWarehousePerformance {
  final String warehouseId;
  final String warehouseName;
  final String city;
  final int interactionCount;
  final int completedReservations;
  final double revenue;

  const TopWarehousePerformance({
    required this.warehouseId,
    required this.warehouseName,
    required this.city,
    required this.interactionCount,
    required this.completedReservations,
    required this.revenue,
  });

  factory TopWarehousePerformance.fromJson(Map<String, dynamic> json) {
    return TopWarehousePerformance(
      warehouseId: json['warehouseId']?.toString() ?? '',
      warehouseName: json['warehouseName']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      interactionCount: (json['interactionCount'] as int?) ?? 0,
      completedReservations: (json['completedReservations'] as int?) ?? 0,
      revenue: (json['confirmedRevenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TopCityPerformance {
  final String cityName;
  final int reservationCount;
  final int completedReservations;
  final double revenue;

  const TopCityPerformance({
    required this.cityName,
    required this.reservationCount,
    required this.completedReservations,
    required this.revenue,
  });

  factory TopCityPerformance.fromJson(Map<String, dynamic> json) {
    return TopCityPerformance(
      cityName: json['city']?.toString() ?? json['cityName']?.toString() ?? '',
      reservationCount: (json['interactionCount'] as int?) ?? 0,
      completedReservations: (json['completedReservations'] as int?) ?? 0,
      revenue: (json['confirmedRevenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardSummary {
  final String period;
  final int totalReservations;
  final double revenue;
  final int activeReservations;
  final int completedReservations;
  final double completionRate;

  const DashboardSummary({
    required this.period,
    required this.totalReservations,
    required this.revenue,
    required this.activeReservations,
    required this.completedReservations,
    required this.completionRate,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? json;
    return DashboardSummary(
      period: json['period']?.toString() ?? 'month',
      totalReservations: (summary['reservations'] as int?) ?? 0,
      revenue: (summary['confirmedRevenue'] as num?)?.toDouble() ?? 0.0,
      activeReservations: (summary['activeReservations'] as int?) ?? 0,
      completedReservations: (summary['completedReservations'] as int?) ?? 0,
      completionRate: (summary['completionRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>((ref) {
  return AdminDashboardRepositoryImpl(dio: ref.watch(dioProvider));
});

class AdminDashboardRepositoryImpl implements AdminDashboardRepository {
  final Dio _dio;

  AdminDashboardRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<DashboardStats> getDashboardStats(String period) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/stats',
        queryParameters: {'period': period},
      );

      final data = response.data;
      if (data == null) {
        throw AppException('Dashboard stats not available');
      }

      return DashboardStats.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<DashboardOverview> getDashboardOverview(String period) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/overview',
        queryParameters: {'period': period},
      );

      final data = response.data;
      if (data == null) {
        throw AppException('Dashboard overview not available');
      }

      return DashboardOverview.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<DashboardSummary> getDashboardSummary(String period) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/dashboard/summary',
        queryParameters: {'period': period},
      );

      final data = response.data;
      if (data == null) {
        throw AppException('Dashboard summary not available');
      }

      return DashboardSummary.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> invalidateCache({String? period}) async {
    try {
      await _dio.post<void>(
        '/admin/dashboard/invalidate-cache',
        queryParameters: {
          if (period != null) 'period': period,
        },
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

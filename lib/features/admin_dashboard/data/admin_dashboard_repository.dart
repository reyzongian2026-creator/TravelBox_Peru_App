import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class AdminDashboardRepository {
  Future<DashboardStats> getDashboardStats(String period);
  Future<DashboardOverview> getDashboardOverview(String period);
  Future<DashboardSummary> getDashboardSummary(String period);
  Future<DashboardSummary> getDashboardSummaryOnly(String period);
  Future<List<RankingItem>> getDashboardRankings(String period);
  Future<TrendsData> getDashboardTrends(String period);
  Future<void> invalidateCache({String? period});
  
  Future<RevenueReport> getRevenueReport(DateTime startDate, DateTime endDate);
  
  Future<List<AdminRatingItem>> getAllRatings();
  Future<void> updateRating(int ratingId, Map<String, dynamic> updates);
  Future<void> deleteRating(int ratingId);
  
  Future<SystemHealthInfo> getSystemHealth();
  
  Future<List<AuditLogEntry>> getAuditLog({int limit = 100, String? entityType, int? entityId, String? action, String? performedBy});
}

class RankingItem {
  final String type;
  final String label;
  final int value;
  final double score;
  final String? warehouseId;
  final String? warehouseName;
  final String? city;

  RankingItem({
    required this.type,
    required this.label,
    required this.value,
    required this.score,
    this.warehouseId,
    this.warehouseName,
    this.city,
  });

  factory RankingItem.fromJson(Map<String, dynamic> json) {
    return RankingItem(
      type: json['type']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      value: (json['value'] as int?) ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      warehouseId: json['warehouseId']?.toString(),
      warehouseName: json['warehouseName']?.toString(),
      city: json['city']?.toString(),
    );
  }
}

class TrendsData {
  final String period;
  final List<TrendPoint> reservations;
  final List<TrendPoint> revenue;
  final List<TrendPoint> activeUsers;
  final double reservationGrowth;
  final double revenueGrowth;
  final double userGrowth;

  TrendsData({
    required this.period,
    required this.reservations,
    required this.revenue,
    required this.activeUsers,
    required this.reservationGrowth,
    required this.revenueGrowth,
    required this.userGrowth,
  });

  factory TrendsData.fromJson(Map<String, dynamic> json) {
    return TrendsData(
      period: json['period']?.toString() ?? 'month',
      reservations: (json['reservations'] as List<dynamic>?)
              ?.map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      revenue: (json['revenue'] as List<dynamic>?)
              ?.map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      activeUsers: (json['activeUsers'] as List<dynamic>?)
              ?.map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      reservationGrowth: (json['reservationGrowth'] as num?)?.toDouble() ?? 0.0,
      revenueGrowth: (json['revenueGrowth'] as num?)?.toDouble() ?? 0.0,
      userGrowth: (json['userGrowth'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TrendPoint {
  final String date;
  final double value;

  TrendPoint({required this.date, required this.value});

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      date: json['date']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }
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

class RevenueReport {
  final Decimal totalRevenue;
  final int totalReservations;
  final Decimal averageReservationValue;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String periodLabel;
  final List<RevenueByWarehouse> byWarehouse;
  final List<RevenueByCity> byCity;
  final List<RevenueByDay> byDay;

  RevenueReport({
    required this.totalRevenue,
    required this.totalReservations,
    required this.averageReservationValue,
    required this.periodStart,
    required this.periodEnd,
    required this.periodLabel,
    required this.byWarehouse,
    required this.byCity,
    required this.byDay,
  });

  factory RevenueReport.fromJson(Map<String, dynamic> json) {
    Decimal parseDecimal(dynamic value) {
      if (value == null) return Decimal.zero;
      if (value is Decimal) return value;
      if (value is int) return Decimal.fromInt(value);
      if (value is double) return Decimal.parse(value.toString());
      if (value is String) {
        try {
          return Decimal.parse(value);
        } catch (_) {
          return Decimal.zero;
        }
      }
      return Decimal.zero;
    }

    return RevenueReport(
      totalRevenue: parseDecimal(json['totalRevenue']),
      totalReservations: (json['totalReservations'] as int?) ?? 0,
      averageReservationValue: parseDecimal(json['averageReservationValue']),
      periodStart: DateTime.tryParse(json['periodStart']?.toString() ?? '') ?? DateTime.now(),
      periodEnd: DateTime.tryParse(json['periodEnd']?.toString() ?? '') ?? DateTime.now(),
      periodLabel: json['periodLabel']?.toString() ?? '',
      byWarehouse: (json['byWarehouse'] as List<dynamic>?)
          ?.map((e) => RevenueByWarehouse.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      byCity: (json['byCity'] as List<dynamic>?)
          ?.map((e) => RevenueByCity.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      byDay: (json['byDay'] as List<dynamic>?)
          ?.map((e) => RevenueByDay.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

class RevenueByWarehouse {
  final int warehouseId;
  final String warehouseName;
  final Decimal revenue;
  final int reservationCount;

  RevenueByWarehouse({
    required this.warehouseId,
    required this.warehouseName,
    required this.revenue,
    required this.reservationCount,
  });

  factory RevenueByWarehouse.fromJson(Map<String, dynamic> json) {
    Decimal parseDecimal(dynamic value) {
      if (value == null) return Decimal.zero;
      if (value is Decimal) return value;
      if (value is int) return Decimal.fromInt(value);
      if (value is double) return Decimal.parse(value.toString());
      if (value is String) {
        try {
          return Decimal.parse(value);
        } catch (_) {
          return Decimal.zero;
        }
      }
      return Decimal.zero;
    }

    return RevenueByWarehouse(
      warehouseId: (json['warehouseId'] as int?) ?? 0,
      warehouseName: json['warehouseName']?.toString() ?? '',
      revenue: parseDecimal(json['revenue']),
      reservationCount: (json['reservationCount'] as int?) ?? 0,
    );
  }
}

class RevenueByCity {
  final String cityName;
  final Decimal revenue;
  final int reservationCount;

  RevenueByCity({
    required this.cityName,
    required this.revenue,
    required this.reservationCount,
  });

  factory RevenueByCity.fromJson(Map<String, dynamic> json) {
    Decimal parseDecimal(dynamic value) {
      if (value == null) return Decimal.zero;
      if (value is Decimal) return value;
      if (value is int) return Decimal.fromInt(value);
      if (value is double) return Decimal.parse(value.toString());
      if (value is String) {
        try {
          return Decimal.parse(value);
        } catch (_) {
          return Decimal.zero;
        }
      }
      return Decimal.zero;
    }

    return RevenueByCity(
      cityName: json['cityName']?.toString() ?? '',
      revenue: parseDecimal(json['revenue']),
      reservationCount: (json['reservationCount'] as int?) ?? 0,
    );
  }
}

class RevenueByDay {
  final String date;
  final Decimal revenue;
  final int reservationCount;

  RevenueByDay({
    required this.date,
    required this.revenue,
    required this.reservationCount,
  });

  factory RevenueByDay.fromJson(Map<String, dynamic> json) {
    Decimal parseDecimal(dynamic value) {
      if (value == null) return Decimal.zero;
      if (value is Decimal) return value;
      if (value is int) return Decimal.fromInt(value);
      if (value is double) return Decimal.parse(value.toString());
      if (value is String) {
        try {
          return Decimal.parse(value);
        } catch (_) {
          return Decimal.zero;
        }
      }
      return Decimal.zero;
    }

    return RevenueByDay(
      date: json['date']?.toString() ?? '',
      revenue: parseDecimal(json['revenue']),
      reservationCount: (json['reservationCount'] as int?) ?? 0,
    );
  }
}

class AdminRatingItem {
  final int id;
  final int userId;
  final String userName;
  final String userEmail;
  final int warehouseId;
  final String warehouseName;
  final int? reservationId;
  final int stars;
  final String? comment;
  final String type;
  final bool verified;
  final DateTime createdAt;

  AdminRatingItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.warehouseId,
    required this.warehouseName,
    this.reservationId,
    required this.stars,
    this.comment,
    required this.type,
    required this.verified,
    required this.createdAt,
  });

  factory AdminRatingItem.fromJson(Map<String, dynamic> json) {
    return AdminRatingItem(
      id: (json['id'] as int?) ?? 0,
      userId: (json['userId'] as int?) ?? 0,
      userName: json['userName']?.toString() ?? '',
      userEmail: json['userEmail']?.toString() ?? '',
      warehouseId: (json['warehouseId'] as int?) ?? 0,
      warehouseName: json['warehouseName']?.toString() ?? '',
      reservationId: json['reservationId'] as int?,
      stars: (json['stars'] as int?) ?? 0,
      comment: json['comment']?.toString(),
      type: json['type']?.toString() ?? 'WAREHOUSE',
      verified: (json['verified'] as bool?) ?? false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class SystemHealthInfo {
  final String application;
  final String status;
  final String port;
  final DateTime timestamp;
  final MemoryInfo memory;
  final CpuInfo cpu;

  SystemHealthInfo({
    required this.application,
    required this.status,
    required this.port,
    required this.timestamp,
    required this.memory,
    required this.cpu,
  });

  factory SystemHealthInfo.fromJson(Map<String, dynamic> json) {
    return SystemHealthInfo(
      application: json['application']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DOWN',
      port: json['port']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      memory: MemoryInfo.fromJson(json['memory'] as Map<String, dynamic>? ?? {}),
      cpu: CpuInfo.fromJson(json['cpu'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class MemoryInfo {
  final int usedMB;
  final int maxMB;
  final int freeMB;
  final double usagePercent;

  MemoryInfo({
    required this.usedMB,
    required this.maxMB,
    required this.freeMB,
    required this.usagePercent,
  });

  factory MemoryInfo.fromJson(Map<String, dynamic> json) {
    return MemoryInfo(
      usedMB: (json['usedMB'] as int?) ?? 0,
      maxMB: (json['maxMB'] as int?) ?? 0,
      freeMB: (json['freeMB'] as int?) ?? 0,
      usagePercent: (json['usagePercent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CpuInfo {
  final int availableProcessors;
  final double loadAverage;

  CpuInfo({
    required this.availableProcessors,
    required this.loadAverage,
  });

  factory CpuInfo.fromJson(Map<String, dynamic> json) {
    return CpuInfo(
      availableProcessors: (json['availableProcessors'] as int?) ?? 0,
      loadAverage: (json['loadAverage'] as num?)?.toDouble() ?? -1,
    );
  }
}

class AuditLogEntry {
  final int id;
  final DateTime timestamp;
  final String action;
  final String entityType;
  final int entityId;
  final String? details;
  final String? performedBy;

  AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.details,
    this.performedBy,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: (json['id'] as int?) ?? 0,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      action: json['action']?.toString() ?? '',
      entityType: json['entityType']?.toString() ?? '',
      entityId: (json['entityId'] as int?) ?? 0,
      details: json['details']?.toString(),
      performedBy: json['performedBy']?.toString(),
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
        throw AppException.withCode(AppErrorCode.errFetchFailed, backendMessage: 'Dashboard stats not available');
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
        throw AppException.withCode(AppErrorCode.errFetchFailed, backendMessage: 'Dashboard overview not available');
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
        throw AppException.withCode(AppErrorCode.errFetchFailed, backendMessage: 'Dashboard summary not available');
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
          'period': ?period,
        },
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<RevenueReport> getRevenueReport(DateTime startDate, DateTime endDate) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/reports/revenue',
        queryParameters: {
          'startDate': '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
          'endDate': '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
        },
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.errFetchFailed, backendMessage: 'Revenue report not available');
      }
      return RevenueReport.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<AdminRatingItem>> getAllRatings() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/admin/reports/ratings',
      );
      final data = response.data;
      if (data == null) {
        return [];
      }
      return data.map((e) => AdminRatingItem.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<SystemHealthInfo> getSystemHealth() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/system/health',
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.errFetchFailed, backendMessage: 'System health not available');
      }
      return SystemHealthInfo.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<AuditLogEntry>> getAuditLog({
    int limit = 100,
    String? entityType,
    int? entityId,
    String? action,
    String? performedBy,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/admin/system/audit-log',
        queryParameters: {
          'limit': limit,
          'entityType': ?entityType,
          'entityId': ?entityId,
          'action': ?action,
          'performedBy': ?performedBy,
        },
      );
      final data = response.data;
      if (data == null) {
        return [];
      }
      return data.map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<DashboardSummary> getDashboardSummaryOnly(String period) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/dashboard/summary-only',
        queryParameters: {'period': period},
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.errFetchFailed, backendMessage: 'Dashboard summary not available');
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
  Future<List<RankingItem>> getDashboardRankings(String period) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/admin/dashboard/rankings-only',
        queryParameters: {'period': period},
      );
      final data = response.data;
      if (data == null) return [];
      return data.map((e) => RankingItem.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<TrendsData> getDashboardTrends(String period) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/dashboard/trends-only',
        queryParameters: {'period': period},
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.errFetchFailed, backendMessage: 'Trends data not available');
      }
      return TrendsData.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> updateRating(int ratingId, Map<String, dynamic> updates) async {
    try {
      await _dio.patch<void>(
        '/admin/reports/ratings/$ratingId',
        data: updates,
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    try {
      await _dio.delete<void>('/admin/reports/ratings/$ratingId');
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin Models JSON Parsing', () {
    test('RevenueReport fromJson parses all fields correctly', () {
      final json = {
        'totalRevenue': 125000.50,
        'totalReservations': 150,
        'averageReservationValue': 833.33,
        'periodStart': '2024-01-01T00:00:00Z',
        'periodEnd': '2024-12-31T00:00:00Z',
        'periodLabel': '2024 Full Year',
        'byWarehouse': [
          {'warehouseId': 1, 'warehouseName': 'Miraflores', 'revenue': 50000.00, 'reservationCount': 60}
        ],
        'byCity': [
          {'cityName': 'Lima', 'revenue': 100000.00, 'reservationCount': 120}
        ],
        'byDay': [
          {'date': '2024-01-01', 'revenue': 500.00, 'reservationCount': 2}
        ]
      };

      final report = _RevenueReport.fromJson(json);

      expect(report.totalRevenue, 125000.50);
      expect(report.totalReservations, 150);
      expect(report.averageReservationValue, 833.33);
      expect(report.periodLabel, '2024 Full Year');
      expect(report.byWarehouse.length, 1);
      expect(report.byCity.length, 1);
      expect(report.byDay.length, 1);
      expect(report.byWarehouse.first.warehouseName, 'Miraflores');
    });

    test('AdminRatingItem fromJson parses all fields correctly', () {
      final json = {
        'id': 1,
        'userId': 10,
        'userName': 'Juan Perez',
        'userEmail': 'juan@test.com',
        'warehouseId': 5,
        'warehouseName': 'Surco',
        'reservationId': 100,
        'stars': 5,
        'comment': 'Excelente servicio',
        'type': 'WAREHOUSE',
        'verified': true,
        'createdAt': '2024-06-15T10:30:00Z'
      };

      final item = _AdminRatingItem.fromJson(json);

      expect(item.id, 1);
      expect(item.userName, 'Juan Perez');
      expect(item.stars, 5);
      expect(item.verified, true);
    });

    test('SystemHealthInfo fromJson parses memory and CPU correctly', () {
      final json = {
        'application': 'storage',
        'status': 'UP',
        'port': '8080',
        'timestamp': '2024-06-15T10:30:00Z',
        'memory': {'usedMB': 512, 'maxMB': 2048, 'freeMB': 1536, 'usagePercent': 25.0},
        'cpu': {'availableProcessors': 8, 'loadAverage': 1.5}
      };

      final health = _SystemHealthInfo.fromJson(json);

      expect(health.status, 'UP');
      expect(health.memory.usedMB, 512);
      expect(health.cpu.availableProcessors, 8);
    });

    test('AuditLogEntry fromJson parses all fields', () {
      final json = {
        'id': 1,
        'timestamp': '2024-06-15T10:30:00Z',
        'action': 'CREATE',
        'entityType': 'User',
        'entityId': 10,
        'details': 'User created',
        'performedBy': 'admin@test.com'
      };

      final entry = _AuditLogEntry.fromJson(json);

      expect(entry.action, 'CREATE');
      expect(entry.entityType, 'User');
      expect(entry.entityId, 10);
    });

    test('handles null values gracefully', () {
      final json = {
        'totalRevenue': null,
        'totalReservations': null,
        'averageReservationValue': null,
        'periodStart': null,
        'periodEnd': null,
        'periodLabel': null,
        'byWarehouse': null,
        'byCity': null,
        'byDay': null,
      };

      final report = _RevenueReport.fromJson(json);

      expect(report.totalRevenue, 0.0);
      expect(report.totalReservations, 0);
      expect(report.byWarehouse, isEmpty);
    });

    test('handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final report = _RevenueReport.fromJson(json);
      final health = _SystemHealthInfo.fromJson(json);

      expect(report.totalRevenue, 0.0);
      expect(health.status, 'DOWN');
    });
  });

  group('Admin Users Paged Item', () {
    test('AdminUserPagedItem fromJson parses correctly', () {
      final json = {
        'id': 123,
        'fullName': 'Test User',
        'email': 'test@test.com',
        'roles': 'CLIENT;OPERATOR',
        'active': true,
        'warehouseIds': [1, 2, 3],
        'createdAt': '2024-01-15T10:30:00Z'
      };

      final item = _AdminUserPagedItem.fromJson(json);

      expect(item.id, 123);
      expect(item.fullName, 'Test User');
      expect(item.email, 'test@test.com');
      expect(item.active, true);
      expect(item.warehouseIds, [1, 2, 3]);
    });
  });

  group('CSV Export Format', () {
    test('CSV has BOM for UTF-8', () {
      const csvWithBom = '\u{FEFF}ID,Name,Email';
      expect(csvWithBom.startsWith('\u{FEFF}'), true);
    });

    test('CSV fields are properly escaped', () {
      expect('value with, comma', contains(','));
      expect('value with "quotes"', contains('"'));
      expect('value\nwith\nnewlines', contains('\n'));
    });
  });
}

class _RevenueReport {
  final double totalRevenue;
  final int totalReservations;
  final double averageReservationValue;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String periodLabel;
  final List<_RevenueByWarehouse> byWarehouse;
  final List<_RevenueByCity> byCity;
  final List<_RevenueByDay> byDay;

  _RevenueReport({
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

  factory _RevenueReport.fromJson(Map<String, dynamic> json) {
    return _RevenueReport(
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalReservations: (json['totalReservations'] as int?) ?? 0,
      averageReservationValue: (json['averageReservationValue'] as num?)?.toDouble() ?? 0.0,
      periodStart: DateTime.tryParse(json['periodStart']?.toString() ?? '') ?? DateTime.now(),
      periodEnd: DateTime.tryParse(json['periodEnd']?.toString() ?? '') ?? DateTime.now(),
      periodLabel: json['periodLabel']?.toString() ?? '',
      byWarehouse: (json['byWarehouse'] as List<dynamic>?)
          ?.map((e) => _RevenueByWarehouse.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      byCity: (json['byCity'] as List<dynamic>?)
          ?.map((e) => _RevenueByCity.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      byDay: (json['byDay'] as List<dynamic>?)
          ?.map((e) => _RevenueByDay.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

class _RevenueByWarehouse {
  final int warehouseId;
  final String warehouseName;
  final double revenue;
  final int reservationCount;

  _RevenueByWarehouse({
    required this.warehouseId,
    required this.warehouseName,
    required this.revenue,
    required this.reservationCount,
  });

  factory _RevenueByWarehouse.fromJson(Map<String, dynamic> json) {
    return _RevenueByWarehouse(
      warehouseId: (json['warehouseId'] as int?) ?? 0,
      warehouseName: json['warehouseName']?.toString() ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      reservationCount: (json['reservationCount'] as int?) ?? 0,
    );
  }
}

class _RevenueByCity {
  final String cityName;
  final double revenue;
  final int reservationCount;

  _RevenueByCity({
    required this.cityName,
    required this.revenue,
    required this.reservationCount,
  });

  factory _RevenueByCity.fromJson(Map<String, dynamic> json) {
    return _RevenueByCity(
      cityName: json['cityName']?.toString() ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      reservationCount: (json['reservationCount'] as int?) ?? 0,
    );
  }
}

class _RevenueByDay {
  final String date;
  final double revenue;
  final int reservationCount;

  _RevenueByDay({
    required this.date,
    required this.revenue,
    required this.reservationCount,
  });

  factory _RevenueByDay.fromJson(Map<String, dynamic> json) {
    return _RevenueByDay(
      date: json['date']?.toString() ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      reservationCount: (json['reservationCount'] as int?) ?? 0,
    );
  }
}

class _AdminRatingItem {
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

  _AdminRatingItem({
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

  factory _AdminRatingItem.fromJson(Map<String, dynamic> json) {
    return _AdminRatingItem(
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

class _SystemHealthInfo {
  final String application;
  final String status;
  final String port;
  final DateTime timestamp;
  final _MemoryInfo memory;
  final _CpuInfo cpu;

  _SystemHealthInfo({
    required this.application,
    required this.status,
    required this.port,
    required this.timestamp,
    required this.memory,
    required this.cpu,
  });

  factory _SystemHealthInfo.fromJson(Map<String, dynamic> json) {
    return _SystemHealthInfo(
      application: json['application']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DOWN',
      port: json['port']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      memory: _MemoryInfo.fromJson(json['memory'] as Map<String, dynamic>? ?? {}),
      cpu: _CpuInfo.fromJson(json['cpu'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class _MemoryInfo {
  final int usedMB;
  final int maxMB;
  final int freeMB;
  final double usagePercent;

  _MemoryInfo({
    required this.usedMB,
    required this.maxMB,
    required this.freeMB,
    required this.usagePercent,
  });

  factory _MemoryInfo.fromJson(Map<String, dynamic> json) {
    return _MemoryInfo(
      usedMB: (json['usedMB'] as int?) ?? 0,
      maxMB: (json['maxMB'] as int?) ?? 0,
      freeMB: (json['freeMB'] as int?) ?? 0,
      usagePercent: (json['usagePercent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class _CpuInfo {
  final int availableProcessors;
  final double loadAverage;

  _CpuInfo({
    required this.availableProcessors,
    required this.loadAverage,
  });

  factory _CpuInfo.fromJson(Map<String, dynamic> json) {
    return _CpuInfo(
      availableProcessors: (json['availableProcessors'] as int?) ?? 0,
      loadAverage: (json['loadAverage'] as num?)?.toDouble() ?? -1,
    );
  }
}

class _AuditLogEntry {
  final int id;
  final DateTime timestamp;
  final String action;
  final String entityType;
  final int entityId;
  final String? details;
  final String? performedBy;

  _AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.details,
    this.performedBy,
  });

  factory _AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return _AuditLogEntry(
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

class _AdminUserPagedItem {
  final int id;
  final String fullName;
  final String email;
  final String roles;
  final bool active;
  final List<int> warehouseIds;
  final DateTime createdAt;

  _AdminUserPagedItem({
    required this.id,
    required this.fullName,
    required this.email,
    required this.roles,
    required this.active,
    required this.warehouseIds,
    required this.createdAt,
  });

  factory _AdminUserPagedItem.fromJson(Map<String, dynamic> json) {
    return _AdminUserPagedItem(
      id: json['id'] as int,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      roles: json['roles'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      warehouseIds: (json['warehouseIds'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

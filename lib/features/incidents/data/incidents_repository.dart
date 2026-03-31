import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class IncidentsRepository {
  Future<List<Incident>> getIncidents();
  Future<PagedResult<Incident>> getIncidentsPage({
    int page = 0,
    int size = 20,
    String? status,
    String? severity,
    String? type,
  });
  Future<Incident> createIncident(CreateIncidentRequest request);
  Future<Incident> resolveIncident(int incidentId, String resolution);
  Future<List<IncidentMessage>> getIncidentMessages(int incidentId);
  Future<IncidentMessage> addIncidentMessage({
    required int incidentId,
    required String message,
    required String originalLanguage,
  });
}

class CreateIncidentRequest {
  final String title;
  final String description;
  final String type;
  final String? reservationId;
  final String? warehouseId;
  final String? priority;
  final String originalLanguage;

  CreateIncidentRequest({
    required this.title,
    required this.description,
    required this.type,
    required this.originalLanguage,
    this.reservationId,
    this.warehouseId,
    this.priority,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'type': type,
        'originalLanguage': originalLanguage,
        if (reservationId != null) 'reservationId': reservationId,
        if (warehouseId != null) 'warehouseId': warehouseId,
        if (priority != null) 'priority': priority,
      };
}

class Incident {
  final int id;
  final String title;
  final String description;
  final String type;
  final String status;
  final String? severity;
  final String? priority;
  final String? reservationId;
  final String? warehouseId;
  final String? reporterId;
  final String? reporterName;
  final String? assignedTo;
  final String? assignedToName;
  final String? resolution;
  final String? originalLanguage;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime? updatedAt;

  Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    this.severity,
    this.priority,
    this.reservationId,
    this.warehouseId,
    this.reporterId,
    this.reporterName,
    this.assignedTo,
    this.assignedToName,
    this.resolution,
    this.originalLanguage,
    required this.createdAt,
    this.resolvedAt,
    this.updatedAt,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: (json['id'] as int?) ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      severity: json['severity']?.toString(),
      priority: json['priority']?.toString(),
      reservationId: json['reservationId']?.toString(),
      warehouseId: json['warehouseId']?.toString(),
      reporterId: json['reporterId']?.toString(),
      reporterName: json['reporterName']?.toString(),
      assignedTo: json['assignedTo']?.toString(),
      assignedToName: json['assignedToName']?.toString(),
      resolution: json['resolution']?.toString(),
      originalLanguage: json['originalLanguage']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      resolvedAt: json['resolvedAt'] != null ? DateTime.tryParse(json['resolvedAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }
}

class IncidentMessage {
  final int id;
  final int incidentId;
  final int? authorId;
  final String? authorName;
  final String authorRole;
  final String originalLanguage;
  final String textOriginal;
  final String? textTranslated;
  final DateTime createdAt;

  IncidentMessage({
    required this.id,
    required this.incidentId,
    this.authorId,
    this.authorName,
    required this.authorRole,
    required this.originalLanguage,
    required this.textOriginal,
    this.textTranslated,
    required this.createdAt,
  });

  factory IncidentMessage.fromJson(Map<String, dynamic> json) {
    return IncidentMessage(
      id: (json['id'] as int?) ?? 0,
      incidentId: (json['incidentId'] as int?) ?? 0,
      authorId: json['authorId'] as int?,
      authorName: json['authorName']?.toString(),
      authorRole: json['authorRole']?.toString() ?? 'unknown',
      originalLanguage: json['originalLanguage']?.toString() ?? 'es',
      textOriginal: json['textOriginal']?.toString() ?? '',
      textTranslated: json['textTranslated']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class PagedResult<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  PagedResult({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final contentList =
        json['items'] as List<dynamic>? ??
        json['content'] as List<dynamic>? ??
        [];
    final hasNext = json['hasNext'] as bool? ?? false;
    return PagedResult(
      content: contentList.map((e) => fromJsonT(e as Map<String, dynamic>)).toList(),
      page: (json['page'] as int?) ?? 0,
      size: (json['size'] as int?) ?? json['pageSize'] as int? ?? 20,
      totalElements: (json['totalElements'] as int?) ?? json['total'] as int? ?? 0,
      totalPages: (json['totalPages'] as int?) ?? json['pages'] as int? ?? 0,
      last: (json['last'] as bool?) ?? !hasNext,
    );
  }
}

final incidentsRepositoryProvider = Provider<IncidentsRepository>((ref) {
  return IncidentsRepositoryImpl(dio: ref.watch(dioProvider));
});

class IncidentsRepositoryImpl implements IncidentsRepository {
  final Dio _dio;

  IncidentsRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<List<Incident>> getIncidents() async {
    try {
      final response = await _dio.get<List<dynamic>>('/incidents');
      final data = response.data;
      if (data == null) return [];
      return data.map((e) => Incident.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<PagedResult<Incident>> getIncidentsPage({
    int page = 0,
    int size = 20,
    String? status,
    String? severity,
    String? type,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/incidents/page',
        queryParameters: {
          'page': page,
          'size': size,
          if (status != null && status.isNotEmpty) 'status': status,
          if (severity != null && severity.isNotEmpty) 'severity': severity,
          if (type != null && type.isNotEmpty) 'type': type,
        },
      );
      final data = response.data;
      if (data == null) {
        return PagedResult(
          content: [],
          page: page,
          size: size,
          totalElements: 0,
          totalPages: 0,
          last: true,
        );
      }
      return PagedResult.fromJson(data, Incident.fromJson);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<Incident> createIncident(CreateIncidentRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/incidents',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.errCreateIncident, backendMessage: 'Failed to create incident');
      }
      return Incident.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<Incident> resolveIncident(int incidentId, String resolution) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/incidents/$incidentId/resolve',
        data: {'resolution': resolution},
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.errUpdateFailed, backendMessage: 'Failed to resolve incident');
      }
      return Incident.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<IncidentMessage>> getIncidentMessages(int incidentId) async {
    try {
      final response = await _dio.get<List<dynamic>>('/incidents/$incidentId/messages');
      final data = response.data;
      if (data == null) return [];
      return data
          .map((item) => IncidentMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<IncidentMessage> addIncidentMessage({
    required int incidentId,
    required String message,
    required String originalLanguage,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/incidents/$incidentId/messages',
        data: {
          'message': message,
          'originalLanguage': originalLanguage,
        },
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(
          AppErrorCode.errCreateIncident,
          backendMessage: 'Failed to add incident message',
        );
      }
      return IncidentMessage.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

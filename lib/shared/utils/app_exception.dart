import 'dart:convert';

import 'package:dio/dio.dart';

class AppException implements Exception {
  AppException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory AppException.fromDioError(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return AppException(
        'No tienes conexion a internet o la senal es muy debil.',
      );
    }

    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final payload = _asMap(data);
    final backendMessage = payload?['message']?.toString().trim();
    final details = _extractDetails(payload);
    final detailedMessage = _joinMessageWithDetails(backendMessage, details);

    if (detailedMessage != null) {
      return AppException(detailedMessage, statusCode: statusCode);
    }

    if (statusCode == 400) {
      return AppException(
        'Datos invalidos en la peticion.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 403) {
      return AppException(
        'No tienes permisos para realizar esta accion.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 404) {
      return AppException(
        'El recurso solicitado ya no existe.',
        statusCode: statusCode,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return AppException(
        'El servidor esta en mantenimiento. Intenta de nuevo.',
        statusCode: statusCode,
      );
    }

    return AppException(
      'Ocurrio un error inesperado de comunicacion.',
      statusCode: statusCode,
    );
  }

  factory AppException.fromError(Object error) {
    if (error is AppException) {
      return error;
    }
    if (error is DioException) {
      return AppException.fromDioError(error);
    }
    return AppException(
      error.toString().replaceFirst('Exception: ', '').trim(),
    );
  }

  @override
  String toString() => message;

  static Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty ||
          (!trimmed.startsWith('{') && !trimmed.startsWith('['))) {
        return null;
      }
      try {
        final parsed = jsonDecode(trimmed);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        }
        if (parsed is Map) {
          return parsed.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static List<String> _extractDetails(Map<String, dynamic>? payload) {
    if (payload == null) {
      return const [];
    }
    final rawDetails = payload['details'];
    if (rawDetails is! List) {
      return const [];
    }
    return rawDetails
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String? _joinMessageWithDetails(
    String? backendMessage,
    List<String> details,
  ) {
    final normalizedMessage = backendMessage?.trim();
    if (details.isEmpty) {
      if (normalizedMessage == null || normalizedMessage.isEmpty) {
        return null;
      }
      return normalizedMessage;
    }
    final joinedDetails = details.join(' | ');
    if (normalizedMessage == null || normalizedMessage.isEmpty) {
      return joinedDetails;
    }
    return '$normalizedMessage $joinedDetails';
  }
}

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

    final data = error.response?.data;
    String? backendMessage;
    if (data is Map<String, dynamic>) {
      backendMessage = data['message']?.toString();
    } else if (data is Map) {
      backendMessage = data['message']?.toString();
    }

    return AppException(
      backendMessage?.trim().isNotEmpty == true
          ? backendMessage!.trim()
          : 'Ocurrio un error inesperado de comunicacion.',
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
}

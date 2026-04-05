import 'dart:convert';

import 'package:dio/dio.dart';

enum AppErrorCode {
  errorConnection,
  errorRateLimit,
  errorNoPermissions,
  errorNotFound,
  errorServerError,
  errorGeneric,
  errorInvalidRequest,
  errorUnauthorized,
  errorBadRequest,
  
  errNoResponse,
  errExportFailed,
  errCheckinFailed,
  errCheckoutFailed,
  errUploadFailed,
  errCreateIncident,
  errCreateWarehouse,
  errCreateUser,
  errUpdateFailed,
  errDeleteFailed,
  errFetchFailed,
}

class AppError {
  const AppError(this.code, {this.params = const {}, this.backendMessage});

  final AppErrorCode code;
  final Map<String, dynamic> params;
  final String? backendMessage;

  String get translationKey => code.name.replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}');

  bool get hasBackendMessage => backendMessage != null && backendMessage!.isNotEmpty;

  @override
  String toString() => 'AppError($code, params: $params, backendMessage: $backendMessage)';
}

class AppException implements Exception {
  const AppException(this.error, {this.statusCode});

  final AppError error;
  final int? statusCode;

  factory AppException.fromDioError(DioException error, {String? backendMessage}) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return AppException(
        const AppError(AppErrorCode.errorConnection),
      );
    }

    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final payload = _asMap(data);
    final extractedMessage = payload?['message']?.toString().trim();
    final extractedDetails = _extractDetails(payload);
    final joinedMessage = _joinMessageWithDetails(extractedMessage, extractedDetails);

    if (statusCode == 429) {
      final retryAfter = _extractRetryAfterSeconds(error.response?.headers);
      return AppException(
        AppError(
          AppErrorCode.errorRateLimit,
          params: retryAfter != null && retryAfter > 0 ? {'seconds': retryAfter} : {},
        ),
        statusCode: statusCode,
      );
    }

    if (statusCode == 400) {
      return AppException(
        AppError(
          AppErrorCode.errorInvalidRequest,
          backendMessage: joinedMessage,
        ),
        statusCode: statusCode,
      );
    }
    if (statusCode == 401) {
      return AppException(
        AppError(
          AppErrorCode.errorUnauthorized,
          backendMessage: joinedMessage,
        ),
        statusCode: statusCode,
      );
    }
    if (statusCode == 403) {
      return AppException(
        AppError(
          AppErrorCode.errorNoPermissions,
          backendMessage: joinedMessage,
        ),
        statusCode: statusCode,
      );
    }
    if (statusCode == 404) {
      return AppException(
        AppError(
          AppErrorCode.errorNotFound,
          backendMessage: joinedMessage,
        ),
        statusCode: statusCode,
      );
    }
    if (statusCode == 409) {
      return AppException(
        AppError(
          AppErrorCode.errorGeneric,
          backendMessage: joinedMessage,
        ),
        statusCode: statusCode,
      );
    }
    if (statusCode == 428) {
      return AppException(
        AppError(
          AppErrorCode.errorGeneric,
          backendMessage: joinedMessage,
        ),
        statusCode: statusCode,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return AppException(
        AppError(
          AppErrorCode.errorServerError,
          backendMessage: joinedMessage,
        ),
        statusCode: statusCode,
      );
    }

    return AppException(
      AppError(
        AppErrorCode.errorGeneric,
        backendMessage: joinedMessage,
      ),
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
      AppError(
        AppErrorCode.errorGeneric,
        backendMessage: error.toString().replaceFirst('Exception: ', '').trim(),
      ),
    );
  }

  factory AppException.withCode(AppErrorCode code, {Map<String, dynamic> params = const {}, String? backendMessage, int? statusCode}) {
    return AppException(
      AppError(code, params: params, backendMessage: backendMessage),
      statusCode: statusCode,
    );
  }

  @override
  String toString() {
    if (error.hasBackendMessage) {
      return error.backendMessage!;
    }
    return switch (error.code) {
      AppErrorCode.errorConnection => 'Error de conexión. Verifica tu internet.',
      AppErrorCode.errorRateLimit => 'Demasiadas solicitudes. Intenta en un momento.',
      AppErrorCode.errorNoPermissions => 'No tienes permisos para esta acción.',
      AppErrorCode.errorNotFound => 'Recurso no encontrado.',
      AppErrorCode.errorServerError => 'Error interno del servidor. Intenta de nuevo.',
      AppErrorCode.errorUnauthorized => 'Sesión expirada. Inicia sesión de nuevo.',
      AppErrorCode.errorInvalidRequest => 'Solicitud inválida.',
      AppErrorCode.errorBadRequest => 'Solicitud inválida.',
      _ => 'Ocurrió un error inesperado.',
    };
  }

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

  static int? _extractRetryAfterSeconds(Headers? headers) {
    if (headers == null) {
      return null;
    }
    final value = headers.value('retry-after')?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    final asSeconds = int.tryParse(value);
    if (asSeconds != null) {
      return asSeconds;
    }
    final asDate = DateTime.tryParse(value);
    if (asDate == null) {
      return null;
    }
    final diff = asDate.toUtc().difference(DateTime.now().toUtc()).inSeconds;
    return diff > 0 ? diff : 1;
  }
}

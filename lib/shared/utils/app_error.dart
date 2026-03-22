import 'dart:convert';

import 'package:dio/dio.dart';

enum AppErrorCode {
  error_connection,
  error_rate_limit,
  error_no_permissions,
  error_not_found,
  error_server_error,
  error_generic,
  error_invalid_request,
  error_unauthorized,
  error_bad_request,
  
  err_no_response,
  err_export_failed,
  err_checkin_failed,
  err_checkout_failed,
  err_upload_failed,
  err_create_incident,
  err_create_warehouse,
  err_create_user,
  err_update_failed,
  err_delete_failed,
  err_fetch_failed,
}

class AppError {
  const AppError(this.code, {this.params = const {}, this.backendMessage});

  final AppErrorCode code;
  final Map<String, dynamic> params;
  final String? backendMessage;

  String get translationKey => code.name;

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
        const AppError(AppErrorCode.error_connection),
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
          AppErrorCode.error_rate_limit,
          params: retryAfter != null && retryAfter > 0 ? {'seconds': retryAfter} : {},
        ),
        statusCode: statusCode,
      );
    }

    if (statusCode == 400) {
      return AppException(
        AppError(
          AppErrorCode.error_invalid_request,
          backendMessage: joinedMessage,
        ),
        statusCode: statusCode,
      );
    }
    if (statusCode == 401) {
      return AppException(
        AppError(
          AppErrorCode.error_unauthorized,
          backendMessage: joinedMessage,
        ),
        statusCode: statusCode,
      );
    }
    if (statusCode == 403) {
      return AppException(
        AppError(
          AppErrorCode.error_no_permissions,
          backendMessage: joinedMessage,
        ),
        statusCode: statusCode,
      );
    }
    if (statusCode == 404) {
      return AppException(
        AppError(
          AppErrorCode.error_not_found,
          backendMessage: joinedMessage,
        ),
        statusCode: statusCode,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return AppException(
        const AppError(AppErrorCode.error_server_error),
        statusCode: statusCode,
      );
    }

    return AppException(
      AppError(
        AppErrorCode.error_generic,
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
        AppErrorCode.error_generic,
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
  String toString() => error.toString();

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

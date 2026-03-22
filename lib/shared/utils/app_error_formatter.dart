import 'dart:convert';

import 'package:dio/dio.dart';

import 'app_error.dart';

class AppErrorFormatter {
  const AppErrorFormatter._();

  static AppError getError(Object error) {
    if (error is AppException) {
      return error.error;
    }
    if (error is DioException) {
      return _errorFromDioError(error);
    }
    return AppError(
      AppErrorCode.error_generic,
      backendMessage: error.toString().replaceFirst('Exception: ', '').trim(),
    );
  }

  static String readable(Object error, String Function(String key, {Map<String, dynamic>? params}) translator) {
    final appError = getError(error);
    var translated = translator(appError.translationKey, params: appError.params);
    
    // Handle parameter substitution (e.g., {seconds} -> 60)
    if (appError.params.isNotEmpty) {
      appError.params.forEach((key, value) {
        translated = translated.replaceAll('{$key}', value.toString());
      });
    }
    
    if (appError.hasBackendMessage) {
      return '$translated: ${appError.backendMessage}';
    }
    
    return translated;
  }

  static AppError _errorFromDioError(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const AppError(AppErrorCode.error_connection);
    }

    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final payload = _normalizeErrorData(data);
    final extractedMessage = payload?['message']?.toString().trim();
    final extractedDetails = _extractDetails(payload);
    final joinedMessage = _joinMessageWithDetails(extractedMessage, extractedDetails);

    if (statusCode == 429) {
      final retryAfter = _extractRetryAfterSeconds(error.response?.headers);
      return AppError(
        AppErrorCode.error_rate_limit,
        params: retryAfter != null && retryAfter > 0 ? {'seconds': retryAfter} : {},
      );
    }

    if (statusCode == 400) {
      return AppError(
        AppErrorCode.error_invalid_request,
        backendMessage: joinedMessage,
      );
    }
    if (statusCode == 401) {
      return AppError(
        AppErrorCode.error_unauthorized,
        backendMessage: joinedMessage,
      );
    }
    if (statusCode == 403) {
      return AppError(
        AppErrorCode.error_no_permissions,
        backendMessage: joinedMessage,
      );
    }
    if (statusCode == 404) {
      return AppError(
        AppErrorCode.error_not_found,
        backendMessage: joinedMessage,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return const AppError(AppErrorCode.error_server_error);
    }

    return AppError(
      AppErrorCode.error_generic,
      backendMessage: joinedMessage,
    );
  }

  static String translateError(Object error, String Function(String key, {Map<String, dynamic>? params}) translator) {
    final appError = getError(error);
    
    if (appError.hasBackendMessage) {
      final translated = translator(appError.translationKey, params: appError.params);
      return '$translated: ${appError.backendMessage}';
    }
    
    return translator(appError.translationKey, params: appError.params);
  }

  static String getErrorKey(Object error) {
    final appError = getError(error);
    return appError.translationKey;
  }

  static Map<String, dynamic>? _normalizeErrorData(dynamic rawData) {
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is Map) {
      return rawData.map((key, value) => MapEntry(key.toString(), value));
    }
    if (rawData is String) {
      final trimmed = rawData.trim();
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

  static List<String> _extractDetails(Map<String, dynamic>? data) {
    if (data == null) {
      return const [];
    }
    final details = data['details'];
    if (details is! List) {
      return const [];
    }
    return details
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

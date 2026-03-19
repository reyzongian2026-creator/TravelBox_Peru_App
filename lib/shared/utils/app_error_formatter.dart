import 'dart:convert';

import 'package:dio/dio.dart';

import 'app_exception.dart';

class AppErrorFormatter {
  const AppErrorFormatter._();

  static String readable(
    Object error, {
    String fallback = 'Ocurrio un error inesperado.',
  }) {
    if (error is AppException) {
      final message = error.message.trim();
      return message.isEmpty ? fallback : message;
    }

    if (error is DioException) {
      final response = error.response;
      final statusCode = response?.statusCode;
      final data = _normalizeErrorData(response?.data);
      final backendMessage = data?['message']?.toString().trim();
      final parsedDetails = _extractDetails(data);

      if (statusCode == 429) {
        final retryAfter = _extractRetryAfterSeconds(response?.headers);
        if (retryAfter != null && retryAfter > 0) {
          return 'Demasiados intentos. Espera ${retryAfter}s e intenta nuevamente.';
        }
        if (backendMessage != null && backendMessage.isNotEmpty) {
          return backendMessage;
        }
        return 'Demasiados intentos. Intenta nuevamente en unos minutos.';
      }

      if (parsedDetails.isNotEmpty) {
        if (backendMessage != null && backendMessage.isNotEmpty) {
          return '$backendMessage ${parsedDetails.join(' | ')}';
        }
        return parsedDetails.join(' | ');
      }
      if (backendMessage != null && backendMessage.isNotEmpty) {
        return backendMessage;
      }

      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    final text = error.toString().replaceFirst('Exception: ', '').trim();
    final lowered = text.toLowerCase();
    if (lowered.contains('firebase_auth/operation-not-allowed') ||
        lowered.contains('identity provider configuration is not found')) {
      return 'El proveedor social aun no esta habilitado en Firebase Auth (Google/Facebook).';
    }
    if (lowered.contains('firebase_auth/unauthorized-domain') ||
        lowered.contains('unauthorized-domain')) {
      return 'Este dominio no esta autorizado en Firebase Auth. Agrega tu dominio de Cloud Run en Authorized domains.';
    }
    if (lowered.contains('invalid scopes') && lowered.contains('email')) {
      return 'Facebook rechazo el scope email para esta app. Ajusta permisos en Meta Developers o usa solo public_profile.';
    }
    if (lowered.contains('firebase_auth/channel-error') &&
        lowered.contains('signinwithprovider')) {
      return 'El flujo social movil no esta listo para este proveedor. Actualiza la configuracion nativa.';
    }
    if (lowered.contains('missingpluginexception') &&
        lowered.contains('flutter_facebook_auth')) {
      return 'Facebook Sign-In no esta disponible en este build. Reinicia la app completa o valida la configuracion nativa.';
    }
    if (lowered.contains('firebase_facebook_app_id')) {
      return 'Falta FIREBASE_FACEBOOK_APP_ID en el build web. El login de Facebook no puede inicializarse.';
    }
    if (lowered.contains('googlesigninexceptioncode.canceled') ||
        lowered.contains('account reauth failed')) {
      return 'El inicio con Google fue cancelado o no se pudo completar en este dispositivo. Intenta nuevamente.';
    }
    if (lowered.contains('timeoutexception') &&
        (lowered.contains('social') || lowered.contains('sesion'))) {
      return 'El proveedor social tardo demasiado en responder. Intenta nuevamente.';
    }
    if (lowered.contains('core/no-app') ||
        lowered.contains('no firebase app') ||
        lowered.contains('firebase.initializeapp')) {
      return 'Firebase no se inicializo en esta app. Revisa las variables FIREBASE_* y vuelve a ejecutar el build.';
    }
    final match = RegExp(r'message[=:]\s*([^,}]+)').firstMatch(text);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return text.isEmpty ? fallback : text;
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

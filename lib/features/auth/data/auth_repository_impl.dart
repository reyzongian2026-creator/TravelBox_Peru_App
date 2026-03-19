import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/utils/app_exception.dart';
import 'firebase_client_auth_service.dart';
import '../domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(dioProvider),
    ref.watch(firebaseClientAuthServiceProvider),
  );
});

final firebaseClientAuthServiceProvider = Provider<FirebaseClientAuthService>((
  ref,
) {
  return FirebaseClientAuthService();
});

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio, this._firebaseClientAuthService);

  final Dio _dio;
  final FirebaseClientAuthService _firebaseClientAuthService;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return _mapSession(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      if (!_canUseMockFallbackForError(error)) {
        throw AppException.fromDioError(error);
      }
      _warnMockFallback('login', error);
      return _mockSession(email: email);
    } catch (error) {
      if (!_allowStrictMockFallback) {
        throw AppException.fromError(error);
      }
      _warnMockFallback('login', error);
      return _mockSession(email: email);
    }
  }

  @override
  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmPassword,
    required String nationality,
    required String preferredLanguage,
    required String phone,
    required bool termsAccepted,
    String? profilePhotoPath,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': password,
          'confirmPassword': confirmPassword,
          'nationality': nationality,
          'preferredLanguage': preferredLanguage,
          'phone': phone,
          'termsAccepted': termsAccepted,
          if (profilePhotoPath?.trim().isNotEmpty == true)
            'profilePhotoPath': profilePhotoPath!.trim(),
        },
      );
      return _mapSession(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      if (statusCode == 404 || statusCode == 405 || statusCode == 501) {
        throw UnsupportedError(
          'El backend actual no expone registro publico. Usa credenciales demo o habilita /auth/register.',
        );
      }
      if (!_canUseMockFallbackForError(error)) {
        throw AppException.fromDioError(error);
      }
      _warnMockFallback('register', error);
      return _mockSession(
        email: email,
        name: '$firstName $lastName',
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        nationality: nationality,
        preferredLanguage: preferredLanguage,
        verified: false,
        verificationCodePreview: '123456',
      );
    } catch (error) {
      if (!_allowStrictMockFallback) {
        throw AppException.fromError(error);
      }
      _warnMockFallback('register', error);
      return _mockSession(
        email: email,
        name: '$firstName $lastName',
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        nationality: nationality,
        preferredLanguage: preferredLanguage,
        verified: false,
        verificationCodePreview: '123456',
      );
    }
  }

  @override
  Future<AuthSession> signInWithSocial({
    required String provider,
    required bool termsAccepted,
  }) async {
    final socialProvider = switch (provider.trim().toUpperCase()) {
      'GOOGLE' => SocialAuthProvider.google,
      'FACEBOOK' => SocialAuthProvider.facebook,
      _ => throw UnsupportedError('Proveedor social no soportado: $provider'),
    };
    final socialResult = await _firebaseClientAuthService.signIn(
      socialProvider,
    );
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/firebase/social',
        data: {
          'idToken': socialResult.idToken,
          'provider': socialResult.provider.backendCode,
          'termsAccepted': termsAccepted,
          if (socialResult.displayName?.trim().isNotEmpty == true)
            'displayName': socialResult.displayName!.trim(),
          if (socialResult.photoUrl?.trim().isNotEmpty == true)
            'profilePhotoUrl': socialResult.photoUrl!.trim(),
        },
      );
      return _mapSession(response.data ?? <String, dynamic>{});
    } catch (error) {
      await _firebaseClientAuthService.signOut();
      if (error is DioException) {
        throw AppException.fromDioError(error);
      }
      throw AppException.fromError(error);
    }
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      return _mapSession(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw AppException.fromDioError(error);
    }
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    DioException? dioError;
    try {
      await _dio.post<void>(
        '/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } on DioException catch (error) {
      dioError = error;
    } finally {
      await _firebaseClientAuthService.signOut();
    }
    if (dioError != null) {
      throw AppException.fromDioError(dioError);
    }
  }

  @override
  Future<EmailVerificationResult> verifyEmail({
    required String code,
    String? email,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/verify-email',
        data: {
          'code': code,
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        },
      );
      final data = response.data ?? <String, dynamic>{};
      return EmailVerificationResult(
        emailVerified: data['emailVerified'] as bool? ?? true,
        message: data['message']?.toString() ?? 'Correo verificado.',
        verificationCodePreview: data['verificationCodePreview']?.toString(),
      );
    } on DioException catch (error) {
      if (!_canUseMockFallbackForError(error)) {
        throw AppException.fromDioError(error);
      }
      _warnMockFallback('verifyEmail', error);
      return const EmailVerificationResult(
        emailVerified: true,
        message: 'Correo verificado en modo mock.',
      );
    } catch (error) {
      if (!_allowStrictMockFallback) {
        throw AppException.fromError(error);
      }
      _warnMockFallback('verifyEmail', error);
      return const EmailVerificationResult(
        emailVerified: true,
        message: 'Correo verificado en modo mock.',
      );
    }
  }

  @override
  Future<EmailVerificationResult> resendVerification() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/resend-verification',
      );
      final data = response.data ?? <String, dynamic>{};
      return EmailVerificationResult(
        emailVerified: data['emailVerified'] as bool? ?? false,
        message: data['message']?.toString() ?? 'Se envio un nuevo codigo.',
        verificationCodePreview: data['verificationCodePreview']?.toString(),
      );
    } on DioException catch (error) {
      if (!_canUseMockFallbackForError(error)) {
        throw AppException.fromDioError(error);
      }
      _warnMockFallback('resendVerification', error);
      return const EmailVerificationResult(
        emailVerified: false,
        message: 'Codigo reenviado en modo mock.',
        verificationCodePreview: '123456',
      );
    } catch (error) {
      if (!_allowStrictMockFallback) {
        throw AppException.fromError(error);
      }
      _warnMockFallback('resendVerification', error);
      return const EmailVerificationResult(
        emailVerified: false,
        message: 'Codigo reenviado en modo mock.',
        verificationCodePreview: '123456',
      );
    }
  }

  @override
  Future<PasswordResetResult> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/password-reset/request',
        data: {'email': email.trim()},
      );
      final data = response.data ?? <String, dynamic>{};
      return PasswordResetResult(
        message:
            data['message']?.toString() ??
            'Si el correo existe, se envio un codigo de recuperacion.',
        resetCodePreview: data['resetCodePreview']?.toString(),
        expiresAtIso: data['expiresAt']?.toString(),
      );
    } on DioException catch (error) {
      if (!_canUseMockFallbackForError(error)) {
        throw AppException.fromDioError(error);
      }
      _warnMockFallback('requestPasswordReset', error);
      return const PasswordResetResult(
        message: 'Codigo de recuperacion generado en modo mock.',
        resetCodePreview: '123456',
      );
    } catch (error) {
      if (!_allowStrictMockFallback) {
        throw AppException.fromError(error);
      }
      _warnMockFallback('requestPasswordReset', error);
      return const PasswordResetResult(
        message: 'Codigo de recuperacion generado en modo mock.',
        resetCodePreview: '123456',
      );
    }
  }

  @override
  Future<PasswordResetResult> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/password-reset/confirm',
        data: {
          'email': email.trim(),
          'code': code.trim(),
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      return PasswordResetResult(
        message:
            data['message']?.toString() ??
            'Contrasena actualizada correctamente.',
      );
    } on DioException catch (error) {
      if (!_canUseMockFallbackForError(error)) {
        throw AppException.fromDioError(error);
      }
      _warnMockFallback('confirmPasswordReset', error);
      return const PasswordResetResult(
        message: 'Contrasena actualizada en modo mock.',
      );
    } catch (error) {
      if (!_allowStrictMockFallback) {
        throw AppException.fromError(error);
      }
      _warnMockFallback('confirmPasswordReset', error);
      return const PasswordResetResult(
        message: 'Contrasena actualizada en modo mock.',
      );
    }
  }

  AuthSession _mapSession(Map<String, dynamic> data) {
    final accessToken =
        data['accessToken']?.toString() ??
        data['access_token']?.toString() ??
        data['token']?.toString() ??
        '';
    final refreshToken =
        data['refreshToken']?.toString() ??
        data['refresh_token']?.toString() ??
        '';
    final normalizedAccessToken = accessToken.trim();
    final normalizedRefreshToken = refreshToken.trim();
    if (normalizedAccessToken.isEmpty || normalizedRefreshToken.isEmpty) {
      if (!_allowStrictMockFallback) {
        throw StateError(
          'Respuesta de autenticacion invalida: faltan accessToken/refreshToken.',
        );
      }
      _warnMockFallback(
        'mapSession',
        StateError('Auth response without access/refresh tokens.'),
      );
    }

    final userJson =
        data['user'] as Map<String, dynamic>? ??
        {
          'id': data['userId'] ?? data['id'],
          'name':
              data['name'] ??
              data['fullName'] ??
              _nameFromEmail(data['email']?.toString()),
          'email': data['email'],
          'role': data['role'],
          'roles': data['roles'],
          'phone': data['phone'],
          'nationality': data['nationality'],
          'preferredLanguage': data['preferredLanguage'],
          'emailVerified': data['emailVerified'],
          'profileCompleted': data['profileCompleted'],
        };

    return AuthSession(
      user: AppUser.fromJson(userJson),
      accessToken: normalizedAccessToken.isNotEmpty
          ? normalizedAccessToken
          : 'mock-access-token',
      refreshToken: normalizedRefreshToken.isNotEmpty
          ? normalizedRefreshToken
          : 'mock-refresh-token',
      verificationCodePreview: data['verificationCodePreview']?.toString(),
    );
  }

  String _nameFromEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Usuario TravelBox';
    }
    final username = email.split('@').first.trim();
    if (username.isEmpty) {
      return 'Usuario TravelBox';
    }
    return username[0].toUpperCase() + username.substring(1);
  }

  AuthSession _mockSession({
    required String email,
    String? name,
    String? firstName,
    String? lastName,
    String? phone,
    String? nationality,
    String? preferredLanguage,
    bool verified = true,
    String? verificationCodePreview,
  }) {
    final emailLower = email.toLowerCase();
    final role = emailLower.contains('admin')
        ? UserRole.admin
        : emailLower.contains('oper')
        ? UserRole.operator
        : emailLower.contains('support')
        ? UserRole.support
        : UserRole.client;

    return AuthSession(
      user: AppUser(
        id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
        name: name ?? 'Usuario TravelBox',
        email: email,
        role: role,
        firstName: firstName ?? '',
        lastName: lastName ?? '',
        phone: phone ?? '',
        nationality: nationality ?? '',
        preferredLanguage: preferredLanguage ?? 'es',
        emailVerified: verified,
        profileCompleted:
            (firstName?.isNotEmpty ?? false) &&
            (lastName?.isNotEmpty ?? false) &&
            (phone?.isNotEmpty ?? false) &&
            (nationality?.isNotEmpty ?? false),
      ),
      accessToken: 'local-token-${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'local-refresh-${DateTime.now().millisecondsSinceEpoch}',
      verificationCodePreview: verificationCodePreview,
    );
  }

  bool get _allowStrictMockFallback {
    if (!AppEnv.useMockFallback) {
      return false;
    }
    final uri = Uri.tryParse(AppEnv.apiBaseUrl);
    final host = uri?.host.trim().toLowerCase() ?? '';
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2' ||
        host == '10.0.3.2';
  }

  bool _canUseMockFallbackForError(DioException error) {
    if (!_allowStrictMockFallback) {
      return false;
    }
    final statusCode = error.response?.statusCode;
    if (statusCode == null) {
      return true;
    }
    if (statusCode >= 500) {
      return true;
    }
    return statusCode == 404 || statusCode == 405 || statusCode == 501;
  }

  void _warnMockFallback(String flow, Object error) {
    debugPrint(
      '[AuthRepositoryImpl] Mock fallback activo en $flow. '
      'Revisa backend/config para evitar ocultar fallos reales. Error: $error',
    );
  }
}

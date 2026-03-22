import '../../../shared/models/app_user.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    this.verificationCodePreview,
  });

  final AppUser user;
  final String accessToken;
  final String refreshToken;
  final String? verificationCodePreview;
}

class EmailVerificationResult {
  const EmailVerificationResult({
    required this.emailVerified,
    required this.message,
    this.verificationCodePreview,
  });

  final bool emailVerified;
  final String message;
  final String? verificationCodePreview;
}

class PasswordResetResult {
  const PasswordResetResult({
    required this.message,
    this.resetCodePreview,
    this.expiresAtIso,
  });

  final String message;
  final String? resetCodePreview;
  final String? expiresAtIso;
}

abstract class AuthRepository {
  Future<AuthSession> login({required String email, required String password});

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
  });

  Future<AuthSession> signInWithSocial({
    required String provider,
    required bool termsAccepted,
  });

  Future<AuthSession> refresh({required String refreshToken});

  Future<void> logout({required String refreshToken});

  Future<EmailVerificationResult> verifyEmail({
    required String code,
    String? email,
  });

  Future<EmailVerificationResult> resendVerification();

  Future<PasswordResetResult> requestPasswordReset({required String email});

  Future<PasswordResetResult> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
    required String confirmPassword,
  });

  Future<EmailChangeResult> initiateEmailChange({required String newEmail});

  Future<EmailChangeResult> verifyEmailChange({
    required String code,
    required String newEmail,
  });
}

class EmailChangeResult {
  const EmailChangeResult({
    required this.success,
    required this.message,
    this.expiresAtIso,
  });

  final bool success;
  final String message;
  final String? expiresAtIso;
}

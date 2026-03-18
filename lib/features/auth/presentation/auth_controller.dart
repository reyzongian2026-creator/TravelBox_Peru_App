import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/session_controller.dart';
import '../data/auth_repository_impl.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      return AuthController(ref);
    });

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await _ref
          .read(authRepositoryProvider)
          .login(email: email.trim(), password: password);
      await _ref
          .read(sessionControllerProvider.notifier)
          .signIn(
            user: session.user,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            pendingVerificationCode: session.verificationCodePreview,
          );
    });
  }

  Future<void> register({
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await _ref
          .read(authRepositoryProvider)
          .register(
            firstName: firstName.trim(),
            lastName: lastName.trim(),
            email: email.trim(),
            password: password,
            confirmPassword: confirmPassword,
            nationality: nationality.trim(),
            preferredLanguage: preferredLanguage.trim(),
            phone: phone.trim(),
            termsAccepted: termsAccepted,
            profilePhotoPath: profilePhotoPath?.trim(),
          );
      await _ref
          .read(sessionControllerProvider.notifier)
          .signIn(
            user: session.user,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            pendingVerificationCode: session.verificationCodePreview,
          );
    });
  }

  Future<void> signInWithSocial({
    required String provider,
    required bool termsAccepted,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await _ref
          .read(authRepositoryProvider)
          .signInWithSocial(
            provider: provider,
            termsAccepted: termsAccepted,
          );
      await _ref
          .read(sessionControllerProvider.notifier)
          .signIn(
            user: session.user,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            pendingVerificationCode: session.verificationCodePreview,
          );
    });
  }
}


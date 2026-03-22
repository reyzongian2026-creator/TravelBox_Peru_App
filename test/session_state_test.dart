import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelbox_peru_app/shared/models/app_user.dart';
import 'package:travelbox_peru_app/shared/state/session_controller.dart';

void main() {
  const user = AppUser(
    id: '1',
    name: 'Admin',
    email: 'admin@travelbox.pe',
    role: UserRole.admin,
  );

  test('isAuthenticated is false with empty token', () {
    const state = SessionState(
      locale: Locale('es'),
      sessionLanguage: 'es',
      user: user,
      accessToken: '',
      refreshToken: 'refresh',
      pendingVerificationCode: null,
      onboardingCompleted: false,
    );

    expect(state.isAuthenticated, isFalse);
  });

  test('isAuthenticated is false with malformed token', () {
    const state = SessionState(
      locale: Locale('es'),
      sessionLanguage: 'es',
      user: user,
      accessToken: 'not-a-jwt',
      refreshToken: 'refresh',
      pendingVerificationCode: null,
      onboardingCompleted: false,
    );

    expect(state.isAuthenticated, isFalse);
  });

  test('isAuthenticated is true with jwt-like token', () {
    const state = SessionState(
      locale: Locale('es'),
      sessionLanguage: 'es',
      user: user,
      accessToken: 'aaa.bbb.ccc',
      refreshToken: 'refresh',
      pendingVerificationCode: null,
      onboardingCompleted: false,
    );

    expect(state.isAuthenticated, isTrue);
  });
}

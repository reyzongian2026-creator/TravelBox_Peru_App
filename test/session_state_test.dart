import 'dart:convert';

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
      isReady: true,
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
      isReady: true,
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

  test('isAuthenticated is false with expired jwt', () {
    final state = SessionState(
      isReady: true,
      locale: const Locale('es'),
      sessionLanguage: 'es',
      user: user,
      accessToken: _buildJwt(
        exp: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60,
      ),
      refreshToken: 'refresh',
      pendingVerificationCode: null,
      onboardingCompleted: false,
    );

    expect(state.isAuthenticated, isFalse);
  });

  test('isAuthenticated is true with non-expired jwt', () {
    final state = SessionState(
      isReady: true,
      locale: const Locale('es'),
      sessionLanguage: 'es',
      user: user,
      accessToken: _buildJwt(
        exp: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      ),
      refreshToken: 'refresh',
      pendingVerificationCode: null,
      onboardingCompleted: false,
    );

    expect(state.isAuthenticated, isTrue);
  });
}

String _buildJwt({required int exp}) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'sub': 'test-user', 'iat': exp - 1800, 'exp': exp}),
        ),
      )
      .replaceAll('=', '');
  return '$header.$payload.signature';
}

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/env/app_env.dart';
import '../models/app_user.dart';
import 'session_token_storage.dart';

const _sessionKey = 'travelbox.session.v2';
const _onboardingCompletedUsersKey = 'travelbox.onboarding.completed.users.v1';
const _onboardingStatusPath = '/profile/me/onboarding-status';
const _onboardingCompletePath = '/profile/me/onboarding-complete';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences provider no inicializado.');
});

final sessionTokenStorageProvider = Provider<SessionTokenStorage>((ref) {
  throw UnimplementedError('SessionTokenStorage provider no inicializado.');
});

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final tokenStorage = ref.watch(sessionTokenStorageProvider);
      return SessionController(prefs, tokenStorage);
    });

class SessionState {
  const SessionState({
    required this.locale,
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.pendingVerificationCode,
    required this.onboardingCompleted,
  });

  factory SessionState.initial() {
    return const SessionState(
      locale: Locale('es'),
      user: null,
      accessToken: null,
      refreshToken: null,
      pendingVerificationCode: null,
      onboardingCompleted: false,
    );
  }

  final Locale locale;
  final AppUser? user;
  final String? accessToken;
  final String? refreshToken;
  final String? pendingVerificationCode;
  final bool onboardingCompleted;

  bool get isAuthenticated =>
      user != null && _hasUsableAccessToken(accessToken);
  bool get isAdmin => user?.role.isAdmin ?? false;
  bool get isCourier => user?.role.isCourier ?? false;
  bool get isSupport => user?.role.isSupport ?? false;
  bool get canAccessAdmin => user?.role.canAccessBackoffice ?? false;
  bool get needsEmailVerification =>
      isAuthenticated && !(user?.emailVerified ?? true);
  bool get needsProfileCompletion =>
      isAuthenticated &&
      (user?.emailVerified ?? false) &&
      !(user?.profileCompleted ?? true);
  bool get needsOnboarding =>
      isAuthenticated &&
      (user?.emailVerified ?? false) &&
      (user?.role == UserRole.client) &&
      !onboardingCompleted;

  SessionState copyWith({
    Locale? locale,
    AppUser? user,
    String? accessToken,
    String? refreshToken,
    String? pendingVerificationCode,
    bool? onboardingCompleted,
    bool clearSession = false,
  }) {
    if (clearSession) {
      return SessionState(
        locale: locale ?? this.locale,
        user: null,
        accessToken: null,
        refreshToken: null,
        pendingVerificationCode: null,
        onboardingCompleted: false,
      );
    }
    return SessionState(
      locale: locale ?? this.locale,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      pendingVerificationCode:
          pendingVerificationCode ?? this.pendingVerificationCode,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locale': locale.languageCode,
      'user': user?.toJson(),
      'pendingVerificationCode': pendingVerificationCode,
      'onboardingCompleted': onboardingCompleted,
    };
  }

  factory SessionState.fromJson(Map<String, dynamic> json) {
    return SessionState(
      locale: Locale(json['locale']?.toString() ?? 'es'),
      user: json['user'] == null
          ? null
          : AppUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken']?.toString(),
      refreshToken: json['refreshToken']?.toString(),
      pendingVerificationCode: json['pendingVerificationCode']?.toString(),
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._prefs, this._tokenStorage)
    : _onboardingCompletedUsers = _loadOnboardingCompletedUsers(_prefs),
      super(SessionState.initial()) {
    _restore();
  }

  final SharedPreferences _prefs;
  final SessionTokenStorage _tokenStorage;
  final Set<String> _onboardingCompletedUsers;

  Future<void> _restore() async {
    final raw = _prefs.getString(_sessionKey);
    if (raw == null) {
      await _tokenStorage.clearTokens();
      return;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final restoredStateFromPrefs = SessionState.fromJson(json);
      final secureAccessToken = await _tokenStorage.readAccessToken();
      final secureRefreshToken = await _tokenStorage.readRefreshToken();

      final restoredState = restoredStateFromPrefs.copyWith(
        accessToken:
            _firstNonEmptyToken(
              secureAccessToken,
              restoredStateFromPrefs.accessToken,
            ) ??
            '',
        refreshToken: _firstNonEmptyToken(
          secureRefreshToken,
          restoredStateFromPrefs.refreshToken,
        ),
      );

      final missingSecureAccess = secureAccessToken?.trim().isEmpty ?? true;
      final missingSecureRefresh = secureRefreshToken?.trim().isEmpty ?? true;
      final requiresTokenMigration =
          (missingSecureAccess &&
              _hasUsableAccessToken(restoredStateFromPrefs.accessToken)) ||
          (missingSecureRefresh &&
              (restoredStateFromPrefs.refreshToken?.trim().isNotEmpty ??
                  false));
      if (requiresTokenMigration) {
        await _tokenStorage.writeTokens(
          accessToken: restoredStateFromPrefs.accessToken,
          refreshToken: restoredStateFromPrefs.refreshToken,
        );
      }

      if (!_hasUsableAccessToken(restoredState.accessToken)) {
        await _prefs.remove(_sessionKey);
        await _tokenStorage.clearTokens();
        return;
      }
      var normalizedState = _normalizeRoleFromAccessToken(restoredState)
          .copyWith(
            onboardingCompleted: _isOnboardingCompleted(restoredState.user),
          );
      final backendOnboardingCompleted =
          await _fetchOnboardingCompletedFromBackend(
            user: normalizedState.user,
            accessToken: normalizedState.accessToken,
          );
      if (backendOnboardingCompleted != null) {
        normalizedState = normalizedState.copyWith(
          onboardingCompleted: backendOnboardingCompleted,
        );
      }
      state = normalizedState;
      if (requiresTokenMigration ||
          normalizedState.user?.role != restoredState.user?.role ||
          backendOnboardingCompleted != null) {
        await _persist();
      }
    } catch (_) {
      await _prefs.remove(_sessionKey);
      await _tokenStorage.clearTokens();
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(_sessionKey, jsonEncode(state.toJson()));
    await _tokenStorage.writeTokens(
      accessToken: state.accessToken,
      refreshToken: state.refreshToken,
    );
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: _normalizeLocale(locale.languageCode));
    await _persist();
  }

  Future<void> signIn({
    required AppUser user,
    required String accessToken,
    required String refreshToken,
    String? pendingVerificationCode,
  }) async {
    if (!_hasUsableAccessToken(accessToken)) {
      state = state.copyWith(clearSession: true);
      await _persist();
      return;
    }

    final keepCurrentLocale =
        state.isAuthenticated &&
        state.user != null &&
        state.user!.id == user.id &&
        state.locale.languageCode.trim().isNotEmpty;
    final nextLocale = keepCurrentLocale
        ? state.locale
        : _normalizeLocale(user.preferredLanguage);
    var nextState = state.copyWith(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      locale: nextLocale,
      pendingVerificationCode: pendingVerificationCode,
      onboardingCompleted: _isOnboardingCompleted(user),
    );
    nextState = _normalizeRoleFromAccessToken(nextState);
    final backendOnboardingCompleted =
        await _fetchOnboardingCompletedFromBackend(
          user: nextState.user,
          accessToken: nextState.accessToken,
        );
    if (backendOnboardingCompleted != null) {
      nextState = nextState.copyWith(
        onboardingCompleted: backendOnboardingCompleted,
      );
    }
    state = nextState;
    await _persist();
  }

  Future<void> updateUser(
    AppUser user, {
    String? pendingVerificationCode,
    bool clearPendingVerificationCode = false,
  }) async {
    state = state.copyWith(
      user: user,
      locale: state.locale,
      pendingVerificationCode: clearPendingVerificationCode
          ? null
          : (pendingVerificationCode ?? state.pendingVerificationCode),
      onboardingCompleted:
          state.onboardingCompleted || _isOnboardingCompleted(user),
    );
    await _persist();
  }

  Future<void> markEmailVerified() async {
    final currentUser = state.user;
    if (currentUser == null) return;
    state = state.copyWith(
      user: currentUser.copyWith(emailVerified: true),
      pendingVerificationCode: null,
    );
    await _persist();
  }

  Future<void> signOut() async {
    state = state.copyWith(clearSession: true);
    await _persist();
  }

  Future<void> completeOnboarding() async {
    final userId = state.user?.id.trim();
    if (userId == null || userId.isEmpty) {
      return;
    }
    await _markOnboardingCompletedLocally(userId);
    state = state.copyWith(onboardingCompleted: true);
    await _persist();
    unawaited(
      _persistOnboardingCompletedInBackend(
        userId: userId,
        accessToken: state.accessToken,
      ),
    );
  }

  SessionState _normalizeRoleFromAccessToken(SessionState currentState) {
    final token = currentState.accessToken;
    final user = currentState.user;
    if (token == null || token.isEmpty || user == null) {
      return currentState;
    }

    final tokenRole = _extractRoleFromJwt(token);
    if (tokenRole == null || tokenRole == user.role) {
      return currentState;
    }

    return currentState.copyWith(user: user.copyWith(role: tokenRole));
  }

  UserRole? _extractRoleFromJwt(String token) {
    try {
      final tokenParts = token.split('.');
      if (tokenParts.length < 2) {
        return null;
      }

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(tokenParts[1])),
      );
      final payloadMap = jsonDecode(payload);
      if (payloadMap is! Map<String, dynamic>) {
        return null;
      }

      final rawRoles = payloadMap['roles'];
      if (rawRoles is! Iterable) {
        return null;
      }

      final normalized = rawRoles
          .map((item) => item.toString().trim().toUpperCase())
          .toSet();
      if (normalized.contains('ROLE_ADMIN') || normalized.contains('ADMIN')) {
        return UserRole.admin;
      }
      if (normalized.contains('ROLE_SUPPORT') ||
          normalized.contains('SUPPORT')) {
        return UserRole.support;
      }
      if (normalized.contains('ROLE_COURIER') ||
          normalized.contains('COURIER')) {
        return UserRole.courier;
      }
      if (normalized.contains('ROLE_CITY_SUPERVISOR') ||
          normalized.contains('CITY_SUPERVISOR')) {
        return UserRole.citySupervisor;
      }
      if (normalized.contains('ROLE_OPERATOR') ||
          normalized.contains('OPERATOR')) {
        return UserRole.operator;
      }
      if (normalized.contains('ROLE_CLIENT') || normalized.contains('CLIENT')) {
        return UserRole.client;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isOnboardingCompleted(AppUser? user) {
    final userId = user?.id.trim();
    if (userId == null || userId.isEmpty) {
      return false;
    }
    return _onboardingCompletedUsers.contains(userId);
  }

  Future<void> _markOnboardingCompletedLocally(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (_onboardingCompletedUsers.add(normalized)) {
      await _prefs.setStringList(
        _onboardingCompletedUsersKey,
        _onboardingCompletedUsers.toList(),
      );
    }
  }

  Future<bool?> _fetchOnboardingCompletedFromBackend({
    required AppUser? user,
    required String? accessToken,
  }) async {
    final userId = user?.id.trim();
    final token = accessToken?.trim();
    if (userId == null || userId.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    final client = _buildOnboardingClient(token);
    try {
      final response = await client.get<Map<String, dynamic>>(
        _onboardingStatusPath,
      );
      final data = response.data ?? const <String, dynamic>{};
      final completed = _readBackendOnboardingFlag(data);
      if (completed == true) {
        await _markOnboardingCompletedLocally(userId);
      }
      return completed;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      if (statusCode == 404 || statusCode == 405 || statusCode == 501) {
        return null;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _persistOnboardingCompletedInBackend({
    required String userId,
    required String? accessToken,
  }) async {
    final token = accessToken?.trim();
    if (token == null || token.isEmpty) {
      return false;
    }
    final client = _buildOnboardingClient(token);
    try {
      final response = await client.post<Map<String, dynamic>>(
        _onboardingCompletePath,
      );
      final data = response.data ?? const <String, dynamic>{};
      final completed = _readBackendOnboardingFlag(data) ?? true;
      if (completed) {
        await _markOnboardingCompletedLocally(userId);
      }
      return completed;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      if (statusCode == 404 || statusCode == 405 || statusCode == 501) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Dio _buildOnboardingClient(String accessToken) {
    return Dio(
      BaseOptions(
        baseUrl: AppEnv.apiBaseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 6),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );
  }

  bool? _readBackendOnboardingFlag(Map<String, dynamic> json) {
    final raw = json['completed'] ?? json['onboardingCompleted'];
    if (raw is bool) {
      return raw;
    }
    final normalized = raw?.toString().trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
    return null;
  }

  static Set<String> _loadOnboardingCompletedUsers(SharedPreferences prefs) {
    final values =
        prefs.getStringList(_onboardingCompletedUsersKey) ?? const [];
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  String? _firstNonEmptyToken(String? primary, String? fallback) {
    final normalizedPrimary = primary?.trim();
    if (normalizedPrimary != null && normalizedPrimary.isNotEmpty) {
      return normalizedPrimary;
    }
    final normalizedFallback = fallback?.trim();
    if (normalizedFallback != null && normalizedFallback.isNotEmpty) {
      return normalizedFallback;
    }
    return null;
  }
}

const _supportedLanguageCodes = {'es', 'en', 'de', 'fr', 'it', 'pt'};

Locale _normalizeLocale(String? raw) {
  final code = raw?.trim().toLowerCase() ?? 'es';
  if (_supportedLanguageCodes.contains(code)) {
    return Locale(code);
  }
  return const Locale('es');
}

bool _hasUsableAccessToken(String? rawToken) {
  final token = rawToken?.trim() ?? '';
  if (token.isEmpty) {
    return false;
  }

  if (token.startsWith('mock-access-token') ||
      token.startsWith('local-token-')) {
    return _isMockTokenAllowed();
  }

  final segments = token.split('.');
  return segments.length == 3 &&
      segments.every((segment) => segment.trim().isNotEmpty);
}

bool _isMockTokenAllowed() {
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

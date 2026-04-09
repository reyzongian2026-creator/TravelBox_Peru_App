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
    required this.isReady,
    required this.locale,
    required this.sessionLanguage,
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.pendingVerificationCode,
    required this.onboardingCompleted,
  });

  factory SessionState.initial() {
    return const SessionState(
      isReady: false,
      locale: Locale('es'),
      sessionLanguage: 'es',
      user: null,
      accessToken: null,
      refreshToken: null,
      pendingVerificationCode: null,
      onboardingCompleted: false,
    );
  }

  final bool isReady;
  final Locale locale;
  final String sessionLanguage;
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
  bool get needsRealEmailCompletion =>
      isAuthenticated && (user?.requiresRealEmailCompletion ?? false);
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
    String? sessionLanguage,
    AppUser? user,
    String? accessToken,
    String? refreshToken,
    String? pendingVerificationCode,
    bool? onboardingCompleted,
    bool? isReady,
    bool clearSession = false,
  }) {
    if (clearSession) {
      return SessionState(
        isReady: isReady ?? this.isReady,
        locale: locale ?? this.locale,
        sessionLanguage: sessionLanguage ?? this.sessionLanguage,
        user: null,
        accessToken: null,
        refreshToken: null,
        pendingVerificationCode: null,
        onboardingCompleted: false,
      );
    }
    return SessionState(
      isReady: isReady ?? this.isReady,
      locale: locale ?? this.locale,
      sessionLanguage: sessionLanguage ?? this.sessionLanguage,
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
      'sessionLanguage': sessionLanguage,
      'user': user?.toJson(),
      'pendingVerificationCode': pendingVerificationCode,
      'onboardingCompleted': onboardingCompleted,
    };
  }

  factory SessionState.fromJson(Map<String, dynamic> json) {
    // Use saved locale and sessionLanguage if available, otherwise default to Spanish
    final savedLocaleCode = json['locale']?.toString().trim().toLowerCase();
    final savedSessionLang = json['sessionLanguage']
        ?.toString()
        .trim()
        .toLowerCase();

    Locale finalLocale;
    String finalSessionLang;

    if (savedLocaleCode != null &&
        savedLocaleCode.isNotEmpty &&
        _supportedLanguageCodes.contains(savedLocaleCode)) {
      finalLocale = Locale(savedLocaleCode);
    } else {
      finalLocale = const Locale('es');
    }

    if (savedSessionLang != null &&
        savedSessionLang.isNotEmpty &&
        _supportedLanguageCodes.contains(savedSessionLang)) {
      finalSessionLang = savedSessionLang;
    } else {
      finalSessionLang = 'es';
    }

    return SessionState(
      isReady: json['isReady'] as bool? ?? false,
      locale: finalLocale,
      sessionLanguage: finalSessionLang,
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
  Timer? _proactiveRefreshTimer;

  @override
  void dispose() {
    _proactiveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    final raw = _prefs.getString(_sessionKey);
    if (raw == null) {
      await _tokenStorage.clearTokens();
      state = state.copyWith(isReady: true);
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

      if (!_hasJwtLikeAccessToken(restoredState.accessToken)) {
        await _prefs.remove(_sessionKey);
        await _tokenStorage.clearTokens();
        state = state.copyWith(isReady: true);
        return;
      }
      var refreshedExpiredSession = false;
      var effectiveState = restoredState;
      if (!_hasUsableAccessToken(effectiveState.accessToken)) {
        final refreshedTokens = await _requestTokenRefresh(
          effectiveState.refreshToken,
        );
        if (refreshedTokens == null) {
          await _prefs.remove(_sessionKey);
          await _tokenStorage.clearTokens();
          state = state.copyWith(isReady: true);
          return;
        }
        effectiveState = effectiveState.copyWith(
          accessToken: refreshedTokens.accessToken,
          refreshToken: refreshedTokens.refreshToken,
        );
        refreshedExpiredSession = true;
      }

      var normalizedState = _normalizeRoleFromAccessToken(effectiveState)
          .copyWith(
            isReady: true,
            onboardingCompleted: _isOnboardingCompleted(effectiveState.user),
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
          refreshedExpiredSession ||
          normalizedState.user?.role != restoredState.user?.role ||
          backendOnboardingCompleted != null) {
        await _persist();
      }
      _scheduleProactiveRefresh();
    } catch (_) {
      await _prefs.remove(_sessionKey);
      await _tokenStorage.clearTokens();
      state = state.copyWith(isReady: true);
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
    final normalizedLocale = _normalizeLocale(locale.languageCode);
    state = state.copyWith(
      locale: normalizedLocale,
      sessionLanguage: normalizedLocale.languageCode,
    );
    await _persist();
  }

  Future<void> setSessionLanguage(String languageCode) async {
    final normalized = _normalizeSessionLanguage(languageCode);
    state = state.copyWith(
      sessionLanguage: normalized,
      locale: Locale(normalized),
    );
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

    // Always default to Spanish, only use user preferredLanguage if explicitly set
    final userPreferredLang = user.preferredLanguage.trim().toLowerCase();
    final isValidUserLang =
        userPreferredLang.isNotEmpty &&
        userPreferredLang != 'es' &&
        _supportedLanguageCodes.contains(userPreferredLang);

    final nextLocale = keepCurrentLocale
        ? state.locale
        : (isValidUserLang
              ? _normalizeLocale(userPreferredLang)
              : const Locale('es'));

    var nextState = state.copyWith(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      locale: nextLocale,
      sessionLanguage: isValidUserLang
          ? userPreferredLang
          : 'es', // Sync sessionLanguage
      pendingVerificationCode: pendingVerificationCode,
      onboardingCompleted: _isOnboardingCompleted(user),
      isReady: true,
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
    _scheduleProactiveRefresh();
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
      isReady: true,
    );
    await _persist();
  }

  Future<void> markEmailVerified() async {
    final currentUser = state.user;
    if (currentUser == null) return;
    state = state.copyWith(
      user: currentUser.copyWith(
        email: currentUser.pendingRealEmail ?? currentUser.email,
        emailVerified: true,
        requiresRealEmailCompletion: false,
        pendingRealEmail: null,
      ),
      pendingVerificationCode: null,
      isReady: true,
    );
    await _persist();
  }

  Future<void> signOut() async {
    _proactiveRefreshTimer?.cancel();
    _proactiveRefreshTimer = null;
    state = state.copyWith(
      clearSession: true,
      sessionLanguage: 'es',
      isReady: true,
    );
    await _persist();
    // Clear reservation cache on logout
    await _prefs.remove('travelbox.reservations.v2');
    await _prefs.remove('travelbox.reservations.v1');
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

  void _scheduleProactiveRefresh() {
    _proactiveRefreshTimer?.cancel();
    _proactiveRefreshTimer = null;

    final token = state.accessToken;
    if (token == null || token.isEmpty) return;
    if (_isTokenExpired(token, leewaySeconds: 30)) {
      unawaited(_performProactiveRefresh());
      return;
    }

    final exp = _extractExpFromJwt(token);
    final iat = _extractIatFromJwt(token);
    if (exp == null) return;

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    int delaySeconds;
    if (iat != null && exp > iat) {
      // Refresh at 75% of token lifetime (Facebook-style proactive refresh)
      // For a 30-min token: refresh after ~22.5 min (7.5 min before expiry)
      final totalLifetime = exp - iat;
      final refreshAt = iat + (totalLifetime * 3 ~/ 4);
      delaySeconds = refreshAt - nowSec;
    } else {
      // Fallback: refresh 2 minutes before expiry
      delaySeconds = exp - nowSec - 120;
    }

    if (delaySeconds <= 30) {
      unawaited(_performProactiveRefresh());
      return;
    }

    _proactiveRefreshTimer = Timer(
      Duration(seconds: delaySeconds.clamp(30, 86400)),
      () => unawaited(_performProactiveRefresh()),
    );
  }

  Future<void> _performProactiveRefresh() async {
    final currentRefreshToken = state.refreshToken?.trim();
    if (currentRefreshToken == null || currentRefreshToken.isEmpty) return;
    final refreshedTokens = await _requestTokenRefresh(currentRefreshToken);
    if (refreshedTokens == null) {
      return;
    }

    state = state.copyWith(
      accessToken: refreshedTokens.accessToken,
      refreshToken: refreshedTokens.refreshToken,
    );
    await _persist();
    _scheduleProactiveRefresh();
  }

  Future<String?> ensureFreshAccessToken({int leewaySeconds = 45}) async {
    final currentAccessToken = state.accessToken?.trim() ?? '';
    if (_hasUsableAccessToken(currentAccessToken) &&
        !_isTokenExpired(currentAccessToken, leewaySeconds: leewaySeconds)) {
      return currentAccessToken;
    }

    final currentRefreshToken = state.refreshToken?.trim() ?? '';
    if (currentRefreshToken.isEmpty) {
      return _hasUsableAccessToken(currentAccessToken)
          ? currentAccessToken
          : null;
    }

    final refreshedTokens = await _requestTokenRefresh(currentRefreshToken);
    if (refreshedTokens == null) {
      return _hasUsableAccessToken(currentAccessToken)
          ? currentAccessToken
          : null;
    }

    state = _normalizeRoleFromAccessToken(
      state.copyWith(
        accessToken: refreshedTokens.accessToken,
        refreshToken: refreshedTokens.refreshToken,
      ),
    );
    await _persist();
    _scheduleProactiveRefresh();
    return state.accessToken?.trim();
  }

  Future<_RefreshedTokens?> _requestTokenRefresh(String? refreshToken) async {
    final normalizedRefreshToken = refreshToken?.trim() ?? '';
    if (normalizedRefreshToken.isEmpty) {
      return null;
    }

    final client = Dio(
      BaseOptions(
        baseUrl: AppEnv.resolvedApiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    try {
      final response = await client.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': normalizedRefreshToken},
      );
      final data = response.data;
      if (data == null) {
        return null;
      }

      final newAccess = data['accessToken']?.toString().trim() ?? '';
      final refreshedRefreshToken =
          data['refreshToken']?.toString().trim() ?? '';
      final nextRefreshToken = refreshedRefreshToken.isNotEmpty
          ? refreshedRefreshToken
          : normalizedRefreshToken;
      if (!_hasUsableAccessToken(newAccess) || nextRefreshToken.isEmpty) {
        return null;
      }

      return _RefreshedTokens(
        accessToken: newAccess,
        refreshToken: nextRefreshToken,
      );
    } catch (_) {
      // Silently fail — the reactive 401 interceptor will handle it
      return null;
    } finally {
      client.close(force: true);
    }
  }

  int? _extractExpFromJwt(String token) {
    return _extractJwtIntClaim(token, 'exp');
  }

  int? _extractIatFromJwt(String token) {
    return _extractJwtIntClaim(token, 'iat');
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
    if (user?.requiresRealEmailCompletion == true ||
        !(user?.emailVerified ?? false)) {
      return null;
    }
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
        baseUrl: AppEnv.resolvedApiBaseUrl,
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

const _supportedLanguageCodes = {'es', 'en'};

Locale _normalizeLocale(String? raw) {
  final code = raw?.trim().toLowerCase() ?? 'es';
  if (_supportedLanguageCodes.contains(code)) {
    return Locale(code);
  }
  return const Locale('es');
}

String _normalizeSessionLanguage(String? raw) {
  final code = raw?.trim().toLowerCase() ?? 'es';
  if (_supportedLanguageCodes.contains(code)) {
    return code;
  }
  return 'es';
}

bool _hasJwtLikeAccessToken(String? rawToken) {
  final token = rawToken?.trim() ?? '';
  if (token.isEmpty) {
    return false;
  }

  if (_isMockAccessToken(token)) {
    return _isMockTokenAllowed();
  }

  final segments = token.split('.');
  return segments.length == 3 &&
      segments.every((segment) => segment.trim().isNotEmpty);
}

bool _hasUsableAccessToken(String? rawToken) {
  final token = rawToken?.trim() ?? '';
  if (!_hasJwtLikeAccessToken(token)) {
    return false;
  }
  if (_isMockAccessToken(token)) {
    return true;
  }

  final exp = _extractJwtIntClaim(token, 'exp');
  if (exp == null) {
    return true;
  }

  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return exp > nowSec + 15;
}

bool _isTokenExpired(String? rawToken, {int leewaySeconds = 0}) {
  final token = rawToken?.trim() ?? '';
  if (token.isEmpty || _isMockAccessToken(token)) {
    return false;
  }
  final exp = _extractJwtIntClaim(token, 'exp');
  if (exp == null) {
    return false;
  }
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return exp <= nowSec + leewaySeconds;
}

int? _extractJwtIntClaim(String token, String claim) {
  try {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final map = jsonDecode(payload);
    if (map is! Map<String, dynamic>) return null;
    final value = map[claim];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  } catch (_) {
    return null;
  }
}

bool _isMockAccessToken(String token) {
  return token.startsWith('mock-access-token') ||
      token.startsWith('local-token-');
}

bool _isMockTokenAllowed() {
  if (!AppEnv.useMockFallback) {
    return false;
  }
  final uri = Uri.tryParse(AppEnv.resolvedApiBaseUrl);
  final host = uri?.host.trim().toLowerCase() ?? '';
  return host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == '10.0.2.2' ||
      host == '10.0.3.2';
}

class _RefreshedTokens {
  const _RefreshedTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

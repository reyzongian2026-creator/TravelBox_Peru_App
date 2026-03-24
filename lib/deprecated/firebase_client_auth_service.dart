import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/env/app_env.dart';
import '../../../core/firebase/travelbox_firebase.dart';

enum SocialAuthProvider { google, facebook }

extension SocialAuthProviderX on SocialAuthProvider {
  String get backendCode {
    switch (this) {
      case SocialAuthProvider.google:
        return 'GOOGLE';
      case SocialAuthProvider.facebook:
        return 'FACEBOOK';
    }
  }

  String get label {
    switch (this) {
      case SocialAuthProvider.google:
        return 'Google';
      case SocialAuthProvider.facebook:
        return 'Facebook';
    }
  }
}

class FirebaseSocialSignInResult {
  const FirebaseSocialSignInResult({
    required this.idToken,
    required this.provider,
    this.displayName,
    this.photoUrl,
  });

  final String idToken;
  final SocialAuthProvider provider;
  final String? displayName;
  final String? photoUrl;
}

class FirebaseClientAuthService {
  FirebaseClientAuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth,
      _googleSignIn = GoogleSignIn.instance;

  FirebaseAuth? _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;
  bool _facebookWebInitialized = false;

  bool get isConfigured => TravelBoxFirebase.isConfigured;

  Future<FirebaseSocialSignInResult> signIn(SocialAuthProvider provider) async {
    if (!isConfigured) {
      throw UnsupportedError(
        'Firebase is not configured yet. Project keys are missing.',
      );
    }
    await TravelBoxFirebase.initializeIfConfigured();
    switch (provider) {
      case SocialAuthProvider.google:
        return _signInWithGoogle();
      case SocialAuthProvider.facebook:
        if (!AppEnv.firebaseFacebookProviderEnabled) {
          throw UnsupportedError('Facebook access is disabled in this build.');
        }
        return _signInWithFacebook();
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    if (_supportsFacebookPlugin) {
      try {
        await FacebookAuth.instance.logOut();
      } catch (_) {}
    }
    if (!isConfigured || Firebase.apps.isEmpty) {
      return;
    }
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  Future<FirebaseSocialSignInResult> _signInWithGoogle() async {
    final firebaseAuth = _auth;
    final userCredential = kIsWeb
        ? await firebaseAuth.signInWithPopup(GoogleAuthProvider())
        : await _signInWithGoogleOnMobile();
    return _toResult(userCredential, provider: SocialAuthProvider.google);
  }

  Future<UserCredential> _signInWithGoogleOnMobile() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _signInWithGoogleCredentialFlow();
      case TargetPlatform.iOS:
        return _signInWithGoogleCredentialFlow();
      default:
        throw UnsupportedError(
          'Google Firebase is only enabled on web, Android, and iOS.',
        );
    }
  }

  Future<UserCredential> _signInWithGoogleCredentialFlow() async {
    try {
      await _initializeGoogleSignIn();
      final account = await _googleSignIn.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final auth = account.authentication;
      if (auth.idToken == null || auth.idToken!.trim().isEmpty) {
        throw UnsupportedError(
          'Google did not return idToken. Configure FIREBASE_GOOGLE_SERVER_CLIENT_ID for Android.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
      return _auth.signInWithCredential(credential);
    } on MissingPluginException {
      throw UnsupportedError(
        'Google Sign-In is not available in this build/device.',
      );
    }
  }

  Future<FirebaseSocialSignInResult> _signInWithFacebook() async {
    if (!_supportsFacebookPlugin) {
      throw UnsupportedError(
        'Facebook Firebase is only enabled on web, Android, and iOS.',
      );
    }
    await _initializeFacebookWebIfNeeded();
    final userCredential = await _signInWithFacebookWithFallbackScopes();
    return _toResult(userCredential, provider: SocialAuthProvider.facebook);
  }

  Future<UserCredential> _signInWithFacebookWithFallbackScopes() async {
    final primaryPermissions = kIsWeb
        ? const <String>['email', 'public_profile']
        : const <String>['email', 'public_profile'];
    try {
      return await _signInWithFacebookPermissions(primaryPermissions);
    } catch (error) {
      if (!_isFacebookInvalidEmailScope(error)) {
        rethrow;
      }
      return _signInWithFacebookPermissions(const ['public_profile']);
    }
  }

  Future<UserCredential> _signInWithFacebookPermissions(
    List<String> permissions,
  ) async {
    try {
      final loginResult = await FacebookAuth.instance.login(
        permissions: permissions,
      );
      if (loginResult.status != LoginStatus.success ||
          loginResult.accessToken == null) {
        final reason = loginResult.message?.trim().isNotEmpty == true
            ? loginResult.message!.trim()
            : 'Could not authenticate with Facebook.';
        if (_looksLikeFacebookAppInactive(reason)) {
          throw UnsupportedError(
            'Facebook Login blocked: app is inactive or in development mode, '
            'or domains/redirect URI are missing. Activate the app in Meta for Developers '
            'and add the production web domain.',
          );
        }
        throw Exception(reason);
      }
      final credential = FacebookAuthProvider.credential(
        loginResult.accessToken!.tokenString,
      );
      return _auth.signInWithCredential(credential);
    } on MissingPluginException {
      throw UnsupportedError(
        'Facebook Sign-In is not available in this build/device.',
      );
    }
  }

  bool _isFacebookInvalidEmailScope(Object error) {
    final lowered = error.toString().toLowerCase();
    return lowered.contains('invalid scopes') && lowered.contains('email');
  }

  bool _looksLikeFacebookAppInactive(String message) {
    final lowered = message.toLowerCase();
    return lowered.contains('app not active') ||
        lowered.contains('application is not active') ||
        lowered.contains('app is not active') ||
        lowered.contains('app isn\'t active');
  }

  Future<FirebaseSocialSignInResult> _toResult(
    UserCredential userCredential, {
    required SocialAuthProvider provider,
  }) async {
    final user = userCredential.user;
    final idToken = await user?.getIdToken(true);
    if (idToken == null || idToken.trim().isEmpty) {
      throw Exception('Firebase did not return a valid token.');
    }
    return FirebaseSocialSignInResult(
      idToken: idToken,
      provider: provider,
      displayName: user?.displayName,
      photoUrl: user?.photoURL,
    );
  }

  Future<void> _initializeGoogleSignIn() async {
    await _initializeGoogleSignInInternal(
      serverClientId: AppEnv.firebaseGoogleServerClientId,
    );
  }

  Future<void> _initializeGoogleSignInInternal({
    required String serverClientId,
  }) async {
    if (_googleInitialized) {
      return;
    }
    final normalizedClientId = serverClientId.trim();
    await _googleSignIn.initialize(
      serverClientId: normalizedClientId.isEmpty ? null : normalizedClientId,
    );
    _googleInitialized = true;
  }

  bool get _supportsFacebookPlugin {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _initializeFacebookWebIfNeeded() async {
    if (!kIsWeb || _facebookWebInitialized) {
      return;
    }
    final appId = AppEnv.firebaseFacebookAppId.trim();
    if (appId.isEmpty) {
      throw UnsupportedError(
        'Missing FIREBASE_FACEBOOK_APP_ID to initialize Facebook on web.',
      );
    }
    final version = AppEnv.firebaseFacebookSdkVersion.trim().isEmpty
        ? 'v22.0'
        : AppEnv.firebaseFacebookSdkVersion.trim();
    await FacebookAuth.instance.webAndDesktopInitialize(
      appId: appId,
      cookie: true,
      xfbml: true,
      version: version,
    );
    _facebookWebInitialized = true;
  }

  FirebaseAuth get _auth {
    final existing = _firebaseAuth;
    if (existing != null) {
      return existing;
    }
    final created = FirebaseAuth.instance;
    _firebaseAuth = created;
    return created;
  }
}

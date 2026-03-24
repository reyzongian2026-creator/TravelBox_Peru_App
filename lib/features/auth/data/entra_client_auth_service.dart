import 'package:msal_flutter/msal_flutter.dart';
import '../../../core/auth/entra_auth_config.dart';
import '../../../core/env/app_env.dart';

enum SocialAuthProvider { google, facebook, microsoft }

extension SocialAuthProviderX on SocialAuthProvider {
  String get backendCode {
    switch (this) {
      case SocialAuthProvider.google:
        return 'GOOGLE';
      case SocialAuthProvider.facebook:
        return 'FACEBOOK';
      case SocialAuthProvider.microsoft:
        return 'MICROSOFT';
    }
  }

  String get label {
    switch (this) {
      case SocialAuthProvider.google:
        return 'Google';
      case SocialAuthProvider.facebook:
        return 'Facebook';
      case SocialAuthProvider.microsoft:
        return 'Microsoft';
    }
  }
}

class EntraSocialSignInResult {
  const EntraSocialSignInResult({
    required this.accessToken,
    required this.provider,
    this.displayName,
    this.email,
  });

  final String accessToken;
  final SocialAuthProvider provider;
  final String? displayName;
  final String? email;
}

class EntraClientAuthService {
  EntraClientAuthService() : _msal = null, _initialized = false;

  PublicClientApplication? _msal;
  bool _initialized;

  bool get isConfigured => 
      AppEnv.azureClientId.trim().isNotEmpty && 
      AppEnv.azureTenantId.trim().isNotEmpty;

  Future<void> _ensureInitialized() async {
    if (_initialized && _msal != null) return;
    
    _msal = await PublicClientApplication.createPublicClientApplication(
      AppEnv.azureClientId,
      authority: 'https://login.microsoftonline.com/${AppEnv.azureTenantId}',
      redirectUri: EntraAuthConfig.redirectUri,
    );
    _initialized = true;
  }

  Future<EntraSocialSignInResult> signIn(SocialAuthProvider provider) async {
    if (!isConfigured) {
      throw UnsupportedError(
        'Microsoft Entra is not configured yet. AZURE_CLIENT_ID or AZURE_TENANT_ID are missing.',
      );
    }
    
    await _ensureInitialized();

    try {
      final token = await _msal!.acquireToken(EntraAuthConfig.scopes);
      
      return EntraSocialSignInResult(
        accessToken: token,
        provider: provider,
        displayName: null,
        email: null,
      );
    } on MsalUserCancelledException {
      throw Exception('Sign in was cancelled');
    } on MsalException catch (e) {
      throw Exception('Authentication failed: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    if (!_initialized || _msal == null) return;
    try {
      await _msal!.logout();
    } catch (_) {}
  }
}

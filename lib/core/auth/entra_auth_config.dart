import 'package:msal_flutter/msal_flutter.dart';
import '../../core/env/app_env.dart';

class EntraAuthConfig {
  static String get clientId => AppEnv.azureClientId;
  static String get tenantId => AppEnv.azureTenantId;
  static String get authority => 'https://login.microsoftonline.com/$tenantId';
  static const String redirectUri = 'travelbox://callback';
  
  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'User.Read',
  ];
}

class EntraAuthResult {
  final String? accessToken;
  final String? idToken;
  final String? displayName;
  final String? email;
  final String? error;

  EntraAuthResult({
    this.accessToken,
    this.idToken,
    this.displayName,
    this.email,
    this.error,
  });

  bool get isSuccess => accessToken != null && error == null;
}

class EntraAuthService {
  PublicClientApplication? _app;

  Future<void> initialize() async {
    _app = await PublicClientApplication.createPublicClientApplication(
      EntraAuthConfig.clientId,
      authority: EntraAuthConfig.authority,
      redirectUri: EntraAuthConfig.redirectUri,
    );
  }

  Future<EntraAuthResult> signIn() async {
    if (_app == null) {
      await initialize();
    }
    
    try {
      final token = await _app!.acquireToken(EntraAuthConfig.scopes);
      return EntraAuthResult(
        accessToken: token,
        idToken: null,
        displayName: null,
        email: null,
      );
    } on MsalUserCancelledException {
      return EntraAuthResult(error: 'Sign in was cancelled');
    } on MsalException catch (e) {
      return EntraAuthResult(error: e.toString());
    } catch (e) {
      return EntraAuthResult(error: e.toString());
    }
  }

  Future<EntraAuthResult> signOut() async {
    if (_app == null) {
      return EntraAuthResult(error: 'Not initialized');
    }
    
    try {
      await _app!.logout();
      return EntraAuthResult();
    } on MsalException catch (e) {
      return EntraAuthResult(error: e.toString());
    } catch (e) {
      return EntraAuthResult(error: e.toString());
    }
  }

  Future<EntraAuthResult> acquireTokenSilent() async {
    if (_app == null) {
      await initialize();
    }
    
    try {
      final token = await _app!.acquireTokenSilent(EntraAuthConfig.scopes);
      return EntraAuthResult(accessToken: token);
    } on MsalException catch (e) {
      return EntraAuthResult(error: e.toString());
    } catch (e) {
      return EntraAuthResult(error: e.toString());
    }
  }
}

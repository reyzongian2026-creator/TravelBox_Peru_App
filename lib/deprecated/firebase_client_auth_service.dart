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
  FirebaseClientAuthService();

  bool get isConfigured => false;

  Future<FirebaseSocialSignInResult> signIn(SocialAuthProvider provider) async {
    throw UnsupportedError(
      'Firebase social auth is deprecated. Use Microsoft Entra ID instead.',
    );
  }

  Future<void> signOut() async {}
}

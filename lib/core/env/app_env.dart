class AppEnv {
  static const appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  static const useMockFallback = bool.fromEnvironment(
    'USE_MOCK_FALLBACK',
    defaultValue: false,
  );

  static const forceCashPaymentsOnly = bool.fromEnvironment(
    'FORCE_CASH_PAYMENTS_ONLY',
    defaultValue: false,
  );

  static const firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );
  static const firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: '',
  );
  static const firebaseIosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: '',
  );
  static const firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '',
  );
  static const firebaseIosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '',
  );
  static const firebaseWebAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
    defaultValue: '',
  );
  static const firebaseGoogleServerClientId = String.fromEnvironment(
    'FIREBASE_GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
  static const firebaseFacebookProviderEnabled = bool.fromEnvironment(
    'FIREBASE_FACEBOOK_ENABLED',
    defaultValue: true,
  );
  static const firebaseFacebookAppId = String.fromEnvironment(
    'FIREBASE_FACEBOOK_APP_ID',
    defaultValue: '',
  );
  static const firebaseFacebookSdkVersion = String.fromEnvironment(
    'FIREBASE_FACEBOOK_SDK_VERSION',
    defaultValue: 'v22.0',
  );
  static const azureStorageUploadsEnabled = bool.fromEnvironment(
    'AZURE_STORAGE_UPLOADS_ENABLED',
    defaultValue: true,
  );

  static const googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static const azureMapsApiKey = String.fromEnvironment(
    'AZURE_MAPS_API_KEY',
    defaultValue: '',
  );

  static const azureTranslatorKey = String.fromEnvironment(
    'AZURE_TRANSLATOR_KEY',
    defaultValue: '',
  );

  static const azureClientId = String.fromEnvironment(
    'AZURE_CLIENT_ID',
    defaultValue: '',
  );

  static const azureTenantId = String.fromEnvironment(
    'AZURE_TENANT_ID',
    defaultValue: '',
  );

  static bool get hasFirebaseClientAuthConfig =>
      firebaseApiKey.trim().isNotEmpty &&
      firebaseProjectId.trim().isNotEmpty &&
      firebaseMessagingSenderId.trim().isNotEmpty;

  static bool get hasEntraAuthConfig =>
      azureClientId.trim().isNotEmpty &&
      azureTenantId.trim().isNotEmpty;

  static bool get hasAzureMapsConfig => azureMapsApiKey.trim().isNotEmpty;

  static bool get isProduction {
    final normalized = appEnvironment.trim().toLowerCase();
    return normalized == 'prod' || normalized == 'production';
  }

  static void validateProductionSafetyOrThrow() {
    if (!isProduction) {
      return;
    }
    if (useMockFallback) {
      throw StateError(
        'Configuracion insegura: USE_MOCK_FALLBACK=true en APP_ENV=prod.',
      );
    }
    if (!hasEntraAuthConfig && !hasFirebaseClientAuthConfig) {
      throw StateError(
        'Configuracion insegura: faltan AZURE_CLIENT_ID/AZURE_TENANT_ID o FIREBASE_API_KEY en APP_ENV=prod.',
      );
    }
    if (!hasAzureMapsConfig && googleMapsApiKey.trim().isEmpty) {
      throw StateError(
        'Configuracion insegura: faltan AZURE_MAPS_API_KEY o GOOGLE_MAPS_API_KEY en APP_ENV=prod.',
      );
    }
    final apiHost = Uri.tryParse(apiBaseUrl)?.host.trim().toLowerCase() ?? '';
    if (apiHost.isEmpty ||
        apiHost == 'localhost' ||
        apiHost == '127.0.0.1' ||
        apiHost == '::1' ||
        apiHost == '10.0.2.2' ||
        apiHost == '10.0.3.2') {
      throw StateError(
        'Configuracion insegura: API_BASE_URL apunta a host local en APP_ENV=prod.',
      );
    }
  }
}

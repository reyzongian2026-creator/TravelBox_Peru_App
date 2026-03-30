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
    if (!hasEntraAuthConfig) {
      throw StateError(
        'Configuracion insegura: faltan AZURE_CLIENT_ID y AZURE_TENANT_ID en APP_ENV=prod.',
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

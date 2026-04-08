class AppEnv {
  static const _productionApiBaseUrl = 'https://api.inkavoy.pe/api/v1';

  static const appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get resolvedApiBaseUrl {
    final configured = apiBaseUrl.trim();
    if (configured.isEmpty) {
      return _fallbackApiBaseUrlForCurrentHost();
    }

    final uri = Uri.tryParse(configured);
    final host = uri?.host.trim().toLowerCase() ?? '';
    if (_isLocalHost(host) && !_isCurrentHostLocal()) {
      return _fallbackApiBaseUrlForCurrentHost();
    }
    return configured;
  }

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
    final apiHost =
        Uri.tryParse(resolvedApiBaseUrl)?.host.trim().toLowerCase() ?? '';
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

  static bool _isCurrentHostLocal() {
    final currentHost = Uri.base.host.trim().toLowerCase();
    return _isLocalHost(currentHost) || currentHost.isEmpty;
  }

  static bool _isLocalHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2' ||
        host == '10.0.3.2';
  }

  static String _fallbackApiBaseUrlForCurrentHost() {
    final currentHost = Uri.base.host.trim().toLowerCase();
    if (_isLocalHost(currentHost)) {
      final origin = Uri.base.origin.trim();
      if (origin.isNotEmpty && origin != 'null') {
        return '$origin/api/v1';
      }
      return '/api/v1';
    }
    if (currentHost.isEmpty) {
      return _productionApiBaseUrl;
    }
    return _productionApiBaseUrl;
  }
}

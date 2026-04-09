import 'dart:async';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/env/app_env.dart';
import 'core/l10n/app_localizations_fixed.dart';
import 'shared/services/app_error_report_service.dart';
import 'shared/services/mobile_push_service.dart';
import 'shared/state/currency_preference.dart';
import 'shared/state/session_controller.dart';
import 'shared/state/session_token_storage.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnv.validateProductionSafetyOrThrow();
  await MobilePushService.instance.initialize();
  final prefs = await SharedPreferences.getInstance();
  final tokenStorage = SecureSessionTokenStorage();

  final errorService = await AppErrorReportService.getInstance(
    Dio(BaseOptions(
      baseUrl: AppEnv.resolvedApiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 45),
    )),
    tokenStorage: tokenStorage,
  );

  AppErrorReportNotifier.setGlobalService(errorService);

  AppLocalizations.setErrorReporter((locale, key, context, userId) {
    errorService.reportI18nError(locale, key, context, userId);
  });

  FlutterError.onError = (FlutterErrorDetails details) {
    errorService.reportFlutterError(details.exception, details.stack, details.context?.toString());
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace? stackTrace) {
    errorService.reportFlutterError(error, stackTrace, 'PlatformDispatcher');
    return true;
  };

  runZonedGuarded<Future<void>>(
    () async {
      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionTokenStorageProvider.overrideWithValue(tokenStorage),
            currencyPreferenceProvider.overrideWith((ref) => CurrencyPreferenceNotifier(prefs)),
          ],
          child: const TravelBoxApp(),
        ),
      );
    },
    (Object error, StackTrace? stackTrace) {
      errorService.reportFlutterError(error, stackTrace, 'AsyncError');
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations_fixed.dart';
import 'core/l10n/localization_runtime.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/state/session_controller.dart';
import 'shared/state/theme_mode_controller.dart';

class TravelBoxApp extends ConsumerWidget {
  const TravelBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final session = ref.watch(sessionControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final effectiveLocale = session.locale;
    LocalizationRuntime.languageCode = session.sessionLanguage;

    return MaterialApp.router(
      title: 'TravelBox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: effectiveLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}

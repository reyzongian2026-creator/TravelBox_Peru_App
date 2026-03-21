import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/env/app_env.dart';
import 'core/firebase/travelbox_firebase.dart';
import 'shared/services/mobile_push_service.dart';
import 'shared/state/session_controller.dart';
import 'shared/state/session_token_storage.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnv.validateProductionSafetyOrThrow();
  await TravelBoxFirebase.initializeIfConfigured();
  await MobilePushService.instance.initialize();
  final prefs = await SharedPreferences.getInstance();
  final tokenStorage = SecureSessionTokenStorage();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionTokenStorageProvider.overrideWithValue(tokenStorage),
      ],
      child: const TravelBoxApp(),
    ),
  );
}

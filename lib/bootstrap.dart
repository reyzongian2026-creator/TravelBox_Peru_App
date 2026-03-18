import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/env/app_env.dart';
import 'core/firebase/travelbox_firebase.dart';
import 'shared/state/session_controller.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnv.validateProductionSafetyOrThrow();
  await TravelBoxFirebase.initializeIfConfigured();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TravelBoxApp(),
    ),
  );
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../env/app_env.dart';

class TravelBoxFirebase {
  static String? get _storageBucketOrNull {
    final value = AppEnv.firebaseStorageBucket.trim();
    return value.isEmpty ? null : value;
  }

  static bool get isConfigured {
    if (!AppEnv.hasFirebaseClientAuthConfig) {
      return false;
    }
    if (kIsWeb) {
      return AppEnv.firebaseWebAppId.trim().isNotEmpty;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AppEnv.firebaseAndroidAppId.trim().isNotEmpty;
      case TargetPlatform.iOS:
        return AppEnv.firebaseIosAppId.trim().isNotEmpty;
      default:
        return false;
    }
  }

  static Future<void> initializeIfConfigured() async {
    if (!isConfigured || Firebase.apps.isNotEmpty) {
      return;
    }
    await Firebase.initializeApp(options: _optionsForCurrentPlatform());
  }

  static FirebaseOptions _optionsForCurrentPlatform() {
    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: AppEnv.firebaseApiKey,
        appId: AppEnv.firebaseWebAppId,
        messagingSenderId: AppEnv.firebaseMessagingSenderId,
        projectId: AppEnv.firebaseProjectId,
        storageBucket: _storageBucketOrNull,
        authDomain: AppEnv.firebaseAuthDomain.trim().isEmpty
            ? null
            : AppEnv.firebaseAuthDomain,
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseOptions(
          apiKey: AppEnv.firebaseApiKey,
          appId: AppEnv.firebaseAndroidAppId,
          messagingSenderId: AppEnv.firebaseMessagingSenderId,
          projectId: AppEnv.firebaseProjectId,
          storageBucket: _storageBucketOrNull,
        );
      case TargetPlatform.iOS:
        return FirebaseOptions(
          apiKey: AppEnv.firebaseApiKey,
          appId: AppEnv.firebaseIosAppId,
          messagingSenderId: AppEnv.firebaseMessagingSenderId,
          projectId: AppEnv.firebaseProjectId,
          storageBucket: _storageBucketOrNull,
          iosBundleId: AppEnv.firebaseIosBundleId.trim().isEmpty
              ? null
              : AppEnv.firebaseIosBundleId,
        );
      default:
        throw UnsupportedError(
          'Firebase social auth solo esta habilitado en web, Android e iOS.',
        );
    }
  }
}

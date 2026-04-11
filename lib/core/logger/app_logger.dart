import 'package:flutter/foundation.dart';

/// Centralized logging utility for TravelBox Peru.
///
/// Usage:
/// ```dart
/// AppLog.d('ApiClient', 'Request sent to /reservations');
/// AppLog.w('PaymentFlow', 'Wallet balance fetch failed', error);
/// AppLog.e('AuthService', 'Token refresh failed', error, stack);
/// ```
///
/// In release builds, [d] and [v] are no-ops. [w] and [e] still
/// print in debug mode and can be wired to a remote error reporter.
class AppLog {
  AppLog._();

  /// Verbose — fine-grained tracing, debug builds only.
  static void v(String tag, String message) {
    if (kDebugMode) debugPrint('[V][$tag] $message');
  }

  /// Debug — general diagnostic info, debug builds only.
  static void d(String tag, String message) {
    if (kDebugMode) debugPrint('[D][$tag] $message');
  }

  /// Warning — unexpected but recoverable situations.
  static void w(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint(
        '[W][$tag] $message'
        '${error != null ? ' | $error' : ''}',
      );
    }
  }

  /// Error — failures that may affect user experience.
  /// Always printed in debug; can be routed to a crash reporter in release.
  static void e(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (kDebugMode) {
      debugPrint(
        '[E][$tag] $message'
        '${error != null ? ' | $error' : ''}'
        '${stack != null ? '\n$stack' : ''}',
      );
    }
  }
}

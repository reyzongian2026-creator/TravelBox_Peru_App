import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight connectivity tracker — no external dependency needed.
/// State is driven by Dio interceptor responses:
///   - Any successful HTTP response → [ConnectivityStatus.online]
///   - Connection/timeout errors    → [ConnectivityStatus.offline]
enum ConnectivityStatus {
  /// Connection is working (last API call succeeded)
  online,

  /// Connection appears down (last API call failed with network error)
  offline,

  /// Initial state — no API call has been made yet
  unknown,
}

/// Global connectivity state provider.
/// Updated automatically by the Dio interceptor in api_client.dart.
final connectivityProvider =
    StateProvider<ConnectivityStatus>((ref) => ConnectivityStatus.unknown);

/// Whether the app currently appears to be offline.
final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider) == ConnectivityStatus.offline;
});

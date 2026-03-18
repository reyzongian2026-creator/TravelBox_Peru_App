import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_center_controller.dart';
import 'session_controller.dart';

final realtimeAppEventCursorProvider = Provider<int>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (!session.isAuthenticated) {
    return 0;
  }
  return ref.watch(
    notificationCenterControllerProvider.select((state) => state.cursor),
  );
});

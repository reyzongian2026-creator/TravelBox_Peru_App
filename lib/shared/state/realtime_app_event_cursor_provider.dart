import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_realtime_mutation_tick_provider.dart';
import 'notification_center_controller.dart';
import 'session_controller.dart';

final realtimeAppEventCursorProvider = Provider<int>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (!session.isAuthenticated) {
    return 0;
  }
  final notificationCursor = ref.watch(
    notificationCenterControllerProvider.select((state) => state.cursor),
  );
  final mutationTick = ref.watch(localRealtimeMutationTickProvider);
  return (notificationCursor * 1000000) + mutationTick;
});

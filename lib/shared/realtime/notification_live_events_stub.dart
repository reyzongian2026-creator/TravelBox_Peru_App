import 'notification_live_events_client.dart';

class _UnsupportedNotificationLiveEventsClient
    implements NotificationLiveEventsClient {
  @override
  bool get isSupported => false;

  @override
  void connect({
    required String apiBaseUrl,
    required String accessToken,
    required void Function(NotificationLiveEvent event) onNotification,
    void Function(Object error)? onError,
  }) {}

  @override
  void disconnect() {}
}

NotificationLiveEventsClient createNotificationLiveEventsClient() =>
    _UnsupportedNotificationLiveEventsClient();

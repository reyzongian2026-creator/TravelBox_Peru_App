class NotificationLiveEvent {
  const NotificationLiveEvent({
    required this.eventName,
    this.payload,
  });

  final String eventName;
  final Map<String, dynamic>? payload;
}

abstract class NotificationLiveEventsClient {
  bool get isSupported;

  void connect({
    required String apiBaseUrl,
    required String accessToken,
    required void Function(NotificationLiveEvent event) onNotification,
    void Function(Object error)? onError,
  });

  void disconnect();
}

import 'notification_live_events_client.dart';
import 'notification_live_events_stub.dart'
    if (dart.library.io) 'notification_live_events_io.dart'
    if (dart.library.html) 'notification_live_events_web.dart'
    as impl;

NotificationLiveEventsClient createNotificationLiveEventsClient() =>
    impl.createNotificationLiveEventsClient();

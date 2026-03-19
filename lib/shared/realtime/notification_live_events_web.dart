// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'notification_live_events_client.dart';

class _WebNotificationLiveEventsClient implements NotificationLiveEventsClient {
  html.EventSource? _eventSource;

  @override
  bool get isSupported => true;

  @override
  void connect({
    required String apiBaseUrl,
    required String accessToken,
    required void Function(NotificationLiveEvent event) onNotification,
    void Function(Object error)? onError,
    int? lastEventId,
  }) {
    if (accessToken.trim().isEmpty) {
      return;
    }

    disconnect();
    final normalizedBase = _normalizeBaseUrl(apiBaseUrl);
    final query = StringBuffer(
      'accessToken=${Uri.encodeQueryComponent(accessToken)}',
    );
    if (lastEventId != null && lastEventId > 0) {
      query.write('&lastEventId=$lastEventId');
    }
    final url = '$normalizedBase/notifications/events?$query';
    final source = html.EventSource(url);
    source.addEventListener('notification', (event) {
      if (event is html.MessageEvent) {
        onNotification(
          NotificationLiveEvent(
            eventName: 'notification',
            payload: _parsePayload(event.data),
          ),
        );
        return;
      }
      onNotification(const NotificationLiveEvent(eventName: 'notification'));
    });
    source.onMessage.listen((event) {
      onNotification(
        NotificationLiveEvent(
          eventName: 'message',
          payload: _parsePayload(event.data),
        ),
      );
    });
    source.onError.listen((_) {
      if (onError != null) {
        onError(StateError('notification_sse_error'));
      }
    });
    _eventSource = source;
  }

  @override
  void disconnect() {
    _eventSource?.close();
    _eventSource = null;
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Map<String, dynamic>? _parsePayload(dynamic raw) {
    final normalized = raw?.toString().trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

NotificationLiveEventsClient createNotificationLiveEventsClient() =>
    _WebNotificationLiveEventsClient();

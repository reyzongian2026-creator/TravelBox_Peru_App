import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'notification_live_events_client.dart';

const _reconnectDelay = Duration(seconds: 3);
// Si no recibimos NADA (ni latidos ni data) en 45s, asumimos que el socket murió
const _idleTimeout = Duration(seconds: 45);

class _IoNotificationLiveEventsClient implements NotificationLiveEventsClient {
  HttpClient? _httpClient;
  StreamSubscription<String>? _subscription;
  Timer? _idleWatchdog;
  int _connectionId = 0;
  bool _manuallyDisconnected = false;
  bool _reconnectScheduled = false;
  String? _apiBaseUrl;
  String? _accessToken;
  int? _lastEventId;
  void Function(NotificationLiveEvent event)? _onNotification;
  void Function(Object error)? _onError;

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
    final normalizedToken = accessToken.trim();
    if (normalizedToken.isEmpty) {
      return;
    }

    disconnect();
    _manuallyDisconnected = false;
    _apiBaseUrl = apiBaseUrl;
    _accessToken = normalizedToken;
    _lastEventId = lastEventId;
    _onNotification = onNotification;
    _onError = onError;
    final currentConnectionId = ++_connectionId;
    unawaited(
      _open(
        connectionId: currentConnectionId,
        apiBaseUrl: apiBaseUrl,
        accessToken: normalizedToken,
        onNotification: onNotification,
        onError: onError,
        lastEventId: lastEventId,
      ),
    );
  }

  @override
  void disconnect() {
    _manuallyDisconnected = true;
    _reconnectScheduled = false;
    _connectionId += 1;
    _lastEventId = null;
    _idleWatchdog?.cancel();
    _idleWatchdog = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  void _resetWatchdog(int connectionId) {
    _idleWatchdog?.cancel();
    _idleWatchdog = Timer(_idleTimeout, () {
      if (connectionId == _connectionId && !_manuallyDisconnected) {
        // El socket se quedó zombi (ej. cambio de red Wi-Fi a 4G).
        // Forzamos el cierre para que se dispare el onError/onDone y se reconecte.
        _httpClient?.close(force: true);
      }
    });
  }

  Future<void> _open({
    required int connectionId,
    required String apiBaseUrl,
    required String accessToken,
    required void Function(NotificationLiveEvent event) onNotification,
    void Function(Object error)? onError,
    int? lastEventId,
  }) async {
    final client = HttpClient();
    _httpClient = client;
    _reconnectScheduled = false;

    try {
      final baseUrl = _normalizeBaseUrl(apiBaseUrl);
      final query = StringBuffer(
        'accessToken=${Uri.encodeQueryComponent(accessToken)}',
      );
      final normalizedLastEventId = lastEventId ?? _lastEventId;
      if (normalizedLastEventId != null && normalizedLastEventId > 0) {
        query.write('&lastEventId=$normalizedLastEventId');
      }
      final uri = Uri.parse('$baseUrl/notifications/events?$query');
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'notification_sse_http_${response.statusCode}',
          uri: uri,
        );
      }
      if (connectionId != _connectionId) {
        return;
      }

      String? eventName;
      var dataLines = <String>[];
      _resetWatchdog(connectionId); // Iniciamos el watchdog

      _subscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (connectionId != _connectionId) return;

              _resetWatchdog(
                connectionId,
              ); // Cada vez que entra data, reseteamos el watchdog

              if (line.isEmpty) {
                final hasData = dataLines.isNotEmpty;
                final event = eventName ?? 'message';
                if (hasData &&
                    (event == 'notification' || event == 'message')) {
                  onNotification(
                    NotificationLiveEvent(
                      eventName: event,
                      payload: _parsePayload(dataLines.join('\n')),
                    ),
                  );
                }
                eventName = null;
                dataLines = <String>[];
                return;
              }

              // Ignorar los comentarios SSE (ej. :keepalive)
              if (line.startsWith(':')) {
                return;
              }
              if (line.startsWith('event:')) {
                eventName = line.substring(6).trim();
                return;
              }
              if (line.startsWith('data:')) {
                dataLines.add(line.substring(5).trimLeft());
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (connectionId != _connectionId) return;
              _idleWatchdog?.cancel();
              if (onError != null) onError(error);
              _scheduleReconnect(connectionId);
            },
            onDone: () {
              if (connectionId != _connectionId) return;
              _idleWatchdog?.cancel();
              if (onError != null) {
                onError(StateError('notification_sse_closed'));
              }
              _scheduleReconnect(connectionId);
            },
            cancelOnError: true,
          );
    } catch (error) {
      if (connectionId != _connectionId) return;
      _idleWatchdog?.cancel();
      if (onError != null) onError(error);
      _scheduleReconnect(connectionId);
    }
  }

  void _scheduleReconnect(int failedConnectionId) {
    if (_manuallyDisconnected || _reconnectScheduled) {
      return;
    }
    final apiBaseUrl = _apiBaseUrl;
    final accessToken = _accessToken;
    final lastEventId = _lastEventId;
    final onNotification = _onNotification;
    if (apiBaseUrl == null ||
        accessToken == null ||
        onNotification == null ||
        failedConnectionId != _connectionId) {
      return;
    }
    _reconnectScheduled = true;
    unawaited(
      Future<void>.delayed(_reconnectDelay, () {
        if (_manuallyDisconnected || failedConnectionId != _connectionId) {
          _reconnectScheduled = false;
          return;
        }
        final reconnectConnectionId = ++_connectionId;
        unawaited(
          _open(
            connectionId: reconnectConnectionId,
            apiBaseUrl: apiBaseUrl,
            accessToken: accessToken,
            onNotification: onNotification,
            onError: _onError,
            lastEventId: lastEventId,
          ),
        );
      }),
    );
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Map<String, dynamic>? _parsePayload(String raw) {
    final normalized = raw.trim();
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
    _IoNotificationLiveEventsClient();

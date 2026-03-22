import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:travelbox_peru_app/core/env/app_env.dart';
import '../state/session_controller.dart';

enum WebSocketEventType {
  reservationUpdated,
  reservationCreated,
  reservationCancelled,
  notificationReceived,
  dashboardStatsUpdate,
  approvalRequired,
  deliveryStatusChanged,
  pong,
  unknown,
}

class WebSocketEvent {
  final WebSocketEventType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  WebSocketEvent({
    required this.type,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    final typeString = json['type']?.toString().toLowerCase() ?? '';
    WebSocketEventType type;

    switch (typeString) {
      case 'reservation_updated':
        type = WebSocketEventType.reservationUpdated;
        break;
      case 'reservation_created':
        type = WebSocketEventType.reservationCreated;
        break;
      case 'reservation_cancelled':
        type = WebSocketEventType.reservationCancelled;
        break;
      case 'notification':
        type = WebSocketEventType.notificationReceived;
        break;
      case 'dashboard_stats':
        type = WebSocketEventType.dashboardStatsUpdate;
        break;
      case 'approval_required':
        type = WebSocketEventType.approvalRequired;
        break;
      case 'delivery_status':
        type = WebSocketEventType.deliveryStatusChanged;
        break;
      default:
        type = WebSocketEventType.unknown;
    }

    return WebSocketEvent(
      type: type,
      payload: json['data'] as Map<String, dynamic>? ?? json,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }
}

class WebSocketManager extends StateNotifier<AsyncValue<WebSocketConnectionStatus>> {
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  String? _accessToken;
  bool _manuallyDisconnected = false;
  final List<void Function(WebSocketEvent)> _eventListeners = [];
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  static const _reconnectBaseDelay = Duration(seconds: 2);

  WebSocketManager(this._ref) : super(const AsyncValue.data(WebSocketConnectionStatus.disconnected));

  void addEventListener(void Function(WebSocketEvent) listener) {
    _eventListeners.add(listener);
  }

  void removeEventListener(void Function(WebSocketEvent) listener) {
    _eventListeners.remove(listener);
  }

  void _notifyListeners(WebSocketEvent event) {
    final listeners = List<void Function(WebSocketEvent)>.from(_eventListeners);
    for (final listener in listeners) {
      try {
        listener(event);
      } catch (e) {
        debugPrint('WebSocket listener error: $e');
      }
    }
  }

  Future<void> connect() async {
    final session = _ref.read(sessionControllerProvider);
    final token = session.accessToken;

    if (token == null || token.isEmpty) {
      return;
    }

    _accessToken = token;
    _manuallyDisconnected = false;
    await _establishConnection();
  }

  Future<void> _establishConnection() async {
    if (_manuallyDisconnected) return;

    state = const AsyncValue.loading();

    try {
      final wsUrl = _buildWebSocketUrl();
      _channel = WebSocketChannel.connect(wsUrl);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      state = const AsyncValue.data(WebSocketConnectionStatus.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      _scheduleReconnect();
    }
  }

  Uri _buildWebSocketUrl() {
    final baseUrl = AppEnv.apiBaseUrl;
    final wsScheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
    final host = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    return Uri.parse('$wsScheme://$host/ws?token=${Uri.encodeComponent(_accessToken ?? '')}');
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString()) as Map<String, dynamic>;
      final typeString = data['type']?.toString().toLowerCase() ?? '';
      
      if (typeString == 'pong') {
        return;
      }
      
      final event = WebSocketEvent.fromJson(data);
      _notifyListeners(event);
    } catch (e) {
      // Log error but don't crash
      debugPrint('WebSocket message parse error: $e');
    }
  }

  void _onError(Object error, [StackTrace? st]) {
    debugPrint('WebSocket error: $error');
    state = AsyncValue.error(error, st ?? StackTrace.current);
    if (!_manuallyDisconnected) {
      _scheduleReconnect();
    }
  }

  void _onDone() {
    if (!_manuallyDisconnected) {
      state = const AsyncValue.data(WebSocketConnectionStatus.reconnecting);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manuallyDisconnected || _reconnectAttempts >= _maxReconnectAttempts) {
      state = const AsyncValue.data(WebSocketConnectionStatus.disconnected);
      return;
    }

    _reconnectAttempts++;
    final delay = _reconnectBaseDelay * (1 << _reconnectAttempts.clamp(0, 4));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_manuallyDisconnected) {
        _establishConnection();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.valueOrNull == WebSocketConnectionStatus.connected) {
        _sendPing();
      }
    });
  }

  void _sendPing() {
    try {
      _channel?.sink.add(jsonEncode({'type': 'ping', 'timestamp': DateTime.now().toIso8601String()}));
    } catch (e) {
      debugPrint('WebSocket ping error: $e');
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (state.valueOrNull == WebSocketConnectionStatus.connected) {
      try {
        _channel?.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('WebSocket send error: $e');
      }
    }
  }

  void subscribeToChannels(List<String> channels) {
    sendMessage({
      'type': 'subscribe',
      'channels': channels,
    });
  }

  void disconnect() {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    state = const AsyncValue.data(WebSocketConnectionStatus.disconnected);
  }

  @override
  void dispose() {
    disconnect();
    _eventListeners.clear();
    super.dispose();
  }
}

enum WebSocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

final webSocketManagerProvider =
    StateNotifierProvider<WebSocketManager, AsyncValue<WebSocketConnectionStatus>>(
  (ref) {
    final manager = WebSocketManager(ref);

    final session = ref.watch(sessionControllerProvider);
    if (session.isAuthenticated) {
      manager.connect();
    }

    ref.onDispose(() {
      manager.disconnect();
    });

    return manager;
  },
);

final realtimeEventProvider = StreamProvider<WebSocketEvent>((ref) {
  final controller = StreamController<WebSocketEvent>();

  final manager = ref.read(webSocketManagerProvider.notifier);
  manager.addEventListener((event) {
    if (!controller.isClosed) {
      controller.add(event);
    }
  });

  ref.onDispose(() {
    manager.removeEventListener((_) {});
    controller.close();
  });

  return controller.stream;
});

final reservationRealtimeUpdatesProvider = StreamProvider.family<WebSocketEvent?, String>(
  (ref, reservationId) {
    return _createEventStream(ref).where((event) {
      if (event.type == WebSocketEventType.reservationUpdated ||
          event.type == WebSocketEventType.reservationCreated) {
        return event.payload['id']?.toString() == reservationId;
      }
      return false;
    });
  },
);

final dashboardRealtimeUpdatesProvider = StreamProvider<WebSocketEvent>((ref) {
  return _createEventStream(ref).where((event) {
    return event.type == WebSocketEventType.dashboardStatsUpdate;
  });
});

Stream<WebSocketEvent> _createEventStream(Ref ref) {
  final controller = StreamController<WebSocketEvent>();
  
  void listener(WebSocketEvent event) {
    if (!controller.isClosed) {
      controller.add(event);
    }
  }
  
  ref.onDispose(() {
    ref.read(webSocketManagerProvider.notifier).removeEventListener(listener);
    controller.close();
  });
  
  ref.read(webSocketManagerProvider.notifier).addEventListener(listener);
  
  return controller.stream;
}

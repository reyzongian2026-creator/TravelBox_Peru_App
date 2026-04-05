import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/state/session_controller.dart';

abstract class NotificationRealtimeService {
  Stream<RealtimeNotification> get notificationStream;
  Future<void> connect();
  Future<void> disconnect();
  bool get isConnected;
}

class RealtimeNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final bool isSilent;

  const RealtimeNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.timestamp,
    this.isSilent = false,
  });

  factory RealtimeNotification.fromJson(Map<String, dynamic> json) {
    return RealtimeNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['message']?.toString() ?? json['body']?.toString() ?? '',
      data: json['data'] as Map<String, dynamic>?,
      timestamp: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      isSilent: json['silent'] == true,
    );
  }
}

final notificationRealtimeServiceProvider =
    StateNotifierProvider<NotificationRealtimeServiceNotifier, NotificationRealtimeServiceState>(
  (ref) => NotificationRealtimeServiceNotifier(ref),
);

class NotificationRealtimeServiceState {
  final bool isConnected;
  final bool isConnecting;
  final String? error;
  final List<RealtimeNotification> recentNotifications;

  const NotificationRealtimeServiceState({
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
    this.recentNotifications = const [],
  });

  NotificationRealtimeServiceState copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? error,
    List<RealtimeNotification>? recentNotifications,
  }) {
    return NotificationRealtimeServiceState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error,
      recentNotifications: recentNotifications ?? this.recentNotifications,
    );
  }
}

class NotificationRealtimeServiceNotifier extends StateNotifier<NotificationRealtimeServiceState>
    implements NotificationRealtimeService {
  final Ref _ref;
  StreamSubscription? _sseSubscription;
  Timer? _reconnectTimer;
  CancelToken? _cancelToken;

  NotificationRealtimeServiceNotifier(this._ref)
      : super(const NotificationRealtimeServiceState());

  @override
  Stream<RealtimeNotification> get notificationStream async* {
    while (!state.isConnected && state.error == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final dio = _ref.read(dioProvider);
    _cancelToken = CancelToken();

    while (!_cancelToken!.isCancelled) {
      try {
        final session = _ref.read(sessionControllerProvider);
        final token = session.accessToken;

        if (token == null || token.isEmpty) {
          break;
        }

        final stream = dio.get<List<int>>(
          '/notifications/events',
          options: Options(
            headers: {
              'Accept': 'text/event-stream',
              'Cache-Control': 'no-cache',
              'Authorization': 'Bearer $token',
            },
            responseType: ResponseType.stream,
          ),
          queryParameters: {
            'accessToken': token,
          },
        );

        await for (final response in stream.asStream()) {
          final data = response.data;
          if (data == null) continue;

          final lines = String.fromCharCodes(data).split('\n');
          for (final line in lines) {
            if (line.startsWith('data:')) {
              final jsonStr = line.substring(5).trim();
              if (jsonStr.isNotEmpty && jsonStr != '[object Object]') {
                try {
                  final json = _parseSSEData(jsonStr);
                  if (json != null) {
                    final notification = RealtimeNotification.fromJson(json);
                    yield notification;
                    _addRecentNotification(notification);
                  }
                } catch (e) {
                  debugPrint('SSE parse error: $e for data: $jsonStr');
                }
              }
            }
          }
        }
      } catch (e) {
        state = state.copyWith(error: e.toString());
        _scheduleReconnect();
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  Map<String, dynamic>? _parseSSEData(String data) {
    if (data.startsWith('{') && data.endsWith('}')) {
      try {
        final firstBracket = data.indexOf('{');
        final lastBracket = data.lastIndexOf('}');
        if (firstBracket >= 0 && lastBracket > firstBracket) {
          final jsonStr = data.substring(firstBracket, lastBracket + 1);
          return _parseJsonSafely(jsonStr);
        }
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic>? _parseJsonSafely(String jsonStr) {
    try {
      final trimmed = jsonStr.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final decoded = Uri.decodeFull(trimmed);
        final result = (const JsonDecoder().convert(decoded)) as Map<String, dynamic>?;
        return result;
      }
    } catch (_) {}
    return null;
  }

  void _addRecentNotification(RealtimeNotification notification) {
    final recent = [notification, ...state.recentNotifications.take(49)];
    state = state.copyWith(recentNotifications: recent);
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connect();
    });
  }

  @override
  Future<void> connect() async {
    if (state.isConnected || state.isConnecting) return;

    state = state.copyWith(isConnecting: true, error: null);

    try {
      final session = _ref.read(sessionControllerProvider);
      final token = session.accessToken;

      if (token == null || token.isEmpty) {
        state = state.copyWith(isConnecting: false, error: 'No auth token available');
        return;
      }

      _sseSubscription?.cancel();
      _sseSubscription = notificationStream.listen(
        (_) {},
        onError: (e) {
          state = state.copyWith(isConnected: false, error: e.toString());
          _scheduleReconnect();
        },
        onDone: () {
          state = state.copyWith(isConnected: false);
          _scheduleReconnect();
        },
      );

      state = state.copyWith(isConnected: true, isConnecting: false);
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: e.toString(),
      );
      _scheduleReconnect();
    }
  }

  @override
  Future<void> disconnect() async {
    _cancelToken?.cancel('User disconnected');
    _sseSubscription?.cancel();
    _reconnectTimer?.cancel();
    state = const NotificationRealtimeServiceState();
  }

  @override
  bool get isConnected => state.isConnected;
}

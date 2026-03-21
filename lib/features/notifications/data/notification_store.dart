import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class NotificationStore extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final Ref _ref;
  final int _batchSize;
  String? _lastEventId;
  Timer? _periodicTimer;
  bool _isInitialized = false;

  NotificationStore(this._ref, {int batchSize = 20})
      : _batchSize = batchSize,
        super(const AsyncValue.loading()) {
    _initialize();
  }

  void _initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refresh(showLoading: false);
    });
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading && state.isLoading) return;

    if (!showLoading && !state.hasValue) {
      state = const AsyncValue.loading();
    }

    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get<List<dynamic>>(
        '/notifications/my',
        queryParameters: {
          'limit': _batchSize,
          if (_lastEventId != null) 'after': _lastEventId,
        },
      );

      final notifications = (response.data ?? [])
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      if (notifications.isNotEmpty) {
        _lastEventId = notifications.first.id;
      }

      if (state.valueOrNull != null && !showLoading) {
        final existing = state.valueOrNull!;
        final newIds = notifications.map((n) => n.id).toSet();
        final uniqueNew = notifications.where((n) => !newIds.contains(n.id)).toList();
        state = AsyncValue.data([...notifications, ...existing, ...uniqueNew]);
      } else {
        state = AsyncValue.data(notifications);
      }
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void addNotification(AppNotification notification) {
    final current = state.valueOrNull ?? [];
    if (current.any((n) => n.id == notification.id)) return;
    state = AsyncValue.data([notification, ...current]);
  }

  void updateNotification(String id, AppNotification notification) {
    final current = state.valueOrNull ?? [];
    final index = current.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final updated = [...current];
    updated[index] = notification;
    state = AsyncValue.data(updated);
  }

  void removeNotification(String id) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((n) => n.id != id).toList());
  }

  void markAsRead(String id) {
    final current = state.valueOrNull ?? [];
    final notification = current.firstWhere(
      (n) => n.id == id,
      orElse: () => throw StateError('Notification not found'),
    );
    if (notification.isRead) return;
    updateNotification(id, notification.copyWith(isRead: true));
  }

  void markAllAsRead() {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((n) => n.isRead ? n : n.copyWith(isRead: true)).toList(),
    );
  }

  int get unreadCount {
    return state.valueOrNull?.where((n) => !n.isRead).length ?? 0;
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}

final notificationStoreProvider =
    StateNotifierProvider<NotificationStore, AsyncValue<List<AppNotification>>>(
  (ref) {
    return NotificationStore(ref);
  },
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationStoreProvider);
  return notifications.valueOrNull?.where((n) => !n.isRead).length ?? 0;
});

final notificationBadgeProvider = Provider<String?>((ref) {
  final count = ref.watch(unreadNotificationCountProvider);
  if (count == 0) return null;
  if (count > 99) return '99+';
  return count.toString();
});

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final bool isRead;
  final String? route;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.createdAt,
    this.isRead = false,
    this.route,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: json['data'] as Map<String, dynamic>?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      route: json['route']?.toString(),
    );
  }

  AppNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    bool? isRead,
    String? route,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      route: route ?? this.route,
    );
  }
}

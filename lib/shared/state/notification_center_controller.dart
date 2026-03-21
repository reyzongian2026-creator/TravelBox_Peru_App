import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/env/app_env.dart';
import '../../core/network/api_client.dart';
import '../../features/notifications/domain/app_notification.dart';
import '../realtime/notification_live_events.dart';
import '../realtime/notification_live_events_client.dart';
import 'session_controller.dart';

const _maxNotificationItems = 150;
const _seenIdsMax = 500;
const _streamBatchSize = 80;
const _seenKeyPrefix = 'travelbox.notifications.seen.';
const _liveRefreshDebounceWindow = Duration(milliseconds: 450);
const _cursorAffectingEventTags = {
  'reservation',
  'payment',
  'delivery',
  'incident',
  'inventory',
  'ops',
};

final notificationCenterControllerProvider =
    StateNotifierProvider<
      NotificationCenterController,
      NotificationCenterState
    >((ref) {
      final controller = NotificationCenterController(
        dio: ref.read(dioProvider),
        prefs: ref.read(sharedPreferencesProvider),
      );

      ref.listen<SessionState>(sessionControllerProvider, (_, next) {
        controller.onSessionChanged(next);
      });
      ref.onDispose(controller.dispose);

      controller.onSessionChanged(ref.read(sessionControllerProvider));
      return controller;
    });

class NotificationCenterState {
  const NotificationCenterState({
    required this.items,
    required this.popupQueue,
    required this.seenIds,
    required this.loading,
    required this.error,
    required this.cursor,
  });

  factory NotificationCenterState.initial() {
    return const NotificationCenterState(
      items: [],
      popupQueue: [],
      seenIds: {},
      loading: false,
      error: null,
      cursor: 0,
    );
  }

  final List<AppNotification> items;
  final List<AppNotification> popupQueue;
  final Set<String> seenIds;
  final bool loading;
  final String? error;
  final int cursor;

  int get unreadCount =>
      items.where((item) => !seenIds.contains(item.id)).length;

  NotificationCenterState copyWith({
    List<AppNotification>? items,
    List<AppNotification>? popupQueue,
    Set<String>? seenIds,
    bool? loading,
    String? error,
    int? cursor,
    bool clearError = false,
  }) {
    return NotificationCenterState(
      items: items ?? this.items,
      popupQueue: popupQueue ?? this.popupQueue,
      seenIds: seenIds ?? this.seenIds,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      cursor: cursor ?? this.cursor,
    );
  }
}

class NotificationCenterController
    extends StateNotifier<NotificationCenterState>
    with WidgetsBindingObserver {
  NotificationCenterController({
    required Dio dio,
    required SharedPreferences prefs,
  }) : _dio = dio,
       _prefs = prefs,
       super(NotificationCenterState.initial()) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Dio _dio;
  final SharedPreferences _prefs;
  final NotificationLiveEventsClient _liveEventsClient =
      createNotificationLiveEventsClient();
  final Set<String> _announcedIds = <String>{};

  bool _isFetching = false;
  bool _isAppForeground = true;
  bool _liveEventsConnected = false;
  bool _seededFromServer = false;
  String? _activeUserId;
  String? _activeAccessToken;
  Timer? _refreshDebounceTimer;

  @override
  void dispose() {
    _refreshDebounceTimer?.cancel();
    _disconnectLiveEvents();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void onSessionChanged(SessionState session) {
    final userId = session.user?.id;
    if (!session.isAuthenticated || userId == null || userId.isEmpty) {
      _refreshDebounceTimer?.cancel();
      _disconnectLiveEvents();
      _activeUserId = null;
      _activeAccessToken = null;
      _seededFromServer = false;
      _announcedIds.clear();
      state = NotificationCenterState.initial();
      return;
    }

    if (_activeUserId != userId) {
      _refreshDebounceTimer?.cancel();
      _activeUserId = userId;
      _seededFromServer = false;
      _announcedIds.clear();
      unawaited(_restoreSeenIdsForActiveUser());
    }

    if (!_isAppForeground) {
      _activeAccessToken = session.accessToken?.trim();
      return;
    }

    _ensureLiveEventsSubscription(
      session.accessToken,
      lastEventId: state.cursor,
    );
    unawaited(refreshNow(showLoading: state.items.isEmpty));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldPause =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (shouldPause) {
      _isAppForeground = false;
      _refreshDebounceTimer?.cancel();
      _disconnectLiveEvents();
      return;
    }

    if (state != AppLifecycleState.resumed) {
      return;
    }

    _isAppForeground = true;
    _ensureLiveEventsSubscription(
      _activeAccessToken,
      lastEventId: this.state.cursor,
      forceReconnect: true,
    );
    unawaited(refreshNow());
  }

  void _ensureLiveEventsSubscription(
    String? accessTokenRaw, {
    int? lastEventId,
    bool forceReconnect = false,
  }) {
    if (!_liveEventsClient.isSupported) {
      return;
    }
    final accessToken = accessTokenRaw?.trim();
    if (accessToken == null || accessToken.isEmpty) {
      _activeAccessToken = null;
      _disconnectLiveEvents();
      return;
    }
    final shouldReconnect =
        forceReconnect ||
        !_liveEventsConnected ||
        _activeAccessToken != accessToken;
    _activeAccessToken = accessToken;
    if (!shouldReconnect) {
      return;
    }
    _liveEventsConnected = true;
    _liveEventsClient.connect(
      apiBaseUrl: AppEnv.apiBaseUrl,
      accessToken: accessToken,
      lastEventId: lastEventId ?? state.cursor,
      onNotification: (event) {
        _handleLiveEvent(event);
      },
      onError: (_) => _scheduleRefreshDebounced(),
    );
  }

  void _handleLiveEvent(NotificationLiveEvent event) {
    final payload = event.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }
    final incoming = _notificationFromLivePayload(payload);
    if (incoming == null) {
      _scheduleRefreshDebounced();
      return;
    }
    _seededFromServer = true;
    _applyLiveNotification(incoming);
  }

  void _applyLiveNotification(AppNotification incoming) {
    final visible = _isVisibleNotification(incoming);
    final cursorCandidate = int.tryParse(incoming.id) ?? state.cursor;
    final shouldAdvanceCursor = _shouldAdvanceCursorForEvent(incoming);
    final nextCursor = shouldAdvanceCursor && cursorCandidate > state.cursor
        ? cursorCandidate
        : state.cursor;

    if (!visible) {
      if (nextCursor != state.cursor) {
        state = state.copyWith(cursor: nextCursor);
      }
      return;
    }

    final fresh = !_announcedIds.contains(incoming.id);
    _announcedIds.add(incoming.id);
    state = state.copyWith(
      items: _mergeItemsNewestFirst(state.items, [incoming]),
      popupQueue: fresh ? [...state.popupQueue, incoming] : state.popupQueue,
      cursor: nextCursor,
      clearError: true,
    );
  }

  AppNotification? _notificationFromLivePayload(Map<String, dynamic> payload) {
    Map<String, dynamic> data = payload;
    final nested = payload['data'];
    if (nested is Map<String, dynamic>) {
      data = nested;
    } else if (nested is Map) {
      data = nested.map((key, value) => MapEntry(key.toString(), value));
    }
    final parsed = AppNotification.fromJson(data);
    if (parsed.id.trim().isEmpty) {
      return null;
    }
    return parsed;
  }

  bool _shouldAdvanceCursorForEvent(AppNotification incoming) {
    if (_isVisibleNotification(incoming)) {
      return true;
    }
    final tags = _extractEventTags(incoming);
    if (tags.isNotEmpty) {
      return tags.any(_cursorAffectingEventTags.contains);
    }
    final normalizedType = incoming.type.trim().toUpperCase();
    return normalizedType.contains('RESERVATION') ||
        normalizedType.contains('PAYMENT') ||
        normalizedType.contains('DELIVERY') ||
        normalizedType.contains('INCIDENT') ||
        normalizedType.contains('INVENTORY') ||
        normalizedType.contains('OPS') ||
        normalizedType.contains('QR');
  }

  Set<String> _extractEventTags(AppNotification incoming) {
    final rawTags = incoming.payload['events'];
    if (rawTags is! Iterable) {
      return const <String>{};
    }
    return rawTags
        .map((tag) => tag.toString().trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet();
  }

  void _scheduleRefreshDebounced() {
    if (!_isAppForeground) {
      return;
    }
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(_liveRefreshDebounceWindow, () {
      _refreshDebounceTimer = null;
      unawaited(refreshNow());
    });
  }

  Future<void> refreshNow({bool showLoading = false}) async {
    if (!_isAppForeground) return;
    if (_isFetching) return;
    if (_activeUserId == null || _activeUserId!.isEmpty) return;

    _isFetching = true;
    if (showLoading && (!state.loading || state.error != null)) {
      state = state.copyWith(loading: true, clearError: true);
    }

    try {
      await _refreshByStream();
      if (state.loading || state.error != null) {
        state = state.copyWith(loading: false, clearError: true);
      }
    } on DioException catch (error) {
      final status = error.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        await _refreshByLegacyEndpoint();
        if (state.loading || state.error != null) {
          state = state.copyWith(loading: false, clearError: true);
        }
      } else {
        state = state.copyWith(
          loading: false,
          error: error.message ?? 'Could not fetch notifications.',
        );
      }
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: 'Could not fetch notifications: $error',
      );
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _refreshByStream() async {
    final snapshot = await _fetchStream(
      afterId: _seededFromServer ? state.cursor : null,
    );
    final incoming = snapshot.items;
    final visibleIncoming = incoming.where(_isVisibleNotification).toList();
    if (!_seededFromServer) {
      _announcedIds.addAll(visibleIncoming.map((item) => item.id));
      _seededFromServer = true;
      state = state.copyWith(
        items: _mergeItemsNewestFirst(state.items, visibleIncoming),
        cursor: snapshot.cursor,
      );
      return;
    }

    if (incoming.isEmpty) {
      if (snapshot.cursor > state.cursor) {
        state = state.copyWith(cursor: snapshot.cursor);
      }
      return;
    }

    final fresh = visibleIncoming
        .where((item) => !_announcedIds.contains(item.id))
        .toList();
    if (fresh.isNotEmpty) {
      _announcedIds.addAll(fresh.map((item) => item.id));
    }

    state = state.copyWith(
      items: _mergeItemsNewestFirst(state.items, visibleIncoming),
      popupQueue: [...state.popupQueue, ...fresh],
      cursor: snapshot.cursor > state.cursor ? snapshot.cursor : state.cursor,
    );
  }

  Future<void> _refreshByLegacyEndpoint() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications/my',
      queryParameters: {'page': 0, 'size': _streamBatchSize},
    );
    final data = response.data ?? const <String, dynamic>{};
    final itemsJson = data['items'] as List<dynamic>? ?? const [];
    final incoming = itemsJson
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
    final visibleIncoming = incoming.where(_isVisibleNotification).toList();

    final maxIncomingId = _maxNotificationId(incoming);
    if (!_seededFromServer) {
      _announcedIds.addAll(visibleIncoming.map((item) => item.id));
      _seededFromServer = true;
      state = state.copyWith(
        items: _mergeItemsNewestFirst(state.items, visibleIncoming),
        cursor: maxIncomingId > state.cursor ? maxIncomingId : state.cursor,
      );
      return;
    }

    final fresh = visibleIncoming
        .where((item) => !_announcedIds.contains(item.id))
        .toList();
    if (fresh.isNotEmpty) {
      _announcedIds.addAll(fresh.map((item) => item.id));
    }

    state = state.copyWith(
      items: _mergeItemsNewestFirst(state.items, visibleIncoming),
      popupQueue: [...state.popupQueue, ...fresh.reversed],
      cursor: maxIncomingId > state.cursor ? maxIncomingId : state.cursor,
    );
  }

  Future<_NotificationStreamSnapshot> _fetchStream({int? afterId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications/stream',
      queryParameters: {
        'limit': _streamBatchSize,
        if (afterId != null && afterId > 0) 'afterId': afterId,
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    final cursor = (data['cursor'] as num?)?.toInt() ?? afterId ?? 0;
    final itemsJson = data['items'] as List<dynamic>? ?? const [];
    final items = itemsJson
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
    return _NotificationStreamSnapshot(cursor: cursor, items: items);
  }

  List<AppNotification> _mergeItemsNewestFirst(
    List<AppNotification> current,
    List<AppNotification> incoming,
  ) {
    final byId = <String, AppNotification>{};
    for (final item in current) {
      byId[item.id] = item;
    }
    for (final item in incoming) {
      byId[item.id] = item;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (merged.length > _maxNotificationItems) {
      return merged.take(_maxNotificationItems).toList();
    }
    return merged;
  }

  int _maxNotificationId(List<AppNotification> items) {
    var maxId = 0;
    for (final item in items) {
      final parsed = int.tryParse(item.id) ?? 0;
      if (parsed > maxId) {
        maxId = parsed;
      }
    }
    return maxId;
  }

  bool _isVisibleNotification(AppNotification item) {
    return item.payload['silent'] != true;
  }

  void consumePopup(String notificationId) {
    final queue = state.popupQueue
        .where((item) => item.id != notificationId)
        .toList();
    state = state.copyWith(popupQueue: queue);
  }

  void markSeen(String notificationId) {
    final seen = {...state.seenIds, notificationId};
    state = state.copyWith(seenIds: seen);
    unawaited(_persistSeenIds(seen));
  }

  void markAllSeen() {
    final seen = {...state.seenIds, ...state.items.map((item) => item.id)};
    state = state.copyWith(seenIds: seen);
    unawaited(_persistSeenIds(seen));
  }

  Future<void> deleteNotification(String notificationId) async {
    final normalizedId = notificationId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    final previous = state;
    final nextItems = previous.items
        .where((item) => item.id != normalizedId)
        .toList();
    final nextQueue = previous.popupQueue
        .where((item) => item.id != normalizedId)
        .toList();
    final nextSeen = {...previous.seenIds}..remove(normalizedId);
    _announcedIds.remove(normalizedId);
    state = previous.copyWith(
      items: nextItems,
      popupQueue: nextQueue,
      seenIds: nextSeen,
      clearError: true,
    );
    unawaited(_persistSeenIds(nextSeen));

    try {
      await _dio.delete('/notifications/$normalizedId');
    } on DioException catch (error) {
      final status = error.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        return;
      }
      state = previous.copyWith(
        error: error.message ?? 'Could not delete notification.',
      );
      await refreshNow();
    } catch (error) {
      state = previous.copyWith(
        error: 'Could not delete notification: $error',
      );
      await refreshNow();
    }
  }

  Future<void> clearAllNotifications() async {
    final previous = state;
    _announcedIds.clear();
    state = state.copyWith(
      items: const [],
      popupQueue: const [],
      seenIds: <String>{},
      clearError: true,
    );
    unawaited(_persistSeenIds(<String>{}));

    try {
      await _dio.delete('/notifications/my');
    } on DioException catch (error) {
      final status = error.response?.statusCode ?? 0;
      if (status == 404 || status == 405) {
        return;
      }
      state = previous.copyWith(
        error: error.message ?? 'Could not delete notifications.',
      );
      await refreshNow();
    } catch (error) {
      state = previous.copyWith(
        error: 'Could not delete notifications: $error',
      );
      await refreshNow();
    }
  }

  Future<void> _restoreSeenIdsForActiveUser() async {
    final userId = _activeUserId;
    if (userId == null || userId.isEmpty) return;

    final key = '$_seenKeyPrefix$userId';
    final restored = (_prefs.getStringList(key) ?? const [])
        .where((item) => item.trim().isNotEmpty)
        .map((item) => item.trim())
        .toSet();
    state = state.copyWith(seenIds: restored);
  }

  Future<void> _persistSeenIds(Set<String> seenIds) async {
    final userId = _activeUserId;
    if (userId == null || userId.isEmpty) return;
    final key = '$_seenKeyPrefix$userId';
    final trimmed = seenIds
        .where((item) => item.trim().isNotEmpty)
        .take(_seenIdsMax)
        .toList();
    await _prefs.setStringList(key, trimmed);
  }

  void _disconnectLiveEvents() {
    _liveEventsConnected = false;
    _liveEventsClient.disconnect();
  }
}

class _NotificationStreamSnapshot {
  const _NotificationStreamSnapshot({
    required this.cursor,
    required this.items,
  });

  final int cursor;
  final List<AppNotification> items;
}

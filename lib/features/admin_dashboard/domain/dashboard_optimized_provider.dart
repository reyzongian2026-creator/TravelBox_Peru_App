import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final String? etag;

  CacheEntry({
    required this.data,
    required this.timestamp,
    this.etag,
  });

  bool get isStale {
    return DateTime.now().difference(timestamp).inMinutes > 5;
  }

  bool get isVeryFresh {
    return DateTime.now().difference(timestamp).inSeconds < 30;
  }
}

class DashboardCache {
  final Map<String, CacheEntry<dynamic>> _cache = {};
  final Map<String, Completer<void>> _pendingRefresh = {};

  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry is CacheEntry<T>) return entry.data;
    return null;
  }

  void set<T>(String key, T data, {String? etag}) {
    _cache[key] = CacheEntry<T>(
      data: data,
      timestamp: DateTime.now(),
      etag: etag,
    );
  }

  void invalidate(String key) {
    _cache.remove(key);
  }

  void invalidateAll() {
    _cache.clear();
  }

  bool hasKey(String key) => _cache.containsKey(key);

  bool isPending(String key) => _pendingRefresh[key]?.isCompleted == false;

  Completer<void> markPending(String key) {
    if (_pendingRefresh[key]?.isCompleted == false) {
      return _pendingRefresh[key]!;
    }
    final completer = Completer<void>();
    _pendingRefresh[key] = completer;
    return completer;
  }

  void markComplete(String key) {
    _pendingRefresh[key]?.complete();
    _pendingRefresh.remove(key);
  }

  String? getEtag(String key) {
    final entry = _cache[key];
    return entry?.etag;
  }
}

final dashboardCacheProvider = Provider<DashboardCache>((ref) {
  return DashboardCache();
});

final dashboardStatsProvider =
    StateNotifierProvider<DashboardStatsNotifier, AsyncValue<Map<String, dynamic>>>(
  (ref) => DashboardStatsNotifier(ref),
);

class DashboardStatsNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final Ref _ref;
  Timer? _refreshTimer;
  String _currentPeriod = 'month';

  DashboardStatsNotifier(this._ref) : super(const AsyncValue.data({}));

  void setPeriod(String period) {
    if (_currentPeriod != period) {
      _currentPeriod = period;
      refresh();
    }
  }

  Future<void> refresh({bool force = false}) async {
    final cache = _ref.read(dashboardCacheProvider);
    final cacheKey = 'dashboard_$_currentPeriod';
    final cached = cache.get<Map<String, dynamic>>(cacheKey);

    if (!force && cached != null) {
      state = AsyncValue.data(cached);
      return;
    }

    if (state.isLoading) return;

    if (cached != null && !force) {
      state = AsyncValue.data(cached);
    } else {
      state = const AsyncValue.loading();
    }

    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get<Map<String, dynamic>>(
        '/admin/dashboard',
        queryParameters: {'period': _currentPeriod},
        options: Options(
          headers: {
            if (cache.getEtag(cacheKey) != null)
              'If-None-Match': cache.getEtag(cacheKey),
          },
        ),
      );

      if (response.statusCode == 304) {
        return;
      }

      final data = response.data ?? <String, dynamic>{};
      cache.set(cacheKey, data, etag: response.headers.value('etag'));
      state = AsyncValue.data(data);
    } catch (e, st) {
      if (cached != null) {
        state = AsyncValue.data(cached);
        return;
      }
      state = AsyncValue.error(e, st);
    }
  }

  void updateFromRealtime(Map<String, dynamic> delta) {
    final current = state.valueOrNull ?? {};
    final updated = _mergeDeltas(current, delta);
    state = AsyncValue.data(updated);
  }

  Map<String, dynamic> _mergeDeltas(
    Map<String, dynamic> current,
    Map<String, dynamic> delta,
  ) {
    final result = Map<String, dynamic>.from(current);
    for (final entry in delta.entries) {
      if (entry.value is Map && result[entry.key] is Map) {
        result[entry.key] = _mergeDeltas(
          result[entry.key] as Map<String, dynamic>,
          entry.value as Map<String, dynamic>,
        );
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

final dashboardKPIsProvider = Provider<Map<String, dynamic>?>((ref) {
  final stats = ref.watch(dashboardStatsProvider);
  return stats.valueOrNull?['summary'];
});

final dashboardTopWarehousesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final stats = ref.watch(dashboardStatsProvider);
  return (stats.valueOrNull?['topWarehouses'] as List?)?.cast() ?? [];
});

final dashboardTopCitiesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final stats = ref.watch(dashboardStatsProvider);
  return (stats.valueOrNull?['topCities'] as List?)?.cast() ?? [];
});

final dashboardTrendProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final stats = ref.watch(dashboardStatsProvider);
  return (stats.valueOrNull?['trend'] as List?)?.cast() ?? [];
});

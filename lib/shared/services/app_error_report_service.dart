import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppErrorReportService {
  AppErrorReportService(this._dio);

  final Dio _dio;
  final List<AppErrorEntry> _pendingErrors = [];
  Timer? _flushTimer;
  bool _isReporting = false;

  static const _storageKey = 'app_pending_errors';
  static const _sessionStateKey = 'travelbox.session.v2';
  static const _batchSize = 10;
  static const _flushInterval = Duration(seconds: 5);

  static AppErrorReportService? _instance;
  static AppErrorReportService? _preInitializedInstance;

  static void setPreInitializedInstance(AppErrorReportService service) {
    _preInitializedInstance = service;
  }

  static Future<AppErrorReportService> getInstance(Dio dio) async {
    if (_instance != null) return _instance!;
    if (_preInitializedInstance != null) {
      _instance = _preInitializedInstance;
      return _instance!;
    }
    _instance = AppErrorReportService(dio);
    await _instance!._loadFromStorage();
    return _instance!;
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      if (stored != null && stored.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(stored);
        _pendingErrors.addAll(
          decoded.map((e) => AppErrorEntry.fromJson(e as Map<String, dynamic>)),
        );
        if (kDebugMode) {
          debugPrint(
            '[ERROR] Loaded ${_pendingErrors.length} pending errors from storage',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ERROR] Failed to load errors from storage: $e');
      }
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _pendingErrors.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ERROR] Failed to save errors to storage: $e');
      }
    }
  }

  void reportI18nError(
    String locale,
    String key,
    String? context,
    String? userId,
  ) {
    final entry = AppErrorEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_i18n_${key.hashCode}',
      type: ErrorType.i18n,
      key: key,
      locale: locale,
      timestamp: DateTime.now(),
      context: context ?? 'unknown',
      reportedBy: userId ?? 'anonymous',
      message: 'Missing translation: $key',
      stackTrace: null,
      additionalData: {'errorType': 'i18n'},
    );
    _addError(entry);
  }

  void reportNetworkError(
    String endpoint,
    int? statusCode,
    String message,
    String? stackTrace,
    String? requestBody,
  ) {
    final entry = AppErrorEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_net_${endpoint.hashCode}',
      type: ErrorType.network,
      key: 'NETWORK_ERROR',
      locale: 'network',
      timestamp: DateTime.now(),
      context: endpoint,
      reportedBy: 'system',
      message: message,
      stackTrace: stackTrace,
      additionalData: {
        'errorType': 'network',
        'endpoint': endpoint,
        'statusCode': statusCode,
        if (requestBody case String body) 'requestBody': body,
      },
    );
    _addError(entry);
  }

  void reportFlutterError(
    Object error,
    StackTrace? stackTrace,
    String? context,
  ) {
    final entry = AppErrorEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_flutter_${error.hashCode}',
      type: ErrorType.flutter,
      key: 'FLUTTER_ERROR',
      locale: 'flutter',
      timestamp: DateTime.now(),
      context: context ?? 'unknown',
      reportedBy: 'system',
      message: error.toString(),
      stackTrace: stackTrace?.toString(),
      additionalData: {'errorType': 'flutter'},
    );
    _addError(entry);
  }

  void reportValidationError(String field, String message, String? context) {
    final entry = AppErrorEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_val_${field.hashCode}',
      type: ErrorType.validation,
      key: 'VALIDATION_ERROR',
      locale: 'validation',
      timestamp: DateTime.now(),
      context: context ?? field,
      reportedBy: 'system',
      message: '$field: $message',
      stackTrace: null,
      additionalData: {'errorType': 'validation', 'field': field},
    );
    _addError(entry);
  }

  void reportOperationError(
    String operation,
    String message,
    String? stackTrace, {
    String? userId,
  }) {
    final entry = AppErrorEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_op_${operation.hashCode}',
      type: ErrorType.operation,
      key: 'OPERATION_ERROR',
      locale: 'operation',
      timestamp: DateTime.now(),
      context: operation,
      reportedBy: userId ?? 'system',
      message: message,
      stackTrace: stackTrace,
      additionalData: {'errorType': 'operation', 'operation': operation},
    );
    _addError(entry);
  }

  void reportSocialAuthError(String service, String code, String message) {
    final entry = AppErrorEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_social_${code.hashCode}',
      type: ErrorType.socialAuth,
      key: 'SOCIAL_AUTH_ERROR',
      locale: 'social-auth',
      timestamp: DateTime.now(),
      context: service,
      reportedBy: 'system',
      message: '$service: $code - $message',
      stackTrace: null,
      additionalData: {
        'errorType': 'social-auth',
        'service': service,
        'code': code,
      },
    );
    _addError(entry);
  }

  void _addError(AppErrorEntry entry) {
    _pendingErrors.add(entry);
    _saveToStorage();

    if (kDebugMode) {
      debugPrint('[ERROR] Reported ${entry.type.name} error: ${entry.message}');
    }

    if (_pendingErrors.length >= _batchSize) {
      _flush();
    } else {
      _scheduleFlush();
    }
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushInterval, _flush);
  }

  Future<void> _flush() async {
    if (_isReporting || _pendingErrors.isEmpty) return;
    if (!await _canSyncToAdminEndpoint()) return;

    _isReporting = true;
    final errorsToSend = List<AppErrorEntry>.from(_pendingErrors);
    _pendingErrors.clear();
    await _saveToStorage();

    try {
      await _dio.post(
        '/admin/i18n-report/errors',
        data: {
          'locale': _getMostCommonLocale(errorsToSend),
          'keys': errorsToSend.map((e) => '${e.type.name}:${e.key}').toList(),
          'context': errorsToSend
              .map((e) => '${e.type.name}:${e.context}')
              .join('|'),
          'reportedBy': _getMostCommonReporter(errorsToSend),
        },
      );

      if (kDebugMode) {
        debugPrint('[ERROR] Synced ${errorsToSend.length} errors to backend');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 0;
      if (statusCode == 401 || statusCode == 403) {
        if (kDebugMode) {
          debugPrint(
            '[ERROR] Skipping admin error sync due to auth status $statusCode',
          );
        }
        return;
      }
      _pendingErrors.addAll(errorsToSend);
      await _saveToStorage();

      if (kDebugMode) {
        debugPrint('[ERROR] Failed to sync errors: $e');
      }
    } catch (e) {
      _pendingErrors.addAll(errorsToSend);
      await _saveToStorage();

      if (kDebugMode) {
        debugPrint('[ERROR] Failed to sync errors: $e');
      }
    } finally {
      _isReporting = false;
    }
  }

  Future<bool> _canSyncToAdminEndpoint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawSession = prefs.getString(_sessionStateKey);
      if (rawSession == null || rawSession.isEmpty) {
        return false;
      }
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      final user = decoded['user'];
      if (user is! Map<String, dynamic>) {
        return false;
      }
      final role = user['role']?.toString().trim().toUpperCase() ?? '';
      return role == 'ADMIN';
    } catch (_) {
      return false;
    }
  }

  String _getMostCommonLocale(List<AppErrorEntry> errors) {
    if (errors.isEmpty) return 'unknown';
    final localeCounts = <String, int>{};
    for (final error in errors) {
      localeCounts[error.locale] = (localeCounts[error.locale] ?? 0) + 1;
    }
    return localeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String _getMostCommonReporter(List<AppErrorEntry> errors) {
    if (errors.isEmpty) return 'anonymous';
    final reporterCounts = <String, int>{};
    for (final error in errors) {
      final reporter = error.reportedBy ?? 'anonymous';
      reporterCounts[reporter] = (reporterCounts[reporter] ?? 0) + 1;
    }
    final maxEntry = reporterCounts.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    return maxEntry.key;
  }

  Future<void> forceFlush() async {
    await _flush();
  }

  Future<void> clearErrors() async {
    _pendingErrors.clear();
    await _saveToStorage();
  }

  List<AppErrorEntry> getPendingErrors() {
    return List.unmodifiable(_pendingErrors);
  }

  int get pendingCount => _pendingErrors.length;

  String exportToJsonSync() {
    final errors = getPendingErrors();
    final byType = <String, int>{};
    for (final error in errors) {
      byType[error.type.name] = (byType[error.type.name] ?? 0) + 1;
    }

    final report = {
      'application': 'InkaVoy Peru',
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'totalErrors': errors.length,
      'errorsByType': byType,
      'errors': errors.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(report);
  }

  void dispose() {
    _flushTimer?.cancel();
  }
}

enum ErrorType {
  i18n,
  network,
  flutter,
  validation,
  operation,
  socialAuth,
  unknown,
}

class AppErrorEntry {
  AppErrorEntry({
    required this.id,
    required this.type,
    required this.key,
    required this.locale,
    required this.timestamp,
    required this.context,
    required this.reportedBy,
    required this.message,
    this.stackTrace,
    this.additionalData,
  });

  final String id;
  final ErrorType type;
  final String key;
  final String locale;
  final DateTime timestamp;
  final String context;
  final String? reportedBy;
  final String message;
  final String? stackTrace;
  final Map<String, dynamic>? additionalData;

  factory AppErrorEntry.fromJson(Map<String, dynamic> json) {
    return AppErrorEntry(
      id: json['id'] as String,
      type: ErrorType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ErrorType.unknown,
      ),
      key: json['key'] as String,
      locale: json['locale'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      context: json['context'] as String? ?? 'unknown',
      reportedBy: json['reportedBy'] as String? ?? 'anonymous',
      message: json['message'] as String? ?? '',
      stackTrace: json['stackTrace'] as String?,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'key': key,
    'locale': locale,
    'timestamp': timestamp.toIso8601String(),
    'context': context,
    'reportedBy': reportedBy,
    'message': message,
    if (stackTrace != null) 'stackTrace': stackTrace,
    if (additionalData != null) 'additionalData': additionalData,
  };
}

class AppErrorReportNotifier extends StateNotifier<AppErrorReportState> {
  AppErrorReportNotifier(Dio? dio)
    : _dio = dio,
      super(
        AppErrorReportState(errors: [], isLoading: false, isSyncing: false),
      ) {
    _init();
  }

  final Dio? _dio;
  AppErrorReportService? _service;

  static AppErrorReportService? _globalService;

  static void setGlobalService(AppErrorReportService service) {
    _globalService = service;
  }

  static AppErrorReportService? getGlobalService() {
    return _globalService;
  }

  static Future<String> exportAndClearBeforeLogout() async {
    if (_globalService != null) {
      await _globalService!.forceFlush();
      final json = _globalService!.exportToJsonSync();
      await _globalService!.clearErrors();
      return json;
    }
    return '{"application": "InkaVoy Peru", "version": "1.0", "exportedAt": "${DateTime.now().toIso8601String()}", "totalErrors": 0, "errors": [], "errorsByType": {}}';
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      if (_dio != null) {
        _service = await AppErrorReportService.getInstance(_dio);
      }
      state = state.copyWith(
        errors: _service?.getPendingErrors() ?? [],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, lastError: e.toString());
    }
  }

  Future<void> syncNow() async {
    if (_service == null) return;

    state = state.copyWith(isSyncing: true);
    try {
      await _service!.forceFlush();
      state = state.copyWith(
        errors: _service!.getPendingErrors(),
        isSyncing: false,
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isSyncing: false, lastError: e.toString());
    }
  }

  Future<String> exportToJson() async {
    final errors = _service?.getPendingErrors() ?? [];
    final byType = <String, int>{};
    for (final error in errors) {
      byType[error.type.name] = (byType[error.type.name] ?? 0) + 1;
    }

    final report = {
      'application': 'InkaVoy Peru',
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'totalErrors': errors.length,
      'errorsByType': byType,
      'errors': errors.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(report);
  }

  Future<void> clearLocal() async {
    await _service?.clearErrors();
    state = state.copyWith(errors: []);
  }

  Future<String> syncAndExportBeforeLogout() async {
    await syncNow();
    final json = await exportToJson();
    await clearLocal();
    return json;
  }
}

class AppErrorReportState {
  AppErrorReportState({
    required this.errors,
    required this.isLoading,
    required this.isSyncing,
    this.lastSyncTime,
    this.lastError,
  });

  final List<AppErrorEntry> errors;
  final bool isLoading;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? lastError;

  AppErrorReportState copyWith({
    List<AppErrorEntry>? errors,
    bool? isLoading,
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? lastError,
  }) {
    return AppErrorReportState(
      errors: errors ?? this.errors,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastError: lastError ?? this.lastError,
    );
  }
}

final appErrorReportNotifierProvider =
    StateNotifierProvider<AppErrorReportNotifier, AppErrorReportState>((ref) {
      return AppErrorReportNotifier(null);
    });

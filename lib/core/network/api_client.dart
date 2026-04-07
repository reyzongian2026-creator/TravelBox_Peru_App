import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../shared/models/app_user.dart';
import '../../shared/services/app_error_report_service.dart';
import '../../shared/state/local_realtime_mutation_tick_provider.dart';
import '../../shared/state/session_controller.dart';
import '../env/app_env.dart';

const _retryableStatusCodes = <int>{502, 503, 504};

bool _isRefreshing = false;

final dioProvider = Provider<Dio>((ref) {
  ref.watch(sessionControllerProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppEnv.resolvedApiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    RetryInterceptor(
      dio: dio,
      retries: 3,
      retryDelays: const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 3),
      ],
      retryEvaluator: (error, _) {
        final request = error.requestOptions;
        if (_shouldSkipRetry(request)) {
          return false;
        }
        final statusCode = error.response?.statusCode;
        final transientStatus =
            statusCode != null && _retryableStatusCodes.contains(statusCode);
        final socketExceptionLike =
            error.type == DioExceptionType.connectionError &&
            error.error?.toString().contains('SocketException') == true;
        return socketExceptionLike || transientStatus;
      },
    ),
  );

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(sessionControllerProvider).accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['X-Correlation-Id'] ??=
            'flutter-${DateTime.now().microsecondsSinceEpoch}';
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (_shouldBumpRealtimeTick(response.requestOptions)) {
          final notifier = ref.read(localRealtimeMutationTickProvider.notifier);
          final current = notifier.state;
          notifier.state = current >= 900000 ? 0 : current + 1;
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final request = error.requestOptions;
        final alreadyRetried = request.extra['__retried'] == true;
        final isAuthEndpoint = request.path.startsWith('/auth/');

        _reportNetworkError(error);

        if (statusCode == 401 && !alreadyRetried && !isAuthEndpoint) {
          if (!_isRefreshing) {
            _isRefreshing = true;
            try {
              final session = ref.read(sessionControllerProvider);
              final refreshToken = session.refreshToken;
              if (refreshToken != null && refreshToken.isNotEmpty) {
                final refreshDio = Dio(
                  BaseOptions(
                    baseUrl: AppEnv.resolvedApiBaseUrl,
                    connectTimeout: const Duration(seconds: 20),
                    receiveTimeout: const Duration(seconds: 45),
                    sendTimeout: const Duration(seconds: 10),
                    headers: {'Content-Type': 'application/json'},
                  ),
                );
                final refreshResponse = await refreshDio
                    .post<Map<String, dynamic>>(
                      '/auth/refresh',
                      data: {'refreshToken': refreshToken},
                    );
                final refreshData = refreshResponse.data ?? <String, dynamic>{};
                final newAccessToken =
                    refreshData['accessToken']?.toString() ?? '';
                final newRefreshToken =
                    refreshData['refreshToken']?.toString() ?? refreshToken;

                if (newAccessToken.isNotEmpty && session.user != null) {
                  final refreshedUser = _resolveUserFromRefresh(
                    currentUser: session.user!,
                    refreshData: refreshData,
                  );
                  await ref
                      .read(sessionControllerProvider.notifier)
                      .signIn(
                        user: refreshedUser,
                        accessToken: newAccessToken,
                        refreshToken: newRefreshToken,
                      );

                  request.headers['Authorization'] = 'Bearer $newAccessToken';
                  request.extra['__retried'] = true;
                  final retryResponse = await dio.fetch(request);

                  _isRefreshing = false;
                  handler.resolve(retryResponse);
                  return;
                }
              }
            } catch (e) {
              debugPrint('Token refresh failed: $e');
            } finally {
              _isRefreshing = false;
            }
          }

          _showSessionExpiredSnackBar();
          await ref.read(sessionControllerProvider.notifier).signOut();
          handler.next(error);
          return;
        }

        if (statusCode == 401) {
          _showSessionExpiredSnackBar();
          await ref.read(sessionControllerProvider.notifier).signOut();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

void _showSessionExpiredSnackBar() {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: const Row(
        children: [
          Icon(Icons.logout, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.',
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () => messenger.hideCurrentSnackBar(),
      ),
    ),
  );
}

void _reportNetworkError(DioException error) {
  final service = AppErrorReportNotifier.getGlobalService();
  if (service == null) return;
  if (!_shouldReportNetworkError(error)) return;

  final endpoint = error.requestOptions.path;
  final statusCode = error.response?.statusCode;
  final message = error.message ?? 'Unknown error';
  final stackTrace = error.stackTrace.toString();

  String? requestBody;
  try {
    final data = error.requestOptions.data;
    if (data != null) {
      if (data is Map || data is FormData) {
        requestBody = data.toString();
      }
    }
  } catch (e) {
    debugPrint('[ApiClient] Error reading request body: $e');
  }

  service.reportNetworkError(
    endpoint,
    statusCode,
    message,
    stackTrace,
    requestBody,
  );

  if (kDebugMode) {
    debugPrint('[NETWORK ERROR] $statusCode $endpoint - $message');
  }
}

bool _shouldReportNetworkError(DioException error) {
  final statusCode = error.response?.statusCode;
  final path = error.requestOptions.path.toLowerCase();
  if (statusCode == 401 &&
      (path.startsWith('/notifications/stream') ||
          path.startsWith('/notifications/events'))) {
    return false;
  }
  return true;
}

bool _shouldSkipRetry(RequestOptions request) {
  final path = request.path.toLowerCase();
  if (path.startsWith('/auth/')) {
    return true;
  }
  if (request.data is FormData) {
    return true;
  }
  return false;
}

bool _shouldBumpRealtimeTick(RequestOptions request) {
  final method = request.method.trim().toUpperCase();
  if (method != 'POST' &&
      method != 'PUT' &&
      method != 'PATCH' &&
      method != 'DELETE') {
    return false;
  }
  final path = request.path.toLowerCase();
  if (path.startsWith('/auth/')) {
    return false;
  }
  return true;
}

AppUser _resolveUserFromRefresh({
  required AppUser currentUser,
  required Map<String, dynamic> refreshData,
}) {
  final nestedUser = refreshData['user'];
  final mapped = AppUser.fromJson(
    nestedUser is Map<String, dynamic>
        ? nestedUser
        : {
            'id': refreshData['userId'] ?? refreshData['id'] ?? currentUser.id,
            'name':
                refreshData['fullName'] ??
                refreshData['name'] ??
                currentUser.name,
            'email': refreshData['email'] ?? currentUser.email,
            'role': refreshData['role'],
            'roles': refreshData['roles'],
            'phone': refreshData['phone'] ?? currentUser.phone,
            'nationality':
                refreshData['nationality'] ?? currentUser.nationality,
            'preferredLanguage':
                refreshData['preferredLanguage'] ??
                currentUser.preferredLanguage,
            'emailVerified':
                refreshData['emailVerified'] ?? currentUser.emailVerified,
            'profileCompleted':
                refreshData['profileCompleted'] ?? currentUser.profileCompleted,
          },
  );

  if (mapped.id.isEmpty || mapped.email.isEmpty || mapped.name.isEmpty) {
    return currentUser;
  }
  return mapped;
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/app_user.dart';
import '../../shared/state/session_controller.dart';
import '../env/app_env.dart';

final dioProvider = Provider<Dio>((ref) {
  ref.watch(sessionControllerProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppEnv.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 45),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(sessionControllerProvider).accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['X-Correlation-Id'] ??=
            'flutter-${DateTime.now().microsecondsSinceEpoch}';
        handler.next(options);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final request = error.requestOptions;
        final alreadyRetried = request.extra['__retried'] == true;
        final isAuthEndpoint = request.path.startsWith('/auth/');

        if (statusCode == 401 && !alreadyRetried && !isAuthEndpoint) {
          final session = ref.read(sessionControllerProvider);
          final refreshToken = session.refreshToken;
          if (refreshToken != null && refreshToken.isNotEmpty) {
            try {
              final refreshDio = Dio(
                BaseOptions(
                  baseUrl: AppEnv.apiBaseUrl,
                  connectTimeout: const Duration(seconds: 20),
                  receiveTimeout: const Duration(seconds: 45),
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
                handler.resolve(retryResponse);
                return;
              }
            } catch (_) {}
          }

          await ref.read(sessionControllerProvider.notifier).signOut();
          handler.next(error);
          return;
        }

        if (statusCode == 401) {
          await ref.read(sessionControllerProvider.notifier).signOut();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

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
            'name': refreshData['fullName'] ?? refreshData['name'] ?? currentUser.name,
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

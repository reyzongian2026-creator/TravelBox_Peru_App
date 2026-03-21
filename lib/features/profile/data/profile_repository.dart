import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class ProfileRepository {
  Future<OnboardingStatus> getOnboardingStatus();
  Future<OnboardingStatus> completeOnboarding();
}

class OnboardingStatus {
  final bool profileCompleted;
  final bool emailVerified;
  final bool onboardingCompleted;
  final List<String> pendingSteps;
  final DateTime? completedAt;

  const OnboardingStatus({
    required this.profileCompleted,
    required this.emailVerified,
    required this.onboardingCompleted,
    required this.pendingSteps,
    this.completedAt,
  });

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    final pendingStepsRaw = json['pendingSteps'] as List<dynamic>? ?? [];
    return OnboardingStatus(
      profileCompleted: json['profileCompleted'] as bool? ?? false,
      emailVerified: json['emailVerified'] as bool? ?? false,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      pendingSteps: pendingStepsRaw.map((e) => e.toString()).toList(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
    );
  }

  factory OnboardingStatus.initial() {
    return const OnboardingStatus(
      profileCompleted: false,
      emailVerified: false,
      onboardingCompleted: false,
      pendingSteps: ['profile', 'email_verification', 'onboarding'],
    );
  }

  int get progressPercentage {
    if (onboardingCompleted) return 100;
    int completed = 0;
    if (profileCompleted) completed++;
    if (emailVerified) completed++;
    if (onboardingCompleted) completed++;
    return ((completed / 3) * 100).round();
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(dio: ref.watch(dioProvider));
});

class ProfileRepositoryImpl implements ProfileRepository {
  final Dio _dio;

  ProfileRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<OnboardingStatus> getOnboardingStatus() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/profile/me/onboarding-status',
      );

      final data = response.data;
      if (data == null) {
        return OnboardingStatus.initial();
      }

      return OnboardingStatus.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return OnboardingStatus.initial();
      }
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<OnboardingStatus> completeOnboarding() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/profile/me/onboarding-complete',
      );

      final data = response.data;
      if (data == null) {
        return const OnboardingStatus(
          profileCompleted: true,
          emailVerified: true,
          onboardingCompleted: true,
          pendingSteps: [],
        );
      }

      return OnboardingStatus.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_exception.dart';
import '../../incidents/data/selected_evidence_image.dart';

final profileRepositoryProvider = Provider<ProfileRepositoryImpl>((ref) {
  return ProfileRepositoryImpl(dio: ref.watch(dioProvider), ref: ref);
});

class ProfileUpdateResult {
  const ProfileUpdateResult({required this.user, this.verificationCodePreview});

  final AppUser user;
  final String? verificationCodePreview;
}

class ProfileRepositoryImpl {
  ProfileRepositoryImpl({required Dio dio, required Ref ref})
    : _dio = dio,
      _ref = ref;

  final Dio _dio;
  final Ref _ref;

  Future<AppUser> getMyProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/profile/me');
      final data = response.data ?? <String, dynamic>{};
      return _mergeWithCurrentUser(AppUser.fromJson(data));
    } catch (error) {
      final currentUser = _ref.read(sessionControllerProvider).user;
      if (currentUser != null && AppEnv.useMockFallback) {
        return currentUser;
      }
      if (error is DioException) {
        throw AppException.fromDioError(error);
      }
      throw AppException.fromError(error);
    }
  }

  Future<ProfileUpdateResult> updateProfile({
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/profile/me',
        data: payload,
      );
      final data = response.data ?? <String, dynamic>{};
      return ProfileUpdateResult(
        user: _mergeWithCurrentUser(AppUser.fromJson(data)),
        verificationCodePreview: data['verificationCodePreview']?.toString(),
      );
    } catch (error) {
      if (!AppEnv.useMockFallback) {
        if (error is DioException) {
          throw AppException.fromDioError(error);
        }
        throw AppException.fromError(error);
      }
      final currentUser = _ref.read(sessionControllerProvider).user;
      if (currentUser == null) {
        if (error is DioException) {
          throw AppException.fromDioError(error);
        }
        throw AppException.fromError(error);
      }
      final updatedUser = currentUser.copyWith(
        firstName: payload['firstName']?.toString() ?? currentUser.firstName,
        lastName: payload['lastName']?.toString() ?? currentUser.lastName,
        name:
            '${payload['firstName']?.toString() ?? currentUser.firstName} ${payload['lastName']?.toString() ?? currentUser.lastName}'
                .trim(),
        email: payload['email']?.toString() ?? currentUser.email,
        phone: payload['phone']?.toString() ?? currentUser.phone,
        nationality:
            payload['nationality']?.toString() ?? currentUser.nationality,
        preferredLanguage:
            payload['preferredLanguage']?.toString() ??
            currentUser.preferredLanguage,
        address: payload['address']?.toString() ?? currentUser.address,
        city: payload['city']?.toString() ?? currentUser.city,
        country: payload['country']?.toString() ?? currentUser.country,
        gender: payload['gender']?.toString() ?? currentUser.gender,
        documentType:
            payload['documentType']?.toString() ?? currentUser.documentType,
        documentNumber:
            payload['documentNumber']?.toString() ?? currentUser.documentNumber,
        secondaryDocumentType:
            payload['secondaryDocumentType']?.toString() ??
            currentUser.secondaryDocumentType,
        secondaryDocumentNumber:
            payload['secondaryDocumentNumber']?.toString() ??
            currentUser.secondaryDocumentNumber,
        emergencyContactName:
            payload['emergencyContactName']?.toString() ??
            currentUser.emergencyContactName,
        emergencyContactPhone:
            payload['emergencyContactPhone']?.toString() ??
            currentUser.emergencyContactPhone,
        profilePhotoPath:
            payload['profilePhotoPath']?.toString() ??
            currentUser.profilePhotoPath,
        emailVerified: payload['email'] != null
            ? false
            : currentUser.emailVerified,
        profileCompleted: true,
      );
      return ProfileUpdateResult(
        user: updatedUser,
        verificationCodePreview: payload['email'] != null ? '123456' : null,
      );
    }
  }

  Future<AppUser> uploadProfilePhoto({
    required SelectedEvidenceImage image,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/profile/me/photo',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(
            image.bytes,
            filename: image.filename,
            contentType: MediaType.parse(image.mimeType),
          ),
        }),
      );
      final data = response.data ?? <String, dynamic>{};
      return _mergeWithCurrentUser(AppUser.fromJson(data));
    } on DioException catch (error) {
      throw AppException.fromDioError(error);
    }
  }

  AppUser _mergeWithCurrentUser(AppUser incoming) {
    final currentUser = _ref.read(sessionControllerProvider).user;
    if (currentUser == null) return incoming;
    return currentUser.copyWith(
      id: incoming.id.isEmpty ? currentUser.id : incoming.id,
      name: incoming.name,
      email: incoming.email,
      role: incoming.role,
      firstName: incoming.firstName,
      lastName: incoming.lastName,
      phone: incoming.phone,
      nationality: incoming.nationality,
      preferredLanguage: incoming.preferredLanguage,
      authProvider: incoming.authProvider,
      managedByAdmin: incoming.managedByAdmin,
      canSelfEditProfile: incoming.canSelfEditProfile,
      vehiclePlate: incoming.vehiclePlate,
      profilePhotoPath: incoming.profilePhotoPath,
      emailVerified: incoming.emailVerified,
      profileCompleted: incoming.profileCompleted,
      emailChangeRemaining: incoming.emailChangeRemaining,
      phoneChangeRemaining: incoming.phoneChangeRemaining,
      documentChangeRemaining: incoming.documentChangeRemaining,
      birthDate: incoming.birthDate,
      gender: incoming.gender,
      address: incoming.address,
      city: incoming.city,
      country: incoming.country,
      documentType: incoming.documentType,
      documentNumber: incoming.documentNumber,
      secondaryDocumentType: incoming.secondaryDocumentType,
      secondaryDocumentNumber: incoming.secondaryDocumentNumber,
      emergencyContactName: incoming.emergencyContactName,
      emergencyContactPhone: incoming.emergencyContactPhone,
    );
  }
}

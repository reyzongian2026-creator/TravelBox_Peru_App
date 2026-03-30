import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class AdminUsersRepository {
  Future<List<AdminUser>> getUsers();
  Future<PagedResult<AdminUser>> getUsersPage({int page = 0, int size = 20, String? search, String? role});
  Future<UserSummary> getUserSummary();
  Future<AdminUser> createUser(CreateUserRequest request);
  Future<AdminUser> updateUser(int userId, UpdateUserRequest request);
  Future<void> updateUserRoles({required int userId, required List<String> roles});
  Future<void> updateUserActive(int userId, bool active);
  Future<void> updateUserPassword(int userId, String newPassword);
  Future<String> uploadDocumentPhoto(String filePath);
  Future<void> deleteUser(int userId);
  BulkOperationResult bulkDelete(Set<int> ids);
  BulkOperationResult bulkUpdateActive(Set<int> ids, bool active);
  BulkOperationResult bulkUpdateRoles(Set<int> ids, List<String> roles);
  String getExportUrl();
}

class CreateUserRequest {
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final List<String> roles;
  final String? nationality;

  CreateUserRequest({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.roles,
    this.nationality,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'roles': roles,
        if (nationality != null) 'nationality': nationality,
      };
}

class UpdateUserRequest {
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? nationality;

  UpdateUserRequest({this.firstName, this.lastName, this.phone, this.nationality});

  Map<String, dynamic> toJson() => {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (phone != null) 'phone': phone,
        if (nationality != null) 'nationality': nationality,
      };
}

class AdminUser {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final List<String> roles;
  final String? nationality;
  final bool active;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  AdminUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.roles,
    this.nationality,
    required this.active,
    required this.emailVerified,
    required this.createdAt,
    this.lastLoginAt,
  });

  String get fullName => '$firstName $lastName';

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: (json['id'] as int?) ?? 0,
      email: json['email']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      nationality: json['nationality']?.toString(),
      active: (json['active'] as bool?) ?? false,
      emailVerified: (json['emailVerified'] as bool?) ?? false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null ? DateTime.tryParse(json['lastLoginAt'].toString()) : null,
    );
  }
}

class UserSummary {
  final int totalUsers;
  final int activeUsers;
  final int inactiveUsers;
  final Map<String, int> usersByRole;
  final int verifiedEmails;
  final int unverifiedEmails;

  UserSummary({
    required this.totalUsers,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.usersByRole,
    required this.verifiedEmails,
    required this.unverifiedEmails,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    final roleMap = <String, int>{};
    final rolesData = json['usersByRole'] as Map<String, dynamic>? ?? json['rolesCount'] as Map<String, dynamic>?;
    if (rolesData != null) {
      rolesData.forEach((key, value) {
        roleMap[key] = (value as int?) ?? 0;
      });
    }
    return UserSummary(
      totalUsers: (json['totalUsers'] as int?) ?? json['total'] as int? ?? 0,
      activeUsers: (json['activeUsers'] as int?) ?? json['active'] as int? ?? 0,
      inactiveUsers: (json['inactiveUsers'] as int?) ?? json['inactive'] as int? ?? 0,
      usersByRole: roleMap,
      verifiedEmails: (json['verifiedEmails'] as int?) ?? 0,
      unverifiedEmails: (json['unverifiedEmails'] as int?) ?? 0,
    );
  }
}

class PagedResult<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  PagedResult({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final contentList =
        json['items'] as List<dynamic>? ??
        json['content'] as List<dynamic>? ??
        [];
    final hasNext = json['hasNext'] as bool? ?? false;
    return PagedResult(
      content: contentList.map((e) => fromJsonT(e as Map<String, dynamic>)).toList(),
      page: (json['page'] as int?) ?? 0,
      size: (json['size'] as int?) ?? json['pageSize'] as int? ?? 20,
      totalElements: (json['totalElements'] as int?) ?? json['total'] as int? ?? 0,
      totalPages: (json['totalPages'] as int?) ?? json['pages'] as int? ?? 0,
      last: (json['last'] as bool?) ?? !hasNext,
    );
  }
}

class BulkOperationResult {
  final int processed;
  final int succeeded;
  final int failed;
  final String message;

  BulkOperationResult({
    required this.processed,
    required this.succeeded,
    required this.failed,
    required this.message,
  });

  factory BulkOperationResult.fromJson(Map<String, dynamic> json) {
    return BulkOperationResult(
      processed: json['processed'] as int? ?? 0,
      succeeded: json['succeeded'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}

final adminUsersRepositoryProvider = Provider<AdminUsersRepository>((ref) {
  return AdminUsersRepositoryImpl(dio: ref.watch(dioProvider));
});

class AdminUsersRepositoryImpl implements AdminUsersRepository {
  final Dio _dio;

  AdminUsersRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<List<AdminUser>> getUsers() async {
    try {
      final response = await _dio.get<List<dynamic>>('/admin/users');
      final data = response.data;
      if (data == null) return [];
      return data.map((e) => AdminUser.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<PagedResult<AdminUser>> getUsersPage({
    int page = 0,
    int size = 20,
    String? search,
    String? role,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/admin/users/page',
        queryParameters: {
          'page': page,
          'size': size,
          if (search != null && search.isNotEmpty) 'search': search,
          if (role != null && role.isNotEmpty) 'role': role,
        },
      );
      final data = response.data;
      if (data == null) {
        return PagedResult(
          content: [],
          page: page,
          size: size,
          totalElements: 0,
          totalPages: 0,
          last: true,
        );
      }
      return PagedResult.fromJson(data, AdminUser.fromJson);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<UserSummary> getUserSummary() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/admin/users/summary');
      final data = response.data;
      if (data == null) {
        return UserSummary(
          totalUsers: 0,
          activeUsers: 0,
          inactiveUsers: 0,
          usersByRole: {},
          verifiedEmails: 0,
          unverifiedEmails: 0,
        );
      }
      return UserSummary.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<AdminUser> createUser(CreateUserRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/admin/users',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.errCreateUser, backendMessage: 'Failed to create user');
      }
      return AdminUser.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<AdminUser> updateUser(int userId, UpdateUserRequest request) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/admin/users/$userId',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw AppException.withCode(AppErrorCode.errUpdateFailed, backendMessage: 'Failed to update user');
      }
      return AdminUser.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> updateUserRoles({
    required int userId,
    required List<String> roles,
  }) async {
    try {
      await _dio.patch<void>(
        '/admin/users/$userId/roles',
        data: {'roles': roles},
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> updateUserActive(int userId, bool active) async {
    try {
      await _dio.patch<void>(
        '/admin/users/$userId/active',
        data: {'active': active},
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> updateUserPassword(int userId, String newPassword) async {
    try {
      await _dio.patch<void>(
        '/admin/users/$userId/password',
        data: {'password': newPassword},
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<String> uploadDocumentPhoto(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/admin/users/document-photo',
        data: formData,
      );
      final data = response.data;
      if (data == null || data['url'] == null) {
        throw AppException.withCode(AppErrorCode.errUploadFailed, backendMessage: 'Failed to upload document photo');
      }
      return data['url'].toString();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> deleteUser(int userId) async {
    try {
      await _dio.delete<void>('/admin/users/$userId');
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  BulkOperationResult bulkDelete(Set<int> ids) {
    throw UnimplementedError('Use bulkDeleteAsync for async operation');
  }

  Future<BulkOperationResult> bulkDeleteAsync(Set<int> ids) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/admin/users/bulk/delete',
        data: {'ids': ids.toList()},
      );
      return BulkOperationResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  BulkOperationResult bulkUpdateActive(Set<int> ids, bool active) {
    throw UnimplementedError('Use bulkUpdateActiveAsync for async operation');
  }

  Future<BulkOperationResult> bulkUpdateActiveAsync(Set<int> ids, bool active) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/admin/users/bulk/active',
        data: {'ids': ids.toList(), 'active': active},
      );
      return BulkOperationResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  BulkOperationResult bulkUpdateRoles(Set<int> ids, List<String> roles) {
    throw UnimplementedError('Use bulkUpdateRolesAsync for async operation');
  }

  Future<BulkOperationResult> bulkUpdateRolesAsync(Set<int> ids, List<String> roles) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/admin/users/bulk/roles',
        data: {'ids': ids.toList(), 'roles': roles},
      );
      return BulkOperationResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  String getExportUrl() {
    return '/admin/users/export';
  }
}

enum UserRole { client, courier, operator, citySupervisor, admin, support }

extension UserRoleX on UserRole {
  String get backendCode {
    switch (this) {
      case UserRole.client:
        return 'CLIENT';
      case UserRole.courier:
        return 'COURIER';
      case UserRole.operator:
        return 'OPERATOR';
      case UserRole.citySupervisor:
        return 'CITY_SUPERVISOR';
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.support:
        return 'SUPPORT';
    }
  }

  String get localizationKey {
    switch (this) {
      case UserRole.client:
        return 'user_role_client';
      case UserRole.courier:
        return 'user_role_courier';
      case UserRole.operator:
        return 'user_role_operator';
      case UserRole.citySupervisor:
        return 'user_role_city_supervisor';
      case UserRole.admin:
        return 'user_role_admin';
      case UserRole.support:
        return 'user_role_support';
    }
  }

  String get displayLabel {
    switch (this) {
      case UserRole.client:
        return 'Client';
      case UserRole.courier:
        return 'Courier';
      case UserRole.operator:
        return 'Operator';
      case UserRole.citySupervisor:
        return 'City supervisor';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.support:
        return 'Support';
    }
  }

  bool get canAccessBackoffice {
    return this == UserRole.operator ||
        this == UserRole.citySupervisor ||
        this == UserRole.admin;
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isCourier => this == UserRole.courier;
  bool get isSupport => this == UserRole.support;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.nationality = '',
    this.preferredLanguage = 'es',
    this.authProvider = 'LOCAL',
    this.managedByAdmin = false,
    this.canSelfEditProfile = true,
    this.vehiclePlate,
    this.profilePhotoPath,
    this.emailVerified = true,
    this.profileCompleted = true,
    this.emailChangeRemaining = 3,
    this.phoneChangeRemaining = 3,
    this.documentChangeRemaining = 3,
    this.birthDate,
    this.gender,
    this.address = '',
    this.city = '',
    this.country = '',
    this.documentType,
    this.documentNumber,
    this.secondaryDocumentType,
    this.secondaryDocumentNumber,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.assignedWarehouseIds = const [],
    this.assignedWarehouseNames = const [],
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String firstName;
  final String lastName;
  final String phone;
  final String nationality;
  final String preferredLanguage;
  final String authProvider;
  final bool managedByAdmin;
  final bool canSelfEditProfile;
  final String? vehiclePlate;
  final String? profilePhotoPath;
  final bool emailVerified;
  final bool profileCompleted;
  final int emailChangeRemaining;
  final int phoneChangeRemaining;
  final int documentChangeRemaining;
  final DateTime? birthDate;
  final String? gender;
  final String address;
  final String city;
  final String country;
  final String? documentType;
  final String? documentNumber;
  final String? secondaryDocumentType;
  final String? secondaryDocumentNumber;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final List<String> assignedWarehouseIds;
  final List<String> assignedWarehouseNames;

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? firstName,
    String? lastName,
    String? phone,
    String? nationality,
    String? preferredLanguage,
    String? authProvider,
    bool? managedByAdmin,
    bool? canSelfEditProfile,
    String? vehiclePlate,
    String? profilePhotoPath,
    bool? emailVerified,
    bool? profileCompleted,
    int? emailChangeRemaining,
    int? phoneChangeRemaining,
    int? documentChangeRemaining,
    DateTime? birthDate,
    String? gender,
    String? address,
    String? city,
    String? country,
    String? documentType,
    String? documentNumber,
    String? secondaryDocumentType,
    String? secondaryDocumentNumber,
    String? emergencyContactName,
    String? emergencyContactPhone,
    List<String>? assignedWarehouseIds,
    List<String>? assignedWarehouseNames,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      nationality: nationality ?? this.nationality,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      authProvider: authProvider ?? this.authProvider,
      managedByAdmin: managedByAdmin ?? this.managedByAdmin,
      canSelfEditProfile: canSelfEditProfile ?? this.canSelfEditProfile,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      emailVerified: emailVerified ?? this.emailVerified,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      emailChangeRemaining: emailChangeRemaining ?? this.emailChangeRemaining,
      phoneChangeRemaining: phoneChangeRemaining ?? this.phoneChangeRemaining,
      documentChangeRemaining:
          documentChangeRemaining ?? this.documentChangeRemaining,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      secondaryDocumentType:
          secondaryDocumentType ?? this.secondaryDocumentType,
      secondaryDocumentNumber:
          secondaryDocumentNumber ?? this.secondaryDocumentNumber,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      assignedWarehouseIds: assignedWarehouseIds ?? this.assignedWarehouseIds,
      assignedWarehouseNames:
          assignedWarehouseNames ?? this.assignedWarehouseNames,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'role': role.backendCode,
      'phone': phone,
      'nationality': nationality,
      'preferredLanguage': preferredLanguage,
      'authProvider': authProvider,
      'managedByAdmin': managedByAdmin,
      'canSelfEditProfile': canSelfEditProfile,
      'vehiclePlate': vehiclePlate,
      'profilePhotoPath': profilePhotoPath,
      'emailVerified': emailVerified,
      'profileCompleted': profileCompleted,
      'emailChangeRemaining': emailChangeRemaining,
      'phoneChangeRemaining': phoneChangeRemaining,
      'documentChangeRemaining': documentChangeRemaining,
      'birthDate': birthDate?.toIso8601String(),
      'gender': gender,
      'address': address,
      'city': city,
      'country': country,
      'documentType': documentType,
      'documentNumber': documentNumber,
      'secondaryDocumentType': secondaryDocumentType,
      'secondaryDocumentNumber': secondaryDocumentNumber,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'warehouseIds': assignedWarehouseIds,
      'warehouseNames': assignedWarehouseNames,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final roleValue = _resolveRoleValue(json);
    final firstName = _readString(json, ['firstName']);
    final lastName = _readString(json, ['lastName']);
    final resolvedName =
        _readString(json, ['fullName', 'name']) ??
        [
          firstName,
          lastName,
        ].where((value) => value != null && value.isNotEmpty).join(' ').trim();

    return AppUser(
      id: json['id']?.toString() ?? '',
      name: resolvedName.isEmpty ? 'Usuario InkaVoy' : resolvedName,
      email: _readString(json, ['email']) ?? '',
      role: _parseUserRole(roleValue),
      firstName: firstName ?? '',
      lastName: lastName ?? '',
      phone: _readString(json, ['phone']) ?? '',
      nationality: _readString(json, ['nationality']) ?? '',
      preferredLanguage: _readString(json, ['preferredLanguage']) ?? 'es',
      authProvider: _readString(json, ['authProvider']) ?? 'LOCAL',
      managedByAdmin: _readBool(json, ['managedByAdmin'], fallback: false),
      canSelfEditProfile: _readBool(json, [
        'canSelfEditProfile',
      ], fallback: _parseUserRole(roleValue) == UserRole.client),
      vehiclePlate: _readString(json, ['vehiclePlate']),
      profilePhotoPath: _readString(json, ['profilePhotoPath', 'photoPath']),
      emailVerified: _readBool(json, ['emailVerified'], fallback: true),
      profileCompleted: _readBool(json, ['profileCompleted'], fallback: true),
      emailChangeRemaining: _readInt(json, [
        'emailChangeRemaining',
      ], fallback: 3),
      phoneChangeRemaining: _readInt(json, [
        'phoneChangeRemaining',
      ], fallback: 3),
      documentChangeRemaining: _readInt(json, [
        'documentChangeRemaining',
      ], fallback: 3),
      birthDate: _readDate(json, ['birthDate']),
      gender: _readString(json, ['gender']),
      address: _readString(json, ['address', 'addressLine']) ?? '',
      city: _readString(json, ['city', 'cityName']) ?? '',
      country: _readString(json, ['country', 'countryName']) ?? '',
      documentType: _readString(json, ['documentType']),
      documentNumber: _readString(json, ['documentNumber']),
      secondaryDocumentType: _readString(json, ['secondaryDocumentType']),
      secondaryDocumentNumber: _readString(json, ['secondaryDocumentNumber']),
      emergencyContactName: _readString(json, ['emergencyContactName']),
      emergencyContactPhone: _readString(json, ['emergencyContactPhone']),
      assignedWarehouseIds: _readStringList(json, [
        'warehouseIds',
        'assignedWarehouseIds',
      ]),
      assignedWarehouseNames: _readStringList(json, [
        'warehouseNames',
        'assignedWarehouseNames',
      ]),
    );
  }
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key]?.toString();
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

bool _readBool(
  Map<String, dynamic> json,
  List<String> keys, {
  required bool fallback,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
  }
  return fallback;
}

int _readInt(
  Map<String, dynamic> json,
  List<String> keys, {
  required int fallback,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

DateTime? _readDate(Map<String, dynamic> json, List<String> keys) {
  final value = _readString(json, keys);
  if (value == null) return null;
  return DateTime.tryParse(value);
}

List<String> _readStringList(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
  }
  return const [];
}

String _resolveRoleValue(Map<String, dynamic> json) {
  final roles = json['roles'];
  if (roles is List && roles.isNotEmpty) {
    final normalized = roles
        .map((item) => item.toString().trim().toUpperCase())
        .toSet();
    if (normalized.contains('ROLE_ADMIN') || normalized.contains('ADMIN')) {
      return 'ADMIN';
    }
    if (normalized.contains('ROLE_SUPPORT') || normalized.contains('SUPPORT')) {
      return 'SUPPORT';
    }
    if (normalized.contains('ROLE_COURIER') || normalized.contains('COURIER')) {
      return 'COURIER';
    }
    if (normalized.contains('ROLE_CITY_SUPERVISOR') ||
        normalized.contains('CITY_SUPERVISOR')) {
      return 'CITY_SUPERVISOR';
    }
    if (normalized.contains('ROLE_OPERATOR') ||
        normalized.contains('OPERATOR')) {
      return 'OPERATOR';
    }
    if (normalized.contains('ROLE_CLIENT') || normalized.contains('CLIENT')) {
      return 'CLIENT';
    }
    return roles.first.toString();
  }
  final role = json['role']?.toString();
  if (role != null && role.isNotEmpty) {
    return role;
  }
  return '';
}

UserRole _parseUserRole(String rawRole) {
  final normalized = rawRole.trim().toUpperCase().replaceFirst('ROLE_', '');
  switch (normalized) {
    case 'CLIENT':
    case 'CUSTOMER':
      return UserRole.client;
    case 'COURIER':
      return UserRole.courier;
    case 'OPERATOR':
      return UserRole.operator;
    case 'CITY_SUPERVISOR':
      return UserRole.citySupervisor;
    case 'ADMIN':
      return UserRole.admin;
    case 'SUPPORT':
      return UserRole.support;
    default:
      return UserRole.client;
  }
}

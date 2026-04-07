/// Centralised mock definitions and test-data factories for widget and
/// unit tests.
///
/// Import this file instead of creating ad-hoc mocks in every test file:
/// ```dart
/// import '../helpers/test_mocks.dart';
/// ```
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travelbox_peru_app/core/network/api_client.dart';
import 'package:travelbox_peru_app/shared/models/app_user.dart';
import 'package:travelbox_peru_app/shared/state/session_controller.dart';

// =============================================================================
// Mock classes
// =============================================================================

/// Mock for [Dio] -- use with the [dioProvider] override.
class MockDio extends Mock implements Dio {
  @override
  BaseOptions get options => BaseOptions(baseUrl: 'https://test.api.local');

  @override
  Interceptors get interceptors => Interceptors();
}

/// Mock for [SharedPreferences] -- needed by [sessionControllerProvider].
class MockSharedPreferences extends Mock implements SharedPreferences {}

// =============================================================================
// Test-data factories for AppUser
// =============================================================================

/// Returns a minimal [AppUser] representing a CLIENT with sensible defaults.
AppUser aTestClientUser({
  String id = '1',
  String name = 'Test Client',
  String email = 'client@test.travelbox.pe',
  UserRole role = UserRole.client,
  bool emailVerified = true,
  bool profileCompleted = true,
}) {
  return AppUser(
    id: id,
    name: name,
    email: email,
    role: role,
    firstName: name.split(' ').first,
    lastName: name.split(' ').length > 1 ? name.split(' ').last : '',
    phone: '+51999001234',
    nationality: 'PE',
    preferredLanguage: 'es',
    emailVerified: emailVerified,
    profileCompleted: profileCompleted,
  );
}

/// Returns a minimal [AppUser] representing an ADMIN.
AppUser aTestAdminUser({
  String id = '100',
  String name = 'Test Admin',
  String email = 'admin@test.travelbox.pe',
}) {
  return AppUser(
    id: id,
    name: name,
    email: email,
    role: UserRole.admin,
    firstName: 'Test',
    lastName: 'Admin',
    phone: '+51999005678',
    nationality: 'PE',
    preferredLanguage: 'es',
    emailVerified: true,
    profileCompleted: true,
  );
}

/// Returns a minimal [AppUser] representing an OPERATOR.
AppUser aTestOperatorUser({
  String id = '200',
  String name = 'Test Operator',
  String email = 'operator@test.travelbox.pe',
  List<String> warehouseIds = const ['1'],
  List<String> warehouseNames = const ['Cusco Centro'],
}) {
  return AppUser(
    id: id,
    name: name,
    email: email,
    role: UserRole.operator,
    firstName: 'Test',
    lastName: 'Operator',
    phone: '+51999009012',
    nationality: 'PE',
    preferredLanguage: 'es',
    emailVerified: true,
    profileCompleted: true,
    assignedWarehouseIds: warehouseIds,
    assignedWarehouseNames: warehouseNames,
  );
}

/// Returns a minimal [AppUser] representing a COURIER.
AppUser aTestCourierUser({
  String id = '300',
  String name = 'Test Courier',
  String email = 'courier@test.travelbox.pe',
  String? vehiclePlate,
}) {
  return AppUser(
    id: id,
    name: name,
    email: email,
    role: UserRole.courier,
    firstName: 'Test',
    lastName: 'Courier',
    phone: '+51999003456',
    nationality: 'PE',
    preferredLanguage: 'es',
    emailVerified: true,
    profileCompleted: true,
    vehiclePlate: vehiclePlate,
  );
}

/// Returns an [AppUser] that requires email verification and onboarding.
AppUser aTestUnverifiedUser({
  String id = '999',
  String name = 'New User',
  String email = 'new@test.travelbox.pe',
}) {
  return AppUser(
    id: id,
    name: name,
    email: email,
    role: UserRole.client,
    emailVerified: false,
    profileCompleted: false,
    requiresRealEmailCompletion: false,
  );
}

// =============================================================================
// Riverpod overrides for testing
// =============================================================================

/// Returns a list of [Override]s that inject [MockDio] and
/// [MockSharedPreferences] into the provider tree.
///
/// Usage:
/// ```dart
/// final container = ProviderContainer(overrides: testProviderOverrides());
/// final dio = container.read(dioProvider);
/// ```
List<Override> testProviderOverrides({
  MockDio? dio,
  MockSharedPreferences? prefs,
}) {
  final mockDio = dio ?? MockDio();
  final mockPrefs = prefs ?? MockSharedPreferences();
  return [
    dioProvider.overrideWithValue(mockDio),
    sharedPreferencesProvider.overrideWithValue(mockPrefs),
  ];
}

// =============================================================================
// Dio response helpers
// =============================================================================

/// Builds a successful [Response] with the given [data] and [statusCode].
///
/// Useful for stubbing [MockDio] calls:
/// ```dart
/// when(() => mockDio.get(any())).thenAnswer(
///   (_) async => fakeResponse({'id': 1}, statusCode: 200),
/// );
/// ```
Response<T> fakeResponse<T>(
  T data, {
  int statusCode = 200,
  String requestPath = '/test',
}) {
  return Response<T>(
    data: data,
    statusCode: statusCode,
    requestOptions: RequestOptions(path: requestPath),
  );
}

/// Builds a [DioException] suitable for testing error paths.
DioException fakeDioError({
  int? statusCode,
  String message = 'Test error',
  String requestPath = '/test',
  DioExceptionType type = DioExceptionType.badResponse,
  Map<String, dynamic>? responseData,
}) {
  final requestOptions = RequestOptions(path: requestPath);
  return DioException(
    requestOptions: requestOptions,
    type: type,
    message: message,
    response: statusCode != null
        ? Response(
            statusCode: statusCode,
            data: responseData,
            requestOptions: requestOptions,
          )
        : null,
  );
}

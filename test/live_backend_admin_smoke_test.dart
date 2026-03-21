import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
const _smokeAdminEmail = String.fromEnvironment(
  'SMOKE_ADMIN_EMAIL',
  defaultValue: '',
);
const _smokeAdminPassword = String.fromEnvironment(
  'SMOKE_ADMIN_PASSWORD',
  defaultValue: '',
);

void main() {
  test('live backend admin smoke dashboard + users + warehouses contracts', () async {
    if (_apiBaseUrl.isEmpty) {
      // Allows local `flutter test` without external backend configuration.
      return;
    }
    expect(
      _smokeAdminEmail.isNotEmpty,
      true,
      reason: 'Missing SMOKE_ADMIN_EMAIL dart-define (must come from real secret).',
    );
    expect(
      _smokeAdminPassword.isNotEmpty,
      true,
      reason: 'Missing SMOKE_ADMIN_PASSWORD dart-define (must come from real secret).',
    );

    final login = await _requestJson(
      method: 'POST',
      url: '$_apiBaseUrl/auth/login',
      body: <String, dynamic>{
        'email': _smokeAdminEmail,
        'password': _smokeAdminPassword,
      },
    );
    expect(login.statusCode, 200, reason: 'Admin login should return 200');
    final accessToken = (login.jsonBody['accessToken'] ?? '').toString();
    expect(accessToken.isNotEmpty, true, reason: 'Admin login should return accessToken');
    expect(login.jsonBody['user'] is Map<String, dynamic>, true);

    final dashboard = await _requestJson(
      method: 'GET',
      url: '$_apiBaseUrl/admin/dashboard?period=month',
      bearerToken: accessToken,
    );
    expect(dashboard.statusCode, 200, reason: 'Admin dashboard should return 200');
    expect(dashboard.jsonBody is Map<String, dynamic>, true);
    final dashboardBody = dashboard.jsonBody as Map<String, dynamic>;
    expect(dashboardBody['summary'] is Map<String, dynamic>, true);
    expect(dashboardBody['topWarehouses'] is List<dynamic>, true);

    final warehouses = await _requestJson(
      method: 'GET',
      url: '$_apiBaseUrl/admin/warehouses',
      bearerToken: accessToken,
    );
    expect(warehouses.statusCode, 200, reason: 'Admin warehouses should return 200');
    expect(warehouses.jsonBody is List<dynamic>, true);
    final warehouseList = warehouses.jsonBody as List<dynamic>;
    if (warehouseList.isNotEmpty) {
      expect(warehouseList.first is Map<String, dynamic>, true);
      final firstWarehouse = warehouseList.first as Map<String, dynamic>;
      expect(firstWarehouse['id'] != null, true);
      expect(firstWarehouse['name']?.toString().trim().isNotEmpty ?? false, true);
      expect(firstWarehouse['active'] is bool, true);
    }

    final users = await _requestJson(
      method: 'GET',
      url: '$_apiBaseUrl/admin/users',
      bearerToken: accessToken,
    );
    expect(users.statusCode, 200, reason: 'Admin users should return 200');
    expect(users.jsonBody is List<dynamic>, true);
    final userList = users.jsonBody as List<dynamic>;
    if (userList.isNotEmpty) {
      expect(userList.first is Map<String, dynamic>, true);
      final firstUser = userList.first as Map<String, dynamic>;
      expect(firstUser['id'] != null, true);
      expect(firstUser['email']?.toString().contains('@') ?? false, true);
      expect(firstUser['roles'] is List<dynamic>, true);
    }
  });
}

Future<_JsonResponse> _requestJson({
  required String method,
  required String url,
  String? bearerToken,
  Map<String, dynamic>? body,
}) async {
  final uri = Uri.parse(url);
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (bearerToken != null && bearerToken.trim().isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${bearerToken.trim()}');
    }
    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    dynamic parsed = <String, dynamic>{};
    if (raw.trim().isNotEmpty) {
      parsed = jsonDecode(raw);
    }
    if (parsed is Map<String, dynamic> || parsed is List<dynamic>) {
      return _JsonResponse(statusCode: response.statusCode, jsonBody: parsed);
    }
    return _JsonResponse(statusCode: response.statusCode, jsonBody: <String, dynamic>{});
  } finally {
    client.close(force: true);
  }
}

class _JsonResponse {
  const _JsonResponse({
    required this.statusCode,
    required this.jsonBody,
  });

  final int statusCode;
  final dynamic jsonBody;
}

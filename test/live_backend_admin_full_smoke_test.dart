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
  group('Admin Backend Smoke Tests - All New Endpoints', () {
    late String accessToken;

    test('login as admin', () async {
      if (_apiBaseUrl.isEmpty) return;
      expect(_smokeAdminEmail.isNotEmpty, true);
      expect(_smokeAdminPassword.isNotEmpty, true);

      final login = await _requestJson(
        method: 'POST',
        url: '$_apiBaseUrl/auth/login',
        body: <String, dynamic>{
          'email': _smokeAdminEmail,
          'password': _smokeAdminPassword,
        },
      );
      expect(login.statusCode, 200, reason: 'Admin login should return 200');
      accessToken = (login.jsonBody['accessToken'] ?? '').toString();
      expect(accessToken.isNotEmpty, true);
    });

    test('dashboard endpoint', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final dashboard = await _requestJson(
        method: 'GET',
        url: '$_apiBaseUrl/admin/dashboard?period=month',
        bearerToken: accessToken,
      );
      expect(dashboard.statusCode, 200);
      final body = dashboard.jsonBody as Map<String, dynamic>;
      expect(body['summary'] is Map<String, dynamic>, true);
      expect(body['topWarehouses'] is List<dynamic>, true);
    });

    test('dashboard summary-only endpoint', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final summary = await _requestJson(
        method: 'GET',
        url: '$_apiBaseUrl/admin/dashboard/summary-only?period=month',
        bearerToken: accessToken,
      );
      expect(summary.statusCode, 200);
      final body = summary.jsonBody as Map<String, dynamic>;
      expect(body['reservations'] != null, true);
    });

    test('users page with pagination', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final usersPage = await _requestJson(
        method: 'GET',
        url: '$_apiBaseUrl/admin/users/page?page=0&size=10',
        bearerToken: accessToken,
      );
      expect(usersPage.statusCode, 200);
      final body = usersPage.jsonBody as Map<String, dynamic>;
      expect(body['content'] is List<dynamic>, true);
      expect(body['totalElements'] != null, true);
      expect(body['totalPages'] != null, true);
    });

    test('users export endpoint returns CSV', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final export = await _requestRaw(
        method: 'GET',
        url: '$_apiBaseUrl/admin/users/export',
        bearerToken: accessToken,
      );
      expect(export.statusCode, 200);
      expect(export.contentType?.contains('text/csv'), true);
      expect(export.bodyText.startsWith('\u{FEFF}'), true, reason: 'CSV should have BOM');
    });

    test('reservations export endpoint returns CSV', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final export = await _requestRaw(
        method: 'GET',
        url: '$_apiBaseUrl/admin/reservations/export',
        bearerToken: accessToken,
      );
      expect(export.statusCode, 200);
      expect(export.contentType?.contains('text/csv'), true);
    });

    test('revenue report endpoint', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final revenue = await _requestJson(
        method: 'GET',
        url: '$_apiBaseUrl/admin/reports/revenue?startDate=2024-01-01&endDate=2024-12-31',
        bearerToken: accessToken,
      );
      expect(revenue.statusCode, 200);
      final body = revenue.jsonBody as Map<String, dynamic>;
      expect(body['totalRevenue'] != null, true);
      expect(body['totalReservations'] != null, true);
      expect(body['byWarehouse'] is List<dynamic>, true);
      expect(body['byCity'] is List<dynamic>, true);
      expect(body['byDay'] is List<dynamic>, true);
    });

    test('ratings endpoint', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final ratings = await _requestJson(
        method: 'GET',
        url: '$_apiBaseUrl/admin/reports/ratings',
        bearerToken: accessToken,
      );
      expect(ratings.statusCode, 200);
      expect(ratings.jsonBody is List<dynamic>, true);
    });

    test('system health endpoint', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final health = await _requestJson(
        method: 'GET',
        url: '$_apiBaseUrl/admin/system/health',
        bearerToken: accessToken,
      );
      expect(health.statusCode, 200);
      final body = health.jsonBody as Map<String, dynamic>;
      expect(body['application'] != null, true);
      expect(body['status'] != null, true);
      expect(body['memory'] is Map<String, dynamic>, true);
      expect(body['cpu'] is Map<String, dynamic>, true);
      final memory = body['memory'] as Map<String, dynamic>;
      expect(memory['usedMB'] != null, true);
      expect(memory['maxMB'] != null, true);
    });

    test('audit log endpoint', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final audit = await _requestJson(
        method: 'GET',
        url: '$_apiBaseUrl/admin/system/audit-log?limit=10',
        bearerToken: accessToken,
      );
      expect(audit.statusCode, 200);
      expect(audit.jsonBody is List<dynamic>, true);
    });

    test('bulk active endpoint', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final bulk = await _requestJson(
        method: 'PATCH',
        url: '$_apiBaseUrl/admin/users/bulk/active',
        bearerToken: accessToken,
        body: <String, dynamic>{
          'ids': [1, 2],
          'active': true,
        },
      );
      expect(bulk.statusCode, 200);
      final body = bulk.jsonBody as Map<String, dynamic>;
      expect(body['processed'] != null, true);
      expect(body['succeeded'] != null, true);
    });

    test('bulk delete endpoint', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final bulk = await _requestJson(
        method: 'PATCH',
        url: '$_apiBaseUrl/admin/users/bulk/delete',
        bearerToken: accessToken,
        body: <String, dynamic>{
          'ids': [99999],
        },
      );
      expect(bulk.statusCode, 200);
      final body = bulk.jsonBody as Map<String, dynamic>;
      expect(body['processed'] != null, true);
    });

    test('bulk roles endpoint', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final bulk = await _requestJson(
        method: 'PATCH',
        url: '$_apiBaseUrl/admin/users/bulk/roles',
        bearerToken: accessToken,
        body: <String, dynamic>{
          'ids': [1],
          'roles': ['CLIENT'],
        },
      );
      expect(bulk.statusCode, 200);
      final body = bulk.jsonBody as Map<String, dynamic>;
      expect(body['processed'] != null, true);
    });

    test('bulk reservation status endpoint', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final bulk = await _requestJson(
        method: 'PATCH',
        url: '$_apiBaseUrl/admin/reservations/bulk/status',
        bearerToken: accessToken,
        body: <String, dynamic>{
          'ids': [1],
          'status': 'CONFIRMED',
        },
      );
      expect(bulk.statusCode, 200);
      final body = bulk.jsonBody as Map<String, dynamic>;
      expect(body['processed'] != null, true);
    });

    test('unauthorized access is rejected', () async {
      if (_apiBaseUrl.isEmpty) return;
      
      final health = await _requestJson(
        method: 'GET',
        url: '$_apiBaseUrl/admin/system/health',
      );
      expect(health.statusCode, 401);
    });
  });
}

Future<_JsonResponse> _requestJson({
  required String method,
  required String url,
  String? bearerToken,
  Map<String, dynamic>? body,
}) async {
  final response = await _requestRaw(
    method: method,
    url: url,
    bearerToken: bearerToken,
    body: body,
  );
  return _JsonResponse(
    statusCode: response.statusCode,
    jsonBody: response.jsonBody,
  );
}

Future<_RawResponse> _requestRaw({
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
      try {
        parsed = jsonDecode(raw);
      } catch (_) {
        parsed = raw;
      }
    }
    if (parsed is Map<String, dynamic> || parsed is List<dynamic>) {
      return _RawResponse(
        statusCode: response.statusCode,
        contentType: response.headers.contentType?.value,
        bodyText: raw,
        jsonBody: parsed,
      );
    }
    return _RawResponse(
      statusCode: response.statusCode,
      contentType: response.headers.contentType?.value,
      bodyText: raw,
      jsonBody: <String, dynamic>{},
    );
  } finally {
    client.close(force: true);
  }
}

class _RawResponse {
  const _RawResponse({
    required this.statusCode,
    required this.contentType,
    required this.bodyText,
    required this.jsonBody,
  });

  final int statusCode;
  final String? contentType;
  final String bodyText;
  final dynamic jsonBody;
}

class _JsonResponse {
  const _JsonResponse({
    required this.statusCode,
    required this.jsonBody,
  });

  final int statusCode;
  final dynamic jsonBody;
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
const _smokeClientEmail =
    String.fromEnvironment('SMOKE_CLIENT_EMAIL', defaultValue: '');
const _smokeClientPassword =
    String.fromEnvironment('SMOKE_CLIENT_PASSWORD', defaultValue: '');

void main() {
  test('live backend smoke auth + warehouses + reservations page', () async {
    if (_apiBaseUrl.isEmpty) {
      // Allows local `flutter test` without external backend configuration.
      return;
    }
    expect(
      _smokeClientEmail.isNotEmpty,
      true,
      reason: 'Missing SMOKE_CLIENT_EMAIL dart-define (must come from real secret).',
    );
    expect(
      _smokeClientPassword.isNotEmpty,
      true,
      reason: 'Missing SMOKE_CLIENT_PASSWORD dart-define (must come from real secret).',
    );

    final login = await _requestJson(
      method: 'POST',
      url: '$_apiBaseUrl/auth/login',
      body: <String, dynamic>{
        'email': _smokeClientEmail,
        'password': _smokeClientPassword,
      },
    );
    expect(login.statusCode, 200, reason: 'Login should return 200');
    final accessToken = (login.jsonBody['accessToken'] ?? '').toString();
    expect(accessToken.isNotEmpty, true, reason: 'Login should return accessToken');

    final warehouses = await _requestJson(
      method: 'GET',
      url: '$_apiBaseUrl/warehouses/search',
      bearerToken: accessToken,
    );
    expect(warehouses.statusCode, 200, reason: 'Warehouses endpoint should return 200');
    expect(warehouses.jsonBody is List, true, reason: 'Warehouses payload should be a list');

    final reservations = await _requestJson(
      method: 'GET',
      url: '$_apiBaseUrl/reservations/page?page=0&size=1',
      bearerToken: accessToken,
    );
    expect(reservations.statusCode, 200, reason: 'Reservations page should return 200');
    expect(
      reservations.jsonBody is Map<String, dynamic>,
      true,
      reason: 'Reservations page payload should be an object',
    );
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

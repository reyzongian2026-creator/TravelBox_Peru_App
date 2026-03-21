import 'dart:convert';

import '../../../shared/utils/peru_time.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.payload,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  String get whenLabel =>
      PeruTime.formatDateTime(createdAt, includeYear: false);

  String? get reservationId {
    final value = payload['reservationId'];
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? get route {
    final explicit = payload['route']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final reservation = reservationId;
    if (reservation != null) {
      return '/reservation/$reservation';
    }
    if (payload['approvalId'] != null) {
      return '/ops/qr-handoff';
    }
    final normalizedType = type.trim().toUpperCase();
    if (normalizedType.contains('DELIVERY')) {
      return '/courier/services';
    }
    if (normalizedType.contains('INCIDENT')) {
      return '/operator/incidents';
    }
    return null;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'GENERAL',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? '-',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      payload: _parsePayload(json),
    );
  }

  static Map<String, dynamic> _parsePayload(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    if (rawPayload is Map<String, dynamic>) {
      return rawPayload;
    }
    final rawPayloadJson = json['payloadJson']?.toString();
    if (rawPayloadJson == null || rawPayloadJson.trim().isEmpty) {
      return const <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(rawPayloadJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
}

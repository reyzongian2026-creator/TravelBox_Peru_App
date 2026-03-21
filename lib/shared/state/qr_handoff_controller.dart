import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/reservation.dart';

enum QrHandoffStage {
  draft,
  qrValidated,
  bagTagged,
  storedAtWarehouse,
  readyForPickup,
  pickupPinValidated,
  deliveryIdentityValidated,
  deliveryLuggageValidated,
  deliveryApprovalPending,
  deliveryApprovalGranted,
  deliveryCompleted,
}

extension QrHandoffStageX on QrHandoffStage {
  String get label {
    switch (this) {
      case QrHandoffStage.draft:
        return 'Borrador operativo';
      case QrHandoffStage.qrValidated:
        return 'QR validado';
      case QrHandoffStage.bagTagged:
        return 'Maleta etiquetada';
      case QrHandoffStage.storedAtWarehouse:
        return 'Guardada en almacen';
      case QrHandoffStage.readyForPickup:
        return 'Lista para recojo';
      case QrHandoffStage.pickupPinValidated:
        return 'Entrega presencial validada';
      case QrHandoffStage.deliveryIdentityValidated:
        return 'Identidad validada';
      case QrHandoffStage.deliveryLuggageValidated:
        return 'Maleta validada';
      case QrHandoffStage.deliveryApprovalPending:
        return 'Esperando aprobacion operador';
      case QrHandoffStage.deliveryApprovalGranted:
        return 'Aprobada para entrega';
      case QrHandoffStage.deliveryCompleted:
        return 'Entrega delivery completada';
    }
  }
}

class QrHandoffCase {
  const QrHandoffCase({
    required this.reservationId,
    required this.reservationCode,
    required this.customerLanguage,
    required this.customerQrPayload,
    required this.stage,
    required this.bagUnits,
    required this.createdAt,
    required this.updatedAt,
    this.bagTagId,
    this.bagTagQrPayload,
    this.pickupPin,
    this.identityValidated = false,
    this.luggageMatched = false,
    this.operatorApprovalRequested = false,
    this.operatorApprovalGranted = false,
    this.latestMessageForCustomer,
    this.latestMessageTranslated,
  });

  final String reservationId;
  final String reservationCode;
  final String customerLanguage;
  final String customerQrPayload;
  final String? bagTagId;
  final String? bagTagQrPayload;
  final int bagUnits;
  final String? pickupPin;
  final bool identityValidated;
  final bool luggageMatched;
  final bool operatorApprovalRequested;
  final bool operatorApprovalGranted;
  final String? latestMessageForCustomer;
  final String? latestMessageTranslated;
  final QrHandoffStage stage;
  final DateTime createdAt;
  final DateTime updatedAt;

  QrHandoffCase copyWith({
    String? customerLanguage,
    String? bagTagId,
    String? bagTagQrPayload,
    int? bagUnits,
    String? pickupPin,
    bool? identityValidated,
    bool? luggageMatched,
    bool? operatorApprovalRequested,
    bool? operatorApprovalGranted,
    String? latestMessageForCustomer,
    String? latestMessageTranslated,
    QrHandoffStage? stage,
    DateTime? updatedAt,
  }) {
    return QrHandoffCase(
      reservationId: reservationId,
      reservationCode: reservationCode,
      customerLanguage: customerLanguage ?? this.customerLanguage,
      customerQrPayload: customerQrPayload,
      bagTagId: bagTagId ?? this.bagTagId,
      bagTagQrPayload: bagTagQrPayload ?? this.bagTagQrPayload,
      bagUnits: bagUnits ?? this.bagUnits,
      pickupPin: pickupPin ?? this.pickupPin,
      identityValidated: identityValidated ?? this.identityValidated,
      luggageMatched: luggageMatched ?? this.luggageMatched,
      operatorApprovalRequested:
          operatorApprovalRequested ?? this.operatorApprovalRequested,
      operatorApprovalGranted:
          operatorApprovalGranted ?? this.operatorApprovalGranted,
      latestMessageForCustomer:
          latestMessageForCustomer ?? this.latestMessageForCustomer,
      latestMessageTranslated:
          latestMessageTranslated ?? this.latestMessageTranslated,
      stage: stage ?? this.stage,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum OpsApprovalStatus { pending, approved, rejected }

extension OpsApprovalStatusX on OpsApprovalStatus {
  String get label {
    switch (this) {
      case OpsApprovalStatus.pending:
        return 'Pendiente';
      case OpsApprovalStatus.approved:
        return 'Aprobada';
      case OpsApprovalStatus.rejected:
        return 'Rechazada';
    }
  }
}

class OpsApprovalNotification {
  const OpsApprovalNotification({
    required this.id,
    required this.reservationId,
    required this.reservationCode,
    required this.createdAt,
    required this.messageForOperator,
    required this.messageForCustomer,
    required this.messageForCustomerTranslated,
    required this.status,
  });

  final String id;
  final String reservationId;
  final String reservationCode;
  final DateTime createdAt;
  final String messageForOperator;
  final String messageForCustomer;
  final String messageForCustomerTranslated;
  final OpsApprovalStatus status;

  OpsApprovalNotification copyWith({
    String? messageForOperator,
    String? messageForCustomer,
    String? messageForCustomerTranslated,
    OpsApprovalStatus? status,
  }) {
    return OpsApprovalNotification(
      id: id,
      reservationId: reservationId,
      reservationCode: reservationCode,
      createdAt: createdAt,
      messageForOperator: messageForOperator ?? this.messageForOperator,
      messageForCustomer: messageForCustomer ?? this.messageForCustomer,
      messageForCustomerTranslated:
          messageForCustomerTranslated ?? this.messageForCustomerTranslated,
      status: status ?? this.status,
    );
  }
}

class QrHandoffState {
  const QrHandoffState({
    required this.casesByReservationId,
    required this.approvalNotifications,
  });

  factory QrHandoffState.initial() {
    return const QrHandoffState(
      casesByReservationId: {},
      approvalNotifications: [],
    );
  }

  final Map<String, QrHandoffCase> casesByReservationId;
  final List<OpsApprovalNotification> approvalNotifications;

  QrHandoffState copyWith({
    Map<String, QrHandoffCase>? casesByReservationId,
    List<OpsApprovalNotification>? approvalNotifications,
  }) {
    return QrHandoffState(
      casesByReservationId: casesByReservationId ?? this.casesByReservationId,
      approvalNotifications:
          approvalNotifications ?? this.approvalNotifications,
    );
  }
}

final qrHandoffControllerProvider =
    StateNotifierProvider<QrHandoffController, QrHandoffState>((ref) {
      return QrHandoffController(dio: ref.watch(dioProvider));
    });

class QrHandoffController extends StateNotifier<QrHandoffState> {
  QrHandoffController({required Dio dio})
    : _dio = dio,
      super(QrHandoffState.initial());

  final Dio _dio;

  QrHandoffCase ensureCase(
    Reservation reservation, {
    String customerLanguage = 'es',
  }) {
    final existing = state.casesByReservationId[reservation.id];
    if (existing != null) {
      return existing;
    }
    final created = QrHandoffCase(
      reservationId: reservation.id,
      reservationCode: reservation.code,
      customerLanguage: customerLanguage,
      customerQrPayload: _buildCustomerQrPayload(reservation.code),
      stage: QrHandoffStage.draft,
      bagUnits: reservation.bagCount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return _upsertCase(created);
  }

  Reservation? findReservationByQr({
    required String scannedValue,
    required List<Reservation> reservations,
  }) {
    final scan = scannedValue.trim();
    if (scan.isEmpty) {
      return null;
    }
    final scanUpper = scan.toUpperCase();
    for (final reservation in reservations) {
      if (reservation.code.toUpperCase() == scanUpper) {
        return reservation;
      }
      final payload = _buildCustomerQrPayload(reservation.code).toUpperCase();
      if (scanUpper.contains(payload) || payload.contains(scanUpper)) {
        return reservation;
      }
    }
    for (final entry in state.casesByReservationId.values) {
      if (entry.bagTagId?.toUpperCase() == scanUpper) {
        for (final reservation in reservations) {
          if (reservation.id == entry.reservationId) {
            return reservation;
          }
        }
      }
    }
    return null;
  }

  Future<QrHandoffCase> validateReservationQr({
    required Reservation reservation,
    required String customerLanguage,
    String? scannedValue,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ops/qr-handoff/scan',
      data: {
        'scannedValue': (scannedValue?.trim().isNotEmpty == true)
            ? scannedValue!.trim()
            : reservation.code,
        'customerLanguage': customerLanguage,
      },
    );
    return _consumeBackendCase(response.data ?? const <String, dynamic>{});
  }

  Future<QrHandoffCase> tagLuggage({
    required Reservation reservation,
    required int bagUnits,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ops/qr-handoff/reservations/${reservation.id}/tag',
      data: {'bagUnits': bagUnits.clamp(1, 20)},
    );
    return _consumeBackendCase(response.data ?? const <String, dynamic>{});
  }

  Future<QrHandoffCase> markStoredAtWarehouse(String reservationId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ops/qr-handoff/reservations/$reservationId/store',
      data: const {},
    );
    return _consumeBackendCase(response.data ?? const <String, dynamic>{});
  }

  Future<QrHandoffCase> markStoredAtWarehouseWithPhotos({
    required String reservationId,
    required List<String> photoBase64List,
    int bagUnits = 1,
  }) async {
    final formData = FormData.fromMap({
      'bagUnits': bagUnits.clamp(1, 20),
      'photos': photoBase64List.map((base64) => FormData.fromMap({
        'data': base64,
        'contentType': 'image/jpeg',
      })).toList(),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/ops/qr-handoff/reservations/$reservationId/store-with-photos',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return _consumeBackendCase(response.data ?? const <String, dynamic>{});
  }

  Future<QrHandoffCase> markReadyForPickup(String reservationId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ops/qr-handoff/reservations/$reservationId/ready-for-pickup',
      data: const {},
    );
    return _consumeBackendCase(response.data ?? const <String, dynamic>{});
  }

  Future<QrHandoffCase> regeneratePickupPin(String reservationId) async {
    return markReadyForPickup(reservationId);
  }

  Future<bool> validatePickupPin({
    required String reservationId,
    required String typedPin,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ops/qr-handoff/reservations/$reservationId/pickup/confirm',
        data: {'pin': typedPin.trim()},
      );
      _consumeBackendCase(response.data ?? const <String, dynamic>{});
      return true;
    } on DioException catch (error) {
      if (_isKnownApiCode(error, {'PIN_INVALID'})) {
        return false;
      }
      rethrow;
    }
  }

  Future<QrHandoffCase> setDeliveryIdentityValidated({
    required String reservationId,
    required bool value,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/ops/qr-handoff/reservations/$reservationId/delivery/identity',
      data: {'value': value},
    );
    return _consumeBackendCase(response.data ?? const <String, dynamic>{});
  }

  Future<QrHandoffCase> setDeliveryLuggageMatched({
    required String reservationId,
    required bool value,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/ops/qr-handoff/reservations/$reservationId/delivery/luggage',
      data: {'value': value},
    );
    return _consumeBackendCase(response.data ?? const <String, dynamic>{});
  }

  Future<OpsApprovalNotification> requestOperatorApproval({
    required String reservationId,
    required String reservationCode,
    required String messageForOperator,
    required String messageForCustomerInSpanish,
    required String customerLanguage,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ops/qr-handoff/reservations/$reservationId/delivery/request-approval',
      data: {
        'messageForOperator': messageForOperator,
        'messageForCustomerSpanish': messageForCustomerInSpanish,
        'customerLanguage': customerLanguage,
      },
    );
    final caseItem = _consumeBackendCase(
      response.data ?? const <String, dynamic>{},
    );
    return state.approvalNotifications.firstWhere(
      (item) =>
          item.reservationId == reservationId &&
          item.status == OpsApprovalStatus.pending,
      orElse: () => OpsApprovalNotification(
        id: 'ops-${DateTime.now().microsecondsSinceEpoch}',
        reservationId: reservationId,
        reservationCode: reservationCode,
        createdAt: DateTime.now(),
        messageForOperator: messageForOperator,
        messageForCustomer: messageForCustomerInSpanish,
        messageForCustomerTranslated:
            caseItem.latestMessageTranslated ?? messageForCustomerInSpanish,
        status: OpsApprovalStatus.pending,
      ),
    );
  }

  Future<QrHandoffCase> approveOperatorHandoff({
    required String notificationId,
    String? specificPin,
  }) async {
    OpsApprovalNotification? notification;
    for (final item in state.approvalNotifications) {
      if (item.id == notificationId) {
        notification = item;
        break;
      }
    }
    if (notification == null) {
      throw StateError('Notificacion no encontrada: $notificationId');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/ops/qr-handoff/approvals/${notification.id}/approve',
      data: {
        if (specificPin?.trim().isNotEmpty == true) 'pin': specificPin!.trim(),
      },
    );
    return _consumeBackendCase(response.data ?? const <String, dynamic>{});
  }

  Future<bool> completeDeliveryWithPin({
    required String reservationId,
    required String typedPin,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ops/qr-handoff/reservations/$reservationId/delivery/complete',
        data: {'pin': typedPin.trim()},
      );
      _consumeBackendCase(response.data ?? const <String, dynamic>{});
      return true;
    } on DioException catch (error) {
      if (_isKnownApiCode(error, {
        'PIN_INVALID',
        'DELIVERY_VALIDATION_REQUIRED',
      })) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> refreshApprovals() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/ops/qr-handoff/approvals',
      );
      final items = response.data ?? const <dynamic>[];
      final parsed = items
          .whereType<Map<String, dynamic>>()
          .map(_mapApproval)
          .toList();
      state = state.copyWith(approvalNotifications: parsed);
    } catch (_) {}
  }

  Future<void> syncCase(String reservationId) async {
    final normalizedReservationId = reservationId.trim();
    if (normalizedReservationId.isEmpty) {
      return;
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/ops/qr-handoff/reservations/$normalizedReservationId',
      );
      _consumeBackendCase(response.data ?? const <String, dynamic>{});
    } catch (_) {}
  }

  void dismissNotification(String notificationId) {
    state = state.copyWith(
      approvalNotifications: state.approvalNotifications
          .where((item) => item.id != notificationId)
          .toList(),
    );
  }

  QrHandoffCase _consumeBackendCase(Map<String, dynamic> raw) {
    final mapped = _mapBackendCase(raw);
    _upsertCase(mapped);
    _syncApprovals(raw['approvals']);
    return mapped;
  }

  void _syncApprovals(dynamic rawList) {
    if (rawList is! List) return;
    final mapped = rawList
        .whereType<Map<String, dynamic>>()
        .map(_mapApproval)
        .toList();
    final byId = <String, OpsApprovalNotification>{
      for (final item in state.approvalNotifications) item.id: item,
    };
    for (final item in mapped) {
      byId[item.id] = item;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(approvalNotifications: merged);
  }

  QrHandoffCase _mapBackendCase(Map<String, dynamic> raw) {
    final reservationId = raw['reservationId']?.toString() ?? '';
    final reservationCode = raw['reservationCode']?.toString() ?? '';
    final existing = state.casesByReservationId[reservationId];
    final now = DateTime.now();
    return QrHandoffCase(
      reservationId: reservationId,
      reservationCode: reservationCode,
      customerLanguage: raw['customerLanguage']?.toString() ?? 'es',
      customerQrPayload:
          raw['customerQrPayload']?.toString() ??
          _buildCustomerQrPayload(reservationCode),
      stage: _parseStage(raw['stage']?.toString()),
      bagUnits: (raw['bagUnits'] as num?)?.toInt() ?? existing?.bagUnits ?? 1,
      bagTagId: raw['bagTagId']?.toString(),
      bagTagQrPayload: raw['bagTagQrPayload']?.toString(),
      pickupPin: raw['pickupPinPreview']?.toString().isNotEmpty == true
          ? raw['pickupPinPreview']?.toString()
          : existing?.pickupPin,
      identityValidated: raw['identityValidated'] as bool? ?? false,
      luggageMatched: raw['luggageMatched'] as bool? ?? false,
      operatorApprovalRequested:
          raw['operatorApprovalRequested'] as bool? ?? false,
      operatorApprovalGranted: raw['operatorApprovalGranted'] as bool? ?? false,
      latestMessageForCustomer: raw['latestMessageForCustomer']?.toString(),
      latestMessageTranslated: raw['latestMessageTranslated']?.toString(),
      createdAt: existing?.createdAt ?? now,
      updatedAt:
          DateTime.tryParse(raw['updatedAt']?.toString() ?? '') ??
          existing?.updatedAt ??
          now,
    );
  }

  OpsApprovalNotification _mapApproval(Map<String, dynamic> raw) {
    final id =
        raw['id']?.toString() ?? 'ops-${DateTime.now().microsecondsSinceEpoch}';
    return OpsApprovalNotification(
      id: id,
      reservationId: raw['reservationId']?.toString() ?? '',
      reservationCode: raw['reservationCode']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(raw['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      messageForOperator: raw['messageForOperator']?.toString() ?? '',
      messageForCustomer: raw['messageForCustomer']?.toString() ?? '',
      messageForCustomerTranslated:
          raw['messageForCustomerTranslated']?.toString() ??
          raw['messageForCustomer']?.toString() ??
          '',
      status: _parseApprovalStatus(raw['status']?.toString()),
    );
  }

  QrHandoffStage _parseStage(String? raw) {
    final code = (raw ?? '').trim().toUpperCase();
    switch (code) {
      case 'QR_VALIDATED':
        return QrHandoffStage.qrValidated;
      case 'BAG_TAGGED':
        return QrHandoffStage.bagTagged;
      case 'STORED_AT_WAREHOUSE':
        return QrHandoffStage.storedAtWarehouse;
      case 'READY_FOR_PICKUP':
        return QrHandoffStage.readyForPickup;
      case 'PICKUP_PIN_VALIDATED':
        return QrHandoffStage.pickupPinValidated;
      case 'DELIVERY_IDENTITY_VALIDATED':
        return QrHandoffStage.deliveryIdentityValidated;
      case 'DELIVERY_LUGGAGE_VALIDATED':
        return QrHandoffStage.deliveryLuggageValidated;
      case 'DELIVERY_APPROVAL_PENDING':
        return QrHandoffStage.deliveryApprovalPending;
      case 'DELIVERY_APPROVAL_GRANTED':
        return QrHandoffStage.deliveryApprovalGranted;
      case 'DELIVERY_COMPLETED':
        return QrHandoffStage.deliveryCompleted;
      default:
        return QrHandoffStage.draft;
    }
  }

  OpsApprovalStatus _parseApprovalStatus(String? raw) {
    final code = (raw ?? '').trim().toUpperCase();
    switch (code) {
      case 'APPROVED':
        return OpsApprovalStatus.approved;
      case 'REJECTED':
        return OpsApprovalStatus.rejected;
      default:
        return OpsApprovalStatus.pending;
    }
  }

  QrHandoffCase _upsertCase(QrHandoffCase value) {
    final next = {...state.casesByReservationId, value.reservationId: value};
    state = state.copyWith(casesByReservationId: next);
    return value;
  }

  bool _isKnownApiCode(DioException error, Set<String> expectedCodes) {
    final data = error.response?.data;
    if (data is! Map<String, dynamic>) {
      return false;
    }
    final code = data['code']?.toString().trim().toUpperCase();
    if (code == null || code.isEmpty) {
      return false;
    }
    return expectedCodes.contains(code);
  }

  String _buildCustomerQrPayload(String reservationCode) {
    return 'TRAVELBOX|RESERVATION|$reservationCode';
  }
}

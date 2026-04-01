import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/payment_constants.dart';
import '../../../core/env/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/state/luggage_photo_memory_store.dart';
import '../../../shared/state/reservation_store.dart';
import '../../../shared/utils/app_exception.dart';
import '../domain/reservation_repository.dart';

final reservationDraftProvider = StateProvider<ReservationDraft?>(
  (ref) => null,
);

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return ReservationRepositoryImpl(dio: ref.watch(dioProvider), ref: ref);
});

class ReservationRepositoryImpl implements ReservationRepository {
  ReservationRepositoryImpl({required Dio dio, required Ref ref})
    : _dio = dio,
      _ref = ref;

  final Dio _dio;
  final Ref _ref;

  @override
  Future<Reservation> createReservation({
    required String userId,
    required ReservationDraft draft,
    String paymentMethod = PaymentConstants.methodCard,
    String? sourceTokenId,
    String? customerEmail,
  }) async {
    try {
      final warehouseId = int.tryParse(draft.warehouse.id);
      if (warehouseId == null) {
        throw const FormatException('warehouseId no numerico para backend');
      }

      await _validateAvailability(
        warehouseId: warehouseId,
        startAt: draft.startAt,
        endAt: draft.endAt,
      );

      final requestData = _buildReservationPayload(
        warehouseId: warehouseId,
        draft: draft,
      );
      final shouldHandlePaymentServerSide = _isOfflinePaymentMethod(
        paymentMethod,
      );

      Reservation? reservation = shouldHandlePaymentServerSide
          ? await _createReservationViaCheckout(
              userId: userId,
              draft: draft,
              requestData: requestData,
              paymentMethod: paymentMethod,
              sourceTokenId: sourceTokenId,
              customerEmail: customerEmail,
            )
          : null;

      if (reservation == null) {
        final response = await _dio.post<Map<String, dynamic>>(
          '/reservations',
          data: requestData,
        );

        reservation = _mapReservation(
          response.data ?? <String, dynamic>{},
          userId: userId,
          fallbackDraft: draft,
        );

        if (shouldHandlePaymentServerSide) {
          await _triggerPaymentFlow(
            reservationId: reservation.id,
            paymentMethod: paymentMethod,
            sourceTokenId: sourceTokenId,
            customerEmail: customerEmail,
          );
        }
      }

      final refreshed = await getReservationById(reservation.id);
      final finalReservation = refreshed ?? reservation;
      await _ref
          .read(reservationStoreProvider.notifier)
          .upsert(finalReservation);
      return finalReservation;
    } catch (error) {
      if (!AppEnv.useMockFallback) {
        if (error is DioException) {
          throw AppException.fromDioError(error);
        }
        throw AppException.fromError(error);
      }
      final now = DateTime.now();
      final reservation = Reservation(
        id: 'res-${now.millisecondsSinceEpoch}',
        code: 'TBX-${now.millisecondsSinceEpoch.toString().substring(7)}',
        userId: userId,
        warehouse: draft.warehouse,
        startAt: draft.startAt,
        endAt: draft.endAt,
        bagCount: draft.bagCount,
        totalPrice: draft.estimatePrice(),
        status: ReservationStatus.confirmed,
        timeline: [
          ReservationTimelineEvent(
            status: ReservationStatus.confirmed,
            timestamp: now,
            message:
                '__L10N__:reservation_timeline_reservation_confirmed_qr_generated',
          ),
        ],
        pickupRequested: draft.pickupRequested,
        dropoffRequested: draft.dropoffRequested,
        extraInsurance: draft.extraInsurance,
      );
      await _ref.read(reservationStoreProvider.notifier).upsert(reservation);
      return reservation;
    }
  }

  Map<String, dynamic> _buildReservationPayload({
    required int warehouseId,
    required ReservationDraft draft,
  }) {
    return {
      'warehouseId': warehouseId,
      'startAt': draft.startAt.toUtc().toIso8601String(),
      'endAt': draft.endAt.toUtc().toIso8601String(),
      'estimatedItems': draft.bagCount,
      'bagSize': draft.size,
      'pickupRequested': draft.pickupRequested,
      'dropoffRequested': draft.dropoffRequested,
      'deliveryRequested': draft.dropoffRequested,
      'extraInsurance': draft.extraInsurance,
    };
  }

  Future<Reservation?> _createReservationViaCheckout({
    required String userId,
    required ReservationDraft draft,
    required Map<String, dynamic> requestData,
    required String paymentMethod,
    String? sourceTokenId,
    String? customerEmail,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/reservations/checkout',
        data: {
          ...requestData,
          'paymentMethod': paymentMethod,
          if (sourceTokenId?.trim().isNotEmpty == true)
            'sourceTokenId': sourceTokenId!.trim(),
          if (customerEmail?.trim().isNotEmpty == true)
            'customerEmail': customerEmail!.trim(),
        },
      );

      return _mapReservation(
        response.data ?? <String, dynamic>{},
        userId: userId,
        fallbackDraft: draft,
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      final isEndpointMissing = error.requestOptions.path.endsWith('/checkout');

      if ((statusCode == 404 && isEndpointMissing) || statusCode == 405) {
        return null;
      }
      throw AppException.fromDioError(error);
    }
  }

  Future<void> _validateAvailability({
    required int warehouseId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/warehouses/$warehouseId/availability',
        queryParameters: {
          'startAt': startAt.toUtc().toIso8601String(),
          'endAt': endAt.toUtc().toIso8601String(),
        },
      );
      final data = response.data ?? <String, dynamic>{};
      final hasAvailability =
          data['hasAvailability'] as bool? ??
          ((data['availableInRange'] as num?)?.toInt() ?? 0) > 0;
      if (!hasAvailability) {
        throw StateError('No availability for the selected time range.');
      }
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      if (statusCode == 404 || statusCode == 405) {
        return;
      }
      throw AppException.fromDioError(error);
    }
  }

  Future<void> _triggerPaymentFlow({
    required String reservationId,
    required String paymentMethod,
    String? sourceTokenId,
    String? customerEmail,
  }) async {
    final parsedReservationId = int.tryParse(reservationId);
    if (parsedReservationId == null) return;

    try {
      final checkoutResponse = await _dio.post<Map<String, dynamic>>(
        '/payments/checkout',
        data: {
          'reservationId': parsedReservationId,
          'approved': true,
          'paymentMethod': paymentMethod,
          if (sourceTokenId?.trim().isNotEmpty == true)
            'sourceTokenId': sourceTokenId!.trim(),
          if (customerEmail?.trim().isNotEmpty == true)
            'customerEmail': customerEmail!.trim(),
        },
      );

      final checkoutData = checkoutResponse.data ?? <String, dynamic>{};
      final paymentIntentId =
          checkoutData['paymentIntentId']?.toString() ??
          checkoutData['id']?.toString() ??
          checkoutData['intentId']?.toString() ??
          checkoutData['paymentId']?.toString();

      if (_isOfflinePaymentMethod(paymentMethod)) {
        return;
      }
      if (paymentIntentId == null || paymentIntentId.isEmpty) {
        return;
      }
      await _verifyPaymentStatus(paymentIntentId: paymentIntentId);
      return;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      if (statusCode != 404 && statusCode != 405) {
        throw AppException.fromDioError(error);
      }
    }

    // Fallback para contratos antiguos: intents + confirm.
    final paymentIntent = await _dio.post<Map<String, dynamic>>(
      '/payments/intents',
      data: {'reservationId': parsedReservationId},
    );
    final intentData = paymentIntent.data ?? <String, dynamic>{};
    final intentId =
        intentData['id']?.toString() ??
        intentData['paymentIntentId']?.toString() ??
        intentData['intentId']?.toString() ??
        intentData['paymentId']?.toString();

    await _dio.post<Map<String, dynamic>>(
      '/payments/confirm',
      data: {
        if (intentId != null)
          'paymentIntentId': int.tryParse(intentId) ?? intentId,
        'reservationId': parsedReservationId,
        'approved': true,
        'providerReference': 'APP-${DateTime.now().millisecondsSinceEpoch}',
        'paymentMethod': paymentMethod,
      },
    );
  }

  Future<void> _verifyPaymentStatus({required String paymentIntentId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/payments/status',
      queryParameters: {
        'paymentIntentId': int.tryParse(paymentIntentId) ?? paymentIntentId,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    final paymentStatus =
        data['paymentStatus']?.toString().toUpperCase() ??
        data['status']?.toString().toUpperCase() ??
        '';
    if (paymentStatus == 'FAILED' || paymentStatus == 'REJECTED') {
      throw StateError('The payment was rejected by the gateway.');
    }
  }

  bool _isOfflinePaymentMethod(String paymentMethod) {
    return PaymentConstants.isOffline(paymentMethod);
  }

  @override
  Future<List<Reservation>> getReservationsByUser(String userId) async {
    try {
      final reservations = await _loadUserReservationsPageByPage(userId);
      await _ref
          .read(reservationStoreProvider.notifier)
          .replaceForUser(userId, reservations);
      return reservations.map(_applyMemoryLuggagePhotos).toList();
    } catch (_) {
      try {
        final response = await _dio.get<dynamic>('/reservations');
        final reservations = _extractList(response.data)
            .map(
              (item) =>
                  _mapReservation(item as Map<String, dynamic>, userId: userId),
            )
            .toList();
        await _ref
            .read(reservationStoreProvider.notifier)
            .replaceForUser(userId, reservations);
        return reservations.map(_applyMemoryLuggagePhotos).toList();
      } catch (error) {
        if (!AppEnv.useMockFallback) {
          if (error is DioException) {
            throw AppException.fromDioError(error);
          }
          throw AppException.fromError(error);
        }
        final local = _ref.read(reservationStoreProvider);
        return local
            .where((reservation) => reservation.userId == userId)
            .map(_applyMemoryLuggagePhotos)
            .toList()
          ..sort((a, b) => b.startAt.compareTo(a.startAt));
      }
    }
  }

  Future<List<Reservation>> _loadUserReservationsPageByPage(
    String userId,
  ) async {
    final merged = <String, Reservation>{};
    var page = 0;
    var hasNext = true;

    while (hasNext && page < 10) {
      final response = await _dio.get<dynamic>(
        '/reservations/page',
        queryParameters: {'page': page, 'size': 40},
      );
      final pageItems = _extractList(response.data)
          .map(
            (item) =>
                _mapReservation(item as Map<String, dynamic>, userId: userId),
          )
          .toList();
      for (final item in pageItems) {
        merged[item.id] = item;
      }
      final isLast = _extractBool(response.data, 'last');
      hasNext = !isLast;
      if (!hasNext || pageItems.isEmpty) {
        break;
      }
      page += 1;
    }

    final reservations = merged.values.toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
    return reservations;
  }

  @override
  Future<List<Reservation>> getAllReservations({
    ReservationStatus? status,
    String? query,
    int size = 50,
  }) async {
    final normalizedQuery = query?.trim();
    try {
      final response = await _dio.get<dynamic>(
        '/reservations/page',
        queryParameters: {
          'page': 0,
          'size': size,
          if (status != null) 'status': status.code,
          if (normalizedQuery != null && normalizedQuery.isNotEmpty)
            'query': normalizedQuery,
        },
      );
      return _extractList(response.data)
          .map((item) => _mapReservation(item as Map<String, dynamic>))
          .map(_applyMemoryLuggagePhotos)
          .toList();
    } catch (primaryError) {
      try {
        final response = await _dio.get<dynamic>('/reservations');
        return _extractList(response.data)
            .map((item) => _mapReservation(item as Map<String, dynamic>))
            .map(_applyMemoryLuggagePhotos)
            .where(
              (item) =>
                  (status == null || item.status == status) &&
                  _matchesReservationQuery(item, normalizedQuery),
            )
            .toList();
      } catch (_) {}
      if (!AppEnv.useMockFallback) {
        if (primaryError is DioException) {
          throw AppException.fromDioError(primaryError);
        }
        throw AppException.fromError(primaryError);
      }
      return _ref
          .read(reservationStoreProvider)
          .map(_applyMemoryLuggagePhotos)
          .where(
            (item) =>
                (status == null || item.status == status) &&
                _matchesReservationQuery(item, normalizedQuery),
          )
          .toList();
    }
  }

  @override
  Future<ReservationPagedResult> getAllReservationsPage({
    ReservationStatus? status,
    String? query,
    int page = 0,
    int size = 5,
  }) async {
    final normalizedQuery = query?.trim();
    final normalizedPage = page < 0 ? 0 : page;
    final normalizedSize = size <= 0 ? 5 : size;

    try {
      final response = await _dio.get<dynamic>(
        '/reservations/page',
        queryParameters: {
          'page': normalizedPage,
          'size': normalizedSize,
          if (status != null) 'status': status.code,
          if (normalizedQuery != null && normalizedQuery.isNotEmpty)
            'query': normalizedQuery,
        },
      );
      final raw = response.data;
      final items = _extractList(raw)
          .map((item) => _mapReservation(item as Map<String, dynamic>))
          .map(_applyMemoryLuggagePhotos)
          .toList();
      return ReservationPagedResult(
        items: items,
        page: _extractInt(raw, 'page', fallback: normalizedPage),
        size: _extractInt(raw, 'size', fallback: normalizedSize),
        totalPages: _extractInt(raw, 'totalPages'),
        totalItems: _extractInt(raw, 'totalItems'),
        hasNext: _extractBool(raw, 'hasNext'),
        hasPrevious: _extractBool(raw, 'hasPrevious'),
      );
    } catch (error) {
      if (!AppEnv.useMockFallback) {
        if (error is DioException) {
          throw AppException.fromDioError(error);
        }
        throw AppException.fromError(error);
      }
      final localItems =
          _ref
              .read(reservationStoreProvider)
              .map(_applyMemoryLuggagePhotos)
              .where(
                (item) =>
                    (status == null || item.status == status) &&
                    _matchesReservationQuery(item, normalizedQuery),
              )
              .toList()
            ..sort((a, b) => b.startAt.compareTo(a.startAt));
      final start = normalizedPage * normalizedSize;
      if (start >= localItems.length) {
        return ReservationPagedResult(
          items: const [],
          page: normalizedPage,
          size: normalizedSize,
          totalPages: localItems.isEmpty
              ? 0
              : ((localItems.length - 1) ~/ normalizedSize) + 1,
          totalItems: localItems.length,
          hasNext: false,
          hasPrevious: normalizedPage > 0,
        );
      }
      final endExclusive = (start + normalizedSize).clamp(0, localItems.length);
      return ReservationPagedResult(
        items: localItems.sublist(start, endExclusive),
        page: normalizedPage,
        size: normalizedSize,
        totalPages: localItems.isEmpty
            ? 0
            : ((localItems.length - 1) ~/ normalizedSize) + 1,
        totalItems: localItems.length,
        hasNext: endExclusive < localItems.length,
        hasPrevious: normalizedPage > 0,
      );
    }
  }

  @override
  Future<Reservation?> getReservationById(String reservationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reservations/$reservationId',
      );
      final data = response.data;
      if (data == null) return null;
      final reservationPayload =
          data['reservation'] as Map<String, dynamic>? ?? data;
      final reservation = _mapReservation(
        reservationPayload,
        fallbackReservationId: reservationId,
      );
      await _ref.read(reservationStoreProvider.notifier).upsert(reservation);
      return _applyMemoryLuggagePhotos(reservation);
    } catch (error) {
      if (!AppEnv.useMockFallback) {
        if (error is DioException) {
          throw AppException.fromDioError(error);
        }
        throw AppException.fromError(error);
      }
      final local = _ref
          .read(reservationStoreProvider.notifier)
          .findById(reservationId);
      if (local == null) {
        return null;
      }
      return _applyMemoryLuggagePhotos(local);
    }
  }

  @override
  Future<Reservation> updateStatus({
    required String reservationId,
    required ReservationStatus status,
    required String message,
  }) async {
    try {
      await _callBackendStatusTransition(
        reservationId: reservationId,
        status: status,
        message: message,
      );

      final refreshed = await getReservationById(reservationId);
      if (refreshed != null) {
        return refreshed;
      }
      return _updateLocalStatus(
        reservationId: reservationId,
        status: status,
        message: message,
      );
    } catch (error) {
      if (!AppEnv.useMockFallback) {
        if (error is DioException) {
          throw AppException.fromDioError(error);
        }
        throw AppException.fromError(error);
      }
      return _updateLocalStatus(
        reservationId: reservationId,
        status: status,
        message: message,
      );
    }
  }

  @override
  Future<void> refundAndCancelReservation({
    required String reservationId,
    required String reason,
  }) async {
    final parsedReservationId = int.tryParse(reservationId);
    if (parsedReservationId == null) {
      throw const FormatException('reservationId no numerico para backend');
    }
    final normalizedReason = _truncate(
      reason.trim().isEmpty
          ? 'Cancellation requested from the app.'
          : reason.trim(),
      240,
    );

    Map<String, dynamic>? paymentStatusPayload;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/payments/status',
        queryParameters: {'reservationId': parsedReservationId},
      );
      paymentStatusPayload = response.data;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      if (statusCode != 404 && statusCode != 405) {
        throw AppException.fromDioError(error);
      }
    }

    final paymentStatus = paymentStatusPayload?['paymentStatus']
        ?.toString()
        .trim()
        .toUpperCase();
    final paymentMethod = paymentStatusPayload?['paymentMethod']
        ?.toString()
        .trim()
        .toUpperCase();
    final paymentIntentId = paymentStatusPayload?['paymentIntentId']
        ?.toString();
    final requiresRefund =
        paymentStatus == 'CONFIRMED' && _isDigitalPaymentMethod(paymentMethod);

    if (requiresRefund) {
      if (paymentIntentId == null || paymentIntentId.isEmpty) {
        throw StateError(
          'Confirmed payment has no paymentIntentId for refund execution.',
        );
      }
      await _dio.post<void>(
        '/payments/$paymentIntentId/refund',
        data: {'reason': normalizedReason},
      );
    } else {
      await _dio.patch<void>(
        '/reservations/$parsedReservationId/cancel',
        data: {'reason': normalizedReason},
      );
    }

    final refreshed = await getReservationById(reservationId);
    if (refreshed != null) {
      return;
    }
    if (AppEnv.useMockFallback) {
      _updateLocalStatus(
        reservationId: reservationId,
        status: ReservationStatus.cancelled,
        message: normalizedReason,
      );
    }
  }

  @override
  Future<void> requestLogisticsOrder({
    required String reservationId,
    required String type,
    required String address,
    String? zone,
    double? latitude,
    double? longitude,
    String? message,
  }) async {
    final parsedReservationId = int.tryParse(reservationId);
    if (parsedReservationId == null) {
      throw const FormatException('reservationId no numerico para backend');
    }
    final normalizedType = type.trim().toUpperCase();
    try {
      final requestData = <String, dynamic>{
        'reservationId': parsedReservationId,
        'type': normalizedType,
        'address': _truncate(address.trim(), 220),
        'zone': _truncate((zone ?? '').trim(), 120),
        'latitude': latitude,
        'longitude': longitude,
      }..removeWhere((_, value) => value == null);
      await _dio.post('/delivery-orders', data: requestData);

      final refreshed = await getReservationById(reservationId);
      if (refreshed != null) {
        return;
      }

      if (!AppEnv.useMockFallback) {
        return;
      }
      final fallbackStatus = normalizedType == 'PICKUP'
          ? ReservationStatus.checkinPending
          : ReservationStatus.outForDelivery;
      _updateLocalStatus(
        reservationId: reservationId,
        status: fallbackStatus,
        message: message?.trim().isNotEmpty == true
            ? message!.trim()
            : normalizedType == 'PICKUP'
            ? '__L10N__:reservation_timeline_pickup_requested'
            : '__L10N__:reservation_timeline_delivery_requested',
      );
    } on DioException catch (error) {
      if (!AppEnv.useMockFallback) {
        throw AppException.fromDioError(error);
      }
      final fallbackStatus = normalizedType == 'PICKUP'
          ? ReservationStatus.checkinPending
          : ReservationStatus.outForDelivery;
      _updateLocalStatus(
        reservationId: reservationId,
        status: fallbackStatus,
        message: message?.trim().isNotEmpty == true
            ? message!.trim()
            : normalizedType == 'PICKUP'
            ? '__L10N__:reservation_timeline_pickup_requested'
            : '__L10N__:reservation_timeline_delivery_requested',
      );
    }
  }

  Future<void> _callBackendStatusTransition({
    required String reservationId,
    required ReservationStatus status,
    required String message,
  }) async {
    final parsedReservationId = int.tryParse(reservationId);
    if (parsedReservationId == null) {
      throw const FormatException('reservationId no numerico para backend');
    }

    switch (status) {
      case ReservationStatus.cancelled:
        await _dio.patch(
          '/reservations/$parsedReservationId/cancel',
          data: {
            'reason': message.trim().isEmpty
                ? '__L10N__:reservation_timeline_frontend_cancelled'
                : message.trim(),
          },
        );
        return;
      case ReservationStatus.checkinPending:
      case ReservationStatus.stored:
        await _dio.post(
          '/inventory/checkin',
          data: {'reservationId': parsedReservationId, 'notes': message},
        );
        return;
      case ReservationStatus.readyForPickup:
      case ReservationStatus.completed:
        await _dio.post(
          '/inventory/checkout',
          data: {'reservationId': parsedReservationId, 'notes': message},
        );
        return;
      case ReservationStatus.outForDelivery:
        await _dio.post(
          '/delivery-orders',
          data: {
            'reservationId': parsedReservationId,
            'type': 'DELIVERY',
            'address': _resolveDeliveryAddress(message),
            'zone': 'LIMA',
          },
        );
        return;
      case ReservationStatus.incident:
        await _dio.post(
          '/incidents',
          data: {
            'reservationId': parsedReservationId,
            'description': _truncate(message, 500),
          },
        );
        return;
      case ReservationStatus.draft:
      case ReservationStatus.pendingPayment:
      case ReservationStatus.confirmed:
      case ReservationStatus.expired:
        return;
    }
  }

  Reservation _mapReservation(
    Map<String, dynamic> source, {
    String? userId,
    ReservationDraft? fallbackDraft,
    String? fallbackReservationId,
  }) {
    final json = Map<String, dynamic>.from(source);
    json['id'] = json['id']?.toString() ?? fallbackReservationId ?? '';
    json['userId'] = json['userId']?.toString() ?? userId ?? '';
    json['bagCount'] =
        json['bagCount'] ??
        json['estimatedItems'] ??
        fallbackDraft?.bagCount ??
        1;
    json['totalPrice'] =
        json['totalPrice'] ??
        json['total'] ??
        fallbackDraft?.estimatePrice() ??
        0;

    if (json['warehouse'] == null) {
      json['warehouse'] = _buildWarehousePayload(
        json,
        fallbackDraft: fallbackDraft,
      );
    }

    if (json['startAt'] == null && fallbackDraft != null) {
      json['startAt'] = fallbackDraft.startAt.toIso8601String();
    }
    if (json['endAt'] == null && fallbackDraft != null) {
      json['endAt'] = fallbackDraft.endAt.toIso8601String();
    }
    if (json['code'] == null || json['code'].toString().isEmpty) {
      json['code'] =
          json['qrCode']?.toString() ??
          'TBX-${json['id']?.toString() ?? DateTime.now().millisecond}';
    }

    return Reservation.fromJson(json);
  }

  Map<String, dynamic> _buildWarehousePayload(
    Map<String, dynamic> reservationJson, {
    ReservationDraft? fallbackDraft,
  }) {
    final fallbackWarehouse = fallbackDraft?.warehouse;
    return <String, dynamic>{
      'id':
          reservationJson['warehouseId'] ??
          fallbackWarehouse?.id ??
          reservationJson['warehouse']?['id'],
      'name':
          reservationJson['warehouseName'] ??
          fallbackWarehouse?.name ??
          'Warehouse',
      'address':
          reservationJson['warehouseAddress'] ??
          fallbackWarehouse?.address ??
          'Address pending',
      'city':
          reservationJson['cityName'] ??
          fallbackWarehouse?.city ??
          reservationJson['city'] ??
          '',
      'district':
          reservationJson['zoneName'] ??
          fallbackWarehouse?.district ??
          reservationJson['district'] ??
          '',
      'latitude':
          reservationJson['lat'] ??
          reservationJson['latitude'] ??
          fallbackWarehouse?.latitude ??
          0,
      'longitude':
          reservationJson['lng'] ??
          reservationJson['longitude'] ??
          fallbackWarehouse?.longitude ??
          0,
      'openingHours':
          reservationJson['openingHours'] ??
          fallbackWarehouse?.openingHours ??
          '08:00 - 22:00',
      'priceFromPerHour':
          reservationJson['priceFromPerHour'] ??
          fallbackWarehouse?.priceFromPerHour ??
          4.5,
      'score': reservationJson['score'] ?? fallbackWarehouse?.score ?? 0,
      'availableSlots':
          reservationJson['availableInRange'] ??
          reservationJson['available'] ??
          fallbackWarehouse?.availableSlots ??
          0,
      'extraServices':
          reservationJson['extraServices'] ??
          fallbackWarehouse?.extraServices ??
          <String>[],
    };
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List<dynamic>) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final items = data['items'] ?? data['content'] ?? data['data'];
      if (items is List<dynamic>) {
        return items;
      }
    }
    return const [];
  }

  bool _extractBool(dynamic data, String key) {
    if (data is Map<String, dynamic>) {
      return data[key] as bool? ?? false;
    }
    return false;
  }

  int _extractInt(dynamic data, String key, {int fallback = 0}) {
    if (data is! Map<String, dynamic>) {
      return fallback;
    }
    final raw = data[key];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  String _resolveDeliveryAddress(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'Address pending confirmation in app';
    }
    return _truncate(trimmed, 220);
  }

  String _truncate(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max);
  }

  bool _isDigitalPaymentMethod(String? paymentMethod) {
    if (paymentMethod == null || paymentMethod.isEmpty) {
      return false;
    }
    final normalized = paymentMethod.trim().toLowerCase();
    return normalized == PaymentConstants.methodCard ||
        normalized == PaymentConstants.methodYape ||
        normalized == 'plin' ||
        normalized == PaymentConstants.methodWallet;
  }

  bool _matchesReservationQuery(Reservation item, String? query) {
    if (query == null || query.isEmpty) return true;
    final normalized = query.trim().toLowerCase();
    return item.code.toLowerCase().contains(normalized) ||
        item.warehouse.name.toLowerCase().contains(normalized) ||
        item.warehouse.city.toLowerCase().contains(normalized) ||
        item.warehouse.district.toLowerCase().contains(normalized);
  }

  Reservation _updateLocalStatus({
    required String reservationId,
    required ReservationStatus status,
    required String message,
  }) {
    final current = _ref
        .read(reservationStoreProvider.notifier)
        .findById(reservationId);
    if (current == null) {
      throw StateError('Reservation not found: $reservationId');
    }
    final updated = current.copyWith(
      status: status,
      timeline: [
        ...current.timeline,
        ReservationTimelineEvent(
          status: status,
          timestamp: DateTime.now(),
          message: message,
        ),
      ],
    );
    _ref.read(reservationStoreProvider.notifier).upsert(updated);
    return updated;
  }

  Reservation _applyMemoryLuggagePhotos(Reservation reservation) {
    return _ref
        .read(luggagePhotoMemoryStoreProvider.notifier)
        .applyToReservation(reservation);
  }

  @override
  Future<Reservation> createAssistedReservation({
    required String userId,
    required ReservationDraft draft,
  }) async {
    try {
      final warehouseId = int.tryParse(draft.warehouse.id);
      if (warehouseId == null) {
        throw const FormatException('warehouseId no numerico para backend');
      }

      final requestData = _buildReservationPayload(
        warehouseId: warehouseId,
        draft: draft,
      );

      final response = await _dio.post<Map<String, dynamic>>(
        '/reservations/assisted',
        data: requestData,
      );

      final reservation = _mapReservation(
        response.data ?? <String, dynamic>{},
        userId: userId,
        fallbackDraft: draft,
      );

      await _ref.read(reservationStoreProvider.notifier).upsert(reservation);
      return reservation;
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<String> getReservationQrCode(String reservationId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/reservations/$reservationId/qr',
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      final bytes = response.data as List<int>;
      final base64 = base64Encode(bytes);
      return 'data:image/png;base64,$base64';
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  @override
  Future<ReservationTracking> getReservationTracking(String reservationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reservations/$reservationId/tracking',
      );
      final data = response.data ?? <String, dynamic>{};
      return _mapReservationTracking(data, reservationId);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.fromError(e);
    }
  }

  ReservationTracking _mapReservationTracking(Map<String, dynamic> data, String reservationId) {
    return ReservationTracking(
      reservationId: reservationId,
      status: data['status']?.toString() ?? '',
      currentStep: data['currentStep']?.toString(),
      estimatedCompletion: data['estimatedCompletion'] != null
          ? DateTime.tryParse(data['estimatedCompletion'].toString())
          : null,
      steps: (data['steps'] as List<dynamic>?)
              ?.map((s) => TrackingStep(
                    id: s['id']?.toString() ?? '',
                    title: s['title']?.toString() ?? '',
                    description: s['description']?.toString() ?? '',
                    timestamp: s['timestamp'] != null
                        ? DateTime.tryParse(s['timestamp'].toString())
                        : null,
                    isCompleted: s['isCompleted'] as bool? ?? false,
                    isActive: s['isActive'] as bool? ?? false,
                  ))
              .toList() ??
          [],
    );
  }
}

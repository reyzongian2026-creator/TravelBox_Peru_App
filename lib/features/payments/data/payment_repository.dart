import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class PaymentRepository {
  Future<PaymentIntentResult> createIntent({
    required int reservationId,
    String? promoCode,
    double? walletAmount,
  });

  Future<PaymentIntentResult> confirmPayment({
    int? paymentIntentId,
    int? reservationId,
    required String paymentMethod,
    String? sourceTokenId,
    String? customerEmail,
    String? customerFirstName,
    String? customerLastName,
    String? customerPhone,
    String? customerDocument,
    bool approved = true,
  });

  Future<PaymentStatusResult> getPaymentStatus({
    int? paymentIntentId,
    int? reservationId,
  });

  Future<PaymentHistoryResult> getPaymentHistory({
    int page = 0,
    int size = 20,
    String? reservationId,
  });

  Future<List<CashPendingPayment>> getPendingCashPayments({
    int page = 0,
    int size = 20,
  });

  Future<void> approveCashPayment({
    required String paymentIntentId,
    String? notes,
  });

  Future<void> rejectCashPayment({
    required String paymentIntentId,
    required String reason,
  });

  Future<List<SavedCard>> getSavedCards();

  Future<PaymentIntentResult> payWithSavedCard({
    required int reservationId,
    required int savedCardId,
  });

  Future<PaymentIntentResult> syncPaymentStatus({
    required int paymentIntentId,
  });

  Future<PaymentIntentResult> validateCheckoutResult({
    required String krAnswer,
    required String krHash,
    int? paymentIntentId,
    int? reservationId,
  });

  Future<Map<String, dynamic>> getCancellationPreview({
    required int reservationId,
  });

  Future<PaymentIntentResult?> confirmCancellation({
    required int reservationId,
    String? reason,
  });

  Future<PromoCodeResult> validatePromoCode({
    required String code,
    required double amount,
  });

  Future<double> getWalletBalance();
}

class SavedCard {
  final String id;
  final String alias;
  final String brand;
  final String lastFourDigits;
  final String expirationMonth;
  final String expirationYear;

  const SavedCard({
    required this.id,
    required this.alias,
    required this.brand,
    required this.lastFourDigits,
    required this.expirationMonth,
    required this.expirationYear,
  });

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    return SavedCard(
      id: (json['id'] ?? '').toString(),
      alias: json['alias']?.toString() ?? 'Tarjeta',
      brand: json['brand']?.toString() ?? 'Visa',
      lastFourDigits: json['lastFourDigits']?.toString() ?? '****',
      expirationMonth: json['expirationMonth']?.toString() ?? '',
      expirationYear: json['expirationYear']?.toString() ?? '',
    );
  }
}

class PaymentIntentResult {
  final String id;
  final String? reservationId;
  final double amount;
  final String status;
  final String? paymentMethod;
  final String? paymentFlow;
  final String? message;
  final Map<String, dynamic>? nextAction;

  const PaymentIntentResult({
    required this.id,
    this.reservationId,
    required this.amount,
    required this.status,
    this.paymentMethod,
    this.paymentFlow,
    this.message,
    this.nextAction,
  });

  bool get requires3ds =>
      paymentFlow == 'REQUIRES_3DS_AUTH' &&
      nextAction?['type'] == 'AUTHENTICATE_3DS';

  String? get threeDsUrl {
    final payload =
        nextAction?['providerPayload'] as Map<String, dynamic>? ?? {};
    return payload['authenticationUrl']?.toString();
  }

  bool get requiresIzipayCheckout =>
      paymentFlow == 'OPEN_IZIPAY_CHECKOUT' &&
      nextAction?['type'] == 'OPEN_IZIPAY_CHECKOUT';

  bool get requiresManualTransfer =>
      paymentFlow == 'WAITING_MANUAL_TRANSFER' &&
      nextAction?['type'] == 'SHOW_TRANSFER_QR';

  bool get isConfirmed =>
      status == 'CONFIRMED' || paymentFlow == 'DIRECT_CHARGE' || paymentFlow == 'DIRECT_CONFIRMATION';

  bool get isFailed =>
      status == 'FAILED' || (paymentFlow?.contains('REJECTED') ?? false);

  bool get isWaitingOffline =>
      paymentFlow == 'WAITING_OFFLINE_VALIDATION';

  factory PaymentIntentResult.fromJson(Map<String, dynamic> json) {
    return PaymentIntentResult(
      id: (json['id'] ?? json['paymentIntentId'] ?? json['intentId'] ?? json['paymentId'] ?? '')
          .toString(),
      reservationId: json['reservationId']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? '',
      paymentMethod: json['paymentMethod']?.toString(),
      paymentFlow: json['paymentFlow']?.toString(),
      message: json['message']?.toString(),
      nextAction: json['nextAction'] as Map<String, dynamic>?,
    );
  }
}

class PaymentStatusResult {
  final String paymentIntentId;
  final String? reservationId;
  final String paymentStatus;
  final String? reservationStatus;
  final double amount;
  final String? paymentMethod;

  const PaymentStatusResult({
    required this.paymentIntentId,
    this.reservationId,
    required this.paymentStatus,
    this.reservationStatus,
    required this.amount,
    this.paymentMethod,
  });

  bool get isConfirmed => paymentStatus.toUpperCase() == 'CONFIRMED';
  bool get isFailed =>
      paymentStatus.toUpperCase() == 'FAILED' ||
      paymentStatus.toUpperCase() == 'REJECTED';
  bool get isPending => paymentStatus.toUpperCase() == 'PENDING';

  factory PaymentStatusResult.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResult(
      paymentIntentId:
          (json['paymentIntentId'] ?? json['id'] ?? '').toString(),
      reservationId: json['reservationId']?.toString(),
      paymentStatus: json['paymentStatus']?.toString() ?? json['status']?.toString() ?? '',
      reservationStatus: json['reservationStatus']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod']?.toString(),
    );
  }
}

class PaymentHistoryResult {
  final List<PaymentHistoryItem> items;
  final int page;
  final int size;
  final int totalPages;
  final int totalItems;
  final bool hasNext;
  final bool hasPrevious;

  const PaymentHistoryResult({
    required this.items,
    required this.page,
    required this.size,
    required this.totalPages,
    required this.totalItems,
    required this.hasNext,
    required this.hasPrevious,
  });
}

class PaymentHistoryItem {
  final String id;
  final String reservationId;
  final String reservationCode;
  final double amount;
  final String status;
  final String method;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  const PaymentHistoryItem({
    required this.id,
    required this.reservationId,
    required this.reservationCode,
    required this.amount,
    required this.status,
    required this.method,
    required this.createdAt,
    this.confirmedAt,
  });

  factory PaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryItem(
      id: json['id']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      reservationCode: json['reservationCode']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? '',
      method: json['method']?.toString() ?? json['paymentMethod']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      confirmedAt: json['confirmedAt'] != null
          ? DateTime.tryParse(json['confirmedAt'].toString())
          : null,
    );
  }
}

class CashPendingPayment {
  final String id;
  final String reservationId;
  final String reservationCode;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String? customerName;
  final String? customerEmail;

  const CashPendingPayment({
    required this.id,
    required this.reservationId,
    required this.reservationCode,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.customerName,
    this.customerEmail,
  });

  factory CashPendingPayment.fromJson(Map<String, dynamic> json) {
    return CashPendingPayment(
      id: json['id']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      reservationCode: json['reservationCode']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      customerName: json['customerName']?.toString(),
      customerEmail: json['customerEmail']?.toString(),
    );
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(dio: ref.watch(dioProvider));
});

class PaymentRepositoryImpl implements PaymentRepository {
  final Dio _dio;

  PaymentRepositoryImpl({required Dio dio}) : _dio = dio;

  @override
  Future<PaymentIntentResult> createIntent({
    required int reservationId,
    String? promoCode,
    double? walletAmount,
  }) async {
    try {
      final data = <String, dynamic>{'reservationId': reservationId};
      if (promoCode != null && promoCode.isNotEmpty) {
        data['promoCode'] = promoCode;
      }
      if (walletAmount != null && walletAmount > 0) {
        data['walletAmount'] = walletAmount;
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '/payments/intents',
        data: data,
      );
      return PaymentIntentResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<PaymentIntentResult> confirmPayment({
    int? paymentIntentId,
    int? reservationId,
    required String paymentMethod,
    String? sourceTokenId,
    String? customerEmail,
    String? customerFirstName,
    String? customerLastName,
    String? customerPhone,
    String? customerDocument,
    bool approved = true,
  }) async {
    final normalizedSourceTokenId = sourceTokenId?.trim();
    final normalizedCustomerEmail = customerEmail?.trim();
    final normalizedCustomerFirstName = customerFirstName?.trim();
    final normalizedCustomerLastName = customerLastName?.trim();
    final normalizedCustomerPhone = customerPhone?.trim();
    final normalizedCustomerDocument = customerDocument?.trim();
    final payload = <String, dynamic>{
      'paymentMethod': paymentMethod,
      'approved': approved,
    };
    if (paymentIntentId != null) {
      payload['paymentIntentId'] = paymentIntentId;
    }
    if (reservationId != null) {
      payload['reservationId'] = reservationId;
    }
    if (normalizedSourceTokenId != null && normalizedSourceTokenId.isNotEmpty) {
      payload['sourceTokenId'] = normalizedSourceTokenId;
    }
    if (normalizedCustomerEmail != null && normalizedCustomerEmail.isNotEmpty) {
      payload['customerEmail'] = normalizedCustomerEmail;
    }
    if (normalizedCustomerFirstName != null &&
        normalizedCustomerFirstName.isNotEmpty) {
      payload['customerFirstName'] = normalizedCustomerFirstName;
    }
    if (normalizedCustomerLastName != null &&
        normalizedCustomerLastName.isNotEmpty) {
      payload['customerLastName'] = normalizedCustomerLastName;
    }
    if (normalizedCustomerPhone != null && normalizedCustomerPhone.isNotEmpty) {
      payload['customerPhone'] = normalizedCustomerPhone;
    }
    if (normalizedCustomerDocument != null &&
        normalizedCustomerDocument.isNotEmpty) {
      payload['customerDocument'] = normalizedCustomerDocument;
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/payments/confirm',
        data: payload,
      );
      return PaymentIntentResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<PaymentStatusResult> getPaymentStatus({
    int? paymentIntentId,
    int? reservationId,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (paymentIntentId != null) {
      queryParameters['paymentIntentId'] = paymentIntentId;
    }
    if (reservationId != null) {
      queryParameters['reservationId'] = reservationId;
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/payments/status',
        queryParameters: queryParameters,
      );
      return PaymentStatusResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<PaymentHistoryResult> getPaymentHistory({
    int page = 0,
    int size = 20,
    String? reservationId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/payments/history',
        queryParameters: {
          'page': page,
          'size': size,
          if (reservationId != null) 'reservationId': reservationId,
        },
      );

      final data = response.data;
      if (data == null) {
        return const PaymentHistoryResult(
          items: [],
          page: 0,
          size: 20,
          totalPages: 0,
          totalItems: 0,
          hasNext: false,
          hasPrevious: false,
        );
      }

      final itemsRaw = data['content'] ?? data['items'] ?? data['data'] ?? [];
      final items = (itemsRaw as List)
          .map((item) => PaymentHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList();

      return PaymentHistoryResult(
        items: items,
        page: (data['page'] as int?) ?? page,
        size: (data['size'] as int?) ?? size,
        totalPages: (data['totalPages'] as int?) ?? 1,
        totalItems: (data['totalItems'] as int?) ?? items.length,
        hasNext: (data['hasNext'] as bool?) ?? false,
        hasPrevious: (data['hasPrevious'] as bool?) ?? page > 0,
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<CashPendingPayment>> getPendingCashPayments({
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/payments/cash/pending',
        queryParameters: {
          'page': page,
          'size': size,
        },
      );

      final data = response.data;
      if (data == null) {
        return [];
      }

      final itemsRaw = data['content'] ?? data['items'] ?? data['data'] ?? data['payments'] ?? [];
      return (itemsRaw as List)
          .map((item) => CashPendingPayment.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> approveCashPayment({
    required String paymentIntentId,
    String? notes,
  }) async {
    try {
      await _dio.post<void>(
        '/payments/cash/$paymentIntentId/approve',
        data: {
          if (notes != null) 'notes': notes,
        },
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<void> rejectCashPayment({
    required String paymentIntentId,
    required String reason,
  }) async {
    try {
      await _dio.post<void>(
        '/payments/cash/$paymentIntentId/reject',
        data: {
          'reason': reason,
        },
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<List<SavedCard>> getSavedCards() async {
    try {
      final response = await _dio.get<List<dynamic>>('/payments/cards');
      final items = response.data ?? [];
      return items.map((item) => SavedCard.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<PaymentIntentResult> payWithSavedCard({
    required int reservationId,
    required int savedCardId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/payments/one-click',
        queryParameters: {
          'reservationId': reservationId,
          'savedCardId': savedCardId,
        },
      );
      return PaymentIntentResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<PaymentIntentResult> syncPaymentStatus({
    required int paymentIntentId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/payments/$paymentIntentId/sync');
      return PaymentIntentResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<PaymentIntentResult> validateCheckoutResult({
    required String krAnswer,
    required String krHash,
    int? paymentIntentId,
    int? reservationId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'krAnswer': krAnswer,
        'krHash': krHash,
      };
      if (paymentIntentId != null) {
        payload['paymentIntentId'] = paymentIntentId;
      }
      if (reservationId != null) {
        payload['reservationId'] = reservationId;
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '/payments/validate-checkout',
        data: payload,
      );
      return PaymentIntentResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getCancellationPreview({
    required int reservationId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/payments/cancellation-preview/$reservationId',
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<PaymentIntentResult?> confirmCancellation({
    required int reservationId,
    String? reason,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/payments/cancellation-confirm/$reservationId',
        data: {
          if (reason != null) 'reason': reason,
        },
      );
      if (response.statusCode == 204 || response.data == null) {
        return null;
      }
      return PaymentIntentResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<PromoCodeResult> validatePromoCode({
    required String code,
    required double amount,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/payments/validate-promo',
        queryParameters: {'code': code, 'amount': amount},
      );
      return PromoCodeResult.fromJson(response.data ?? {});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }

  @override
  Future<double> getWalletBalance() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/payments/wallet-balance',
      );
      final data = response.data ?? {};
      final val = data['walletBalance'];
      if (val is num) return val.toDouble();
      return double.tryParse(val?.toString() ?? '0') ?? 0.0;
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    } catch (e) {
      throw AppException.fromError(e);
    }
  }
}

class PromoCodeResult {
  final bool valid;
  final String? code;
  final String? description;
  final String? discountType;
  final double? discountValue;
  final double? calculatedDiscount;
  final String? message;

  const PromoCodeResult({
    required this.valid,
    this.code,
    this.description,
    this.discountType,
    this.discountValue,
    this.calculatedDiscount,
    this.message,
  });

  factory PromoCodeResult.fromJson(Map<String, dynamic> json) {
    return PromoCodeResult(
      valid: json['valid'] == true,
      code: json['code']?.toString(),
      description: json['description']?.toString(),
      discountType: json['discountType']?.toString(),
      discountValue: (json['discountValue'] as num?)?.toDouble(),
      calculatedDiscount: (json['calculatedDiscount'] as num?)?.toDouble(),
      message: json['message']?.toString(),
    );
  }
}

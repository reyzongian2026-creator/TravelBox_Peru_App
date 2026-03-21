import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/utils/app_exception.dart';

abstract class PaymentRepository {
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
}

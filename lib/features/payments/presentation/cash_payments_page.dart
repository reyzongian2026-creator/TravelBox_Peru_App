import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/payment_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../reservation/presentation/reservation_providers.dart';

final cashPendingPaymentsProvider =
    FutureProvider.autoDispose<List<CashPendingPayment>>((ref) async {
      ref.watch(reservationRealtimeEventCursorProvider);
      final dio = ref.read(dioProvider);
      final response = await dio.get<Map<String, dynamic>>(
        '/payments/cash/pending',
        queryParameters: {'page': 0, 'size': 20},
      );
      final data = response.data ?? <String, dynamic>{};
      final items = data['items'] as List<dynamic>? ?? const [];
      final pending = items
          .map(
            (item) => CashPendingPayment.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      if (pending.isNotEmpty) {
        return pending;
      }

      // Fallback defensivo: si por cualquier motivo el endpoint de caja retorna
      // vacio, revisar historial y recuperar pendientes offline.
      try {
        final historyResponse = await dio.get<Map<String, dynamic>>(
          '/payments/history',
          queryParameters: {'page': 0, 'size': 100},
        );
        final historyData = historyResponse.data ?? <String, dynamic>{};
        final historyItems = historyData['items'] as List<dynamic>? ?? const [];
        final recovered = historyItems
            .whereType<Map<String, dynamic>>()
            .where(_isOfflinePendingFromHistory)
            .map(CashPendingPayment.fromHistoryJson)
            .toList();
        return recovered;
      } on DioException {
        return pending;
      }
    });

bool _isOfflinePendingFromHistory(Map<String, dynamic> item) {
  final paymentStatus = item['paymentStatus']?.toString().toUpperCase() ?? '';
  if (paymentStatus != 'PENDING') {
    return false;
  }
  final paymentMethod = item['paymentMethod']?.toString().toLowerCase() ?? '';
  final paymentFlow =
      item['paymentFlow']?.toString().toUpperCase() ??
      item['gatewayStatus']?.toString().toUpperCase() ??
      '';
  return PaymentConstants.isOffline(paymentMethod) ||
      paymentFlow.contains('OFFLINE');
}

class CashPaymentsPage extends ConsumerStatefulWidget {
  CashPaymentsPage({
    super.key,
    this.title = 'pagos_en_caja',
    this.currentRoute = '/admin/cash-payments',
  });

  final String title;
  final String currentRoute;

  @override
  ConsumerState<CashPaymentsPage> createState() => _CashPaymentsPageState();
}

class _CashPaymentsPageState extends ConsumerState<CashPaymentsPage> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final pendingPayments = ref.watch(cashPendingPaymentsProvider);
    return AppShellScaffold(
      title: context.l10n.t(widget.title),
      currentRoute: widget.currentRoute,
      child: pendingPayments.when(
        data: (items) {
          if (items.isEmpty) {
            return EmptyStateView(
              message:
                  'No hay pagos en caja pendientes.\nSi acabas de registrar un pago en efectivo, toca actualizar.',
              actionLabel: 'Actualizar ahora',
              onAction: () => ref.invalidate(cashPendingPaymentsProvider),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.refresh(cashPendingPaymentsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final payment = items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Intento #${payment.paymentIntentId} - Reserva #${payment.reservationId}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text('${payment.userName} (${payment.userEmail})'),
                        Text(
                          'Monto: S/${payment.amount.toStringAsFixed(2)} - Metodo: ${payment.paymentMethod}',
                        ),
                        Text(
                          'Horario: ${payment.startAt} -> ${payment.endAt}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: _processing
                                  ? null
                                  : () => _decide(
                                      paymentIntentId: payment.paymentIntentId,
                                      approve: true,
                                    ),
                              child: Text(context.l10n.t('aprobar')),
                            ),
                            OutlinedButton(
                              onPressed: _processing
                                  ? null
                                  : () => _decide(
                                      paymentIntentId: payment.paymentIntentId,
                                      approve: false,
                                    ),
                              child: Text(context.l10n.t('rechazar')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: 'No se pudieron cargar pagos en caja: $error',
          onRetry: () => ref.invalidate(cashPendingPaymentsProvider),
        ),
      ),
    );
  }

  Future<void> _decide({
    required String paymentIntentId,
    required bool approve,
  }) async {
    setState(() => _processing = true);
    final dio = ref.read(dioProvider);
    final action = approve ? 'approve' : 'reject';
    try {
      await dio.post<Map<String, dynamic>>(
        '/payments/cash/$paymentIntentId/$action',
        data: {
          'reason': approve
              ? 'Pago validado por operador'
              : 'Pago rechazado por operador',
        },
      );
      ref.invalidate(cashPendingPaymentsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Pago aprobado correctamente.'
                : 'Pago rechazado correctamente.',
          ),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final backendMessage = (error.response?.data is Map<String, dynamic>)
          ? (error.response?.data['message']?.toString())
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            backendMessage ??
                'No se pudo procesar el pago en caja: ${error.message}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }
}

class CashPendingPayment {
  const CashPendingPayment({
    required this.paymentIntentId,
    required this.reservationId,
    required this.userName,
    required this.userEmail,
    required this.amount,
    required this.paymentMethod,
    required this.startAt,
    required this.endAt,
  });

  final String paymentIntentId;
  final String reservationId;
  final String userName;
  final String userEmail;
  final double amount;
  final String paymentMethod;
  final DateTime startAt;
  final DateTime endAt;

  factory CashPendingPayment.fromJson(Map<String, dynamic> json) {
    return CashPendingPayment(
      paymentIntentId: json['paymentIntentId']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'Usuario',
      userEmail: json['userEmail']?.toString() ?? '-',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      startAt:
          DateTime.tryParse(json['reservationStartAt']?.toString() ?? '') ??
          DateTime.now(),
      endAt:
          DateTime.tryParse(json['reservationEndAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  factory CashPendingPayment.fromHistoryJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    final userEmail = json['userEmail']?.toString() ?? '-';
    return CashPendingPayment(
      paymentIntentId: json['paymentIntentId']?.toString() ?? '',
      reservationId: json['reservationId']?.toString() ?? '',
      userName: userEmail,
      userEmail: userEmail,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      startAt: createdAt,
      endAt: createdAt,
    );
  }
}

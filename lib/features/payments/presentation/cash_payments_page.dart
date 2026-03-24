import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/payment_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../reservation/presentation/reservation_providers.dart';

final cashPendingPaymentsProvider = FutureProvider.autoDispose<CashPendingPage>(
  (ref) async {
    ref.watch(reservationRealtimeEventCursorProvider);
    final page = ref.watch(cashPendingPageProvider);
    final dio = ref.read(dioProvider);
    final response = await dio.get<Map<String, dynamic>>(
      '/payments/cash/pending',
      queryParameters: {'page': page, 'size': 5},
    );
    final data = response.data ?? <String, dynamic>{};
    final items = data['items'] as List<dynamic>? ?? const [];
    final pending = items
        .map(
          (item) => CashPendingPayment.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    final pageInfo = CashPendingPage(
      items: pending,
      page: (data['page'] as num?)?.toInt() ?? page,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
      hasNext: data['hasNext'] as bool? ?? false,
      hasPrevious: data['hasPrevious'] as bool? ?? page > 0,
    );
    if (pending.isNotEmpty) {
      return pageInfo;
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
      final start = page * 5;
      if (start >= recovered.length) {
        return CashPendingPage(
          items: const [],
          page: page,
          totalPages: recovered.isEmpty ? 0 : ((recovered.length - 1) ~/ 5) + 1,
          hasNext: false,
          hasPrevious: page > 0,
        );
      }
      final end = (start + 5).clamp(0, recovered.length);
      return CashPendingPage(
        items: recovered.sublist(start, end),
        page: page,
        totalPages: recovered.isEmpty ? 0 : ((recovered.length - 1) ~/ 5) + 1,
        hasNext: end < recovered.length,
        hasPrevious: page > 0,
      );
    } on DioException {
      return pageInfo;
    }
  },
);

final cashPendingPageProvider = StateProvider<int>((ref) => 0);

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
  const CashPaymentsPage({
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
          final pageInfo = items;
          final rows = pageInfo.items;
          if (rows.isEmpty) {
            return EmptyStateView(
              message: context.l10n.t('cash_pending_empty'),
              actionLabel: context.l10n.t('cash_pending_refresh_now'),
              onAction: () => ref.invalidate(cashPendingPaymentsProvider),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.refresh(cashPendingPaymentsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == rows.length) {
                  final totalPages = pageInfo.totalPages <= 0
                      ? 1
                      : pageInfo.totalPages;
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${context.l10n.t('my_reservations_page')} ${pageInfo.page + 1} ${context.l10n.t('my_reservations_of')} $totalPages',
                        ),
                        OutlinedButton.icon(
                          onPressed: pageInfo.hasPrevious
                              ? () {
                                  final notifier = ref.read(
                                    cashPendingPageProvider.notifier,
                                  );
                                  if (notifier.state > 0) {
                                    notifier.state = notifier.state - 1;
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.chevron_left),
                          label: Text(context.l10n.t('previous')),
                        ),
                        FilledButton.icon(
                          onPressed: pageInfo.hasNext
                              ? () {
                                  final notifier = ref.read(
                                    cashPendingPageProvider.notifier,
                                  );
                                  notifier.state = notifier.state + 1;
                                }
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          label: Text(context.l10n.t('next')),
                        ),
                      ],
                    ),
                  );
                }
                final payment = rows[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.l10n.t('operator_attempt')} #${payment.paymentIntentId} - '
                          '${context.l10n.t('operator_reservation')} #${payment.reservationId}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text('${payment.userName} (${payment.userEmail})'),
                        Text(
                          '${context.l10n.t('amount')}: S/${payment.amount.toStringAsFixed(2)} - '
                          '${context.l10n.t('reservation_method')}: ${payment.paymentMethod}',
                        ),
                        Text(
                          '${context.l10n.t('schedule')}: ${payment.startAt} -> ${payment.endAt}',
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
          message:
              '${context.l10n.t('operator_pending_cash_load_failed')}: $error',
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
              ? context.l10n.t('cash_payment_reason_approved')
              : context.l10n.t('cash_payment_reason_rejected'),
        },
      );
      ref.read(cashPendingPageProvider.notifier).state = 0;
      ref.invalidate(cashPendingPaymentsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? context.l10n.t('cash_payment_approved_ok')
                : context.l10n.t('cash_payment_rejected_ok'),
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
                '${context.l10n.t('cash_payment_process_failed_prefix')}: ${error.message}',
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
      userName: json['userName']?.toString() ?? 'User',
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

class CashPendingPage {
  const CashPendingPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<CashPendingPayment> items;
  final int page;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
}

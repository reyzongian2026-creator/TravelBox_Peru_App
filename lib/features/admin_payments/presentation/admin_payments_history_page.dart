import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/state/realtime_app_event_cursor_provider.dart';
import '../../../shared/utils/status_localizer.dart';

final paymentHistoryStatusFilterProvider = StateProvider<String>(
  (ref) => 'ALL',
);
final paymentHistoryPageProvider = StateProvider<int>((ref) => 0);
final paymentHistoryPageSizeProvider = Provider<int>((ref) => 5);

final adminPaymentHistoryProvider = FutureProvider<AdminPaymentHistoryPage>((
  ref,
) async {
  ref.watch(realtimeAppEventCursorProvider);
  final status = ref.watch(paymentHistoryStatusFilterProvider);
  final page = ref.watch(paymentHistoryPageProvider);
  final size = ref.watch(paymentHistoryPageSizeProvider);
  final dio = ref.read(dioProvider);
  final response = await dio.get<Map<String, dynamic>>(
    '/payments/history',
    queryParameters: {
      'page': page,
      'size': size,
      if (status != 'ALL') 'status': status,
    },
  );
  final data = response.data ?? <String, dynamic>{};
  final items = data['items'] as List<dynamic>? ?? const [];
  final mapped = items
      .map(
        (item) =>
            AdminPaymentHistoryItem.fromJson(item as Map<String, dynamic>),
      )
      .toList();
  return AdminPaymentHistoryPage(
    items: mapped,
    page: (data['page'] as num?)?.toInt() ?? page,
    totalPages: (data['totalPages'] as num?)?.toInt() ?? 0,
    hasNext: data['hasNext'] as bool? ?? false,
    hasPrevious: data['hasPrevious'] as bool? ?? page > 0,
  );
});

class AdminPaymentHistoryPage {
  const AdminPaymentHistoryPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<AdminPaymentHistoryItem> items;
  final int page;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
}

class AdminPaymentsHistoryPage extends ConsumerWidget {
  const AdminPaymentsHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(adminPaymentHistoryProvider);
    final filter = ref.watch(paymentHistoryStatusFilterProvider);

    return AppShellScaffold(
      title: context.l10n.t('payments_history_title'),
      currentRoute: '/admin/payments-history',
      child: historyAsync.when(
        data: (pageData) {
          final items = pageData.items;
          void applyFilter(String value) {
            ref.read(paymentHistoryStatusFilterProvider.notifier).state = value;
            ref.read(paymentHistoryPageProvider.notifier).state = 0;
          }

          return SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _StatusChip(
                      label: context.l10n.t('todos'),
                      value: 'ALL',
                      current: filter,
                      onSelected: applyFilter,
                    ),
                    _StatusChip(
                      label: paymentStatusLabel(context, 'PENDING'),
                      value: 'PENDING',
                      current: filter,
                      onSelected: applyFilter,
                    ),
                    _StatusChip(
                      label: paymentStatusLabel(context, 'CONFIRMED'),
                      value: 'CONFIRMED',
                      current: filter,
                      onSelected: applyFilter,
                    ),
                    _StatusChip(
                      label: paymentStatusLabel(context, 'FAILED'),
                      value: 'FAILED',
                      current: filter,
                      onSelected: applyFilter,
                    ),
                    _StatusChip(
                      label: paymentStatusLabel(context, 'REFUNDED'),
                      value: 'REFUNDED',
                      current: filter,
                      onSelected: applyFilter,
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(adminPaymentHistoryProvider),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.t('recargar')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              items.isEmpty
                    ? SizedBox(
                        height: 300,
                        child: EmptyStateView(
                        message: context.l10n.t(
                          'payments_history_empty_filtered',
                        ),
                        actionLabel: pageData.hasPrevious
                            ? context.l10n.t('previous')
                            : context.l10n.t('recargar'),
                        onAction: pageData.hasPrevious
                            ? () {
                                final notifier = ref.read(
                                  paymentHistoryPageProvider.notifier,
                                );
                                if (notifier.state > 0) {
                                  notifier.state = notifier.state - 1;
                                }
                              }
                            : () => ref.invalidate(adminPaymentHistoryProvider),
                      ),
                    )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == items.length) {
                            final totalPages = pageData.totalPages <= 0
                                ? 1
                                : pageData.totalPages;
                            return Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '${context.l10n.t('my_reservations_page')} ${pageData.page + 1} ${context.l10n.t('my_reservations_of')} $totalPages',
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: pageData.hasPrevious
                                        ? () {
                                            final notifier = ref.read(
                                              paymentHistoryPageProvider
                                                  .notifier,
                                            );
                                            if (notifier.state > 0) {
                                              notifier.state =
                                                  notifier.state - 1;
                                            }
                                          }
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                    label: Text(context.l10n.t('previous')),
                                  ),
                                  FilledButton.icon(
                                    onPressed: pageData.hasNext
                                        ? () {
                                            final notifier = ref.read(
                                              paymentHistoryPageProvider
                                                  .notifier,
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
                          final item = items[index];
                          return _PaymentDetailCard(item: item);
                        },
                      ),
            ],
          ));
        },
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: '${context.l10n.t('payments_history_load_failed')}: $error',
          onRetry: () => ref.invalidate(adminPaymentHistoryProvider),
        ),
      ),
    );
  }
}

class _PaymentDetailCard extends StatelessWidget {
  const _PaymentDetailCard({required this.item});

  final AdminPaymentHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Icon & color per method
    final IconData icon;
    final Color methodColor;
    final String methodLabel;
    if (item.providerReference.startsWith('TRANSFER-YAPE')) {
      icon = Icons.qr_code_2;
      methodColor = const Color(0xFF6B2D8B);
      methodLabel = 'Yape';
    } else if (item.providerReference.startsWith('TRANSFER-PLIN')) {
      icon = Icons.phone_android;
      methodColor = const Color(0xFF00BFA5);
      methodLabel = 'Plin';
    } else if (item.providerReference.startsWith('TRANSFER-WALLET')) {
      icon = Icons.qr_code;
      methodColor = const Color(0xFF1565C0);
      methodLabel = 'QR Universal';
    } else if (item.paymentMethod == 'card' || item.paymentMethod == 'saved_card') {
      icon = Icons.credit_card;
      methodColor = Colors.indigo;
      methodLabel = 'Tarjeta';
    } else {
      icon = Icons.receipt_long_outlined;
      methodColor = Colors.grey.shade700;
      methodLabel = item.paymentMethod.toUpperCase();
    }

    // Status styling
    final Color statusColor;
    final String statusText;
    switch (item.paymentStatus.toUpperCase()) {
      case 'CONFIRMED':
        statusColor = Colors.green;
        statusText = 'Confirmado';
        break;
      case 'PENDING':
        statusColor = Colors.orange;
        statusText = 'Pendiente';
        break;
      case 'FAILED':
        statusColor = Colors.red;
        statusText = 'Fallido';
        break;
      case 'REFUNDED':
        statusColor = Colors.blue;
        statusText = 'Reembolsado';
        break;
      case 'REFUND_PENDING':
        statusColor = Colors.blue.shade300;
        statusText = 'Reembolso pendiente';
        break;
      default:
        statusColor = Colors.grey;
        statusText = item.paymentStatus;
    }

    // Confirmation source
    String? confirmationSource;
    if (item.isAutoConfirmedByEmail) {
      confirmationSource = 'Verificado automaticamente por email Yape';
    } else if (item.isConfirmedByOperator) {
      confirmationSource = 'Confirmado por operador';
    } else if (item.isMultipleMatch) {
      confirmationSource = 'Multiples coincidencias — requiere revision manual';
    }

    // Parse audit info from gatewayMessage
    String? senderName;
    String? txDate;
    if (item.gatewayMessage.contains('Remitente Yape:')) {
      final remRegex = RegExp(r'Remitente Yape:\s*([^|]+)');
      final dateRegex = RegExp(r'Fecha operacion:\s*([^|]+)');
      senderName = remRegex.firstMatch(item.gatewayMessage)?.group(1)?.trim();
      txDate = dateRegex.firstMatch(item.gatewayMessage)?.group(1)?.trim();
    }

    return Card(
      elevation: item.isMultipleMatch ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: item.isMultipleMatch
            ? const BorderSide(color: Colors.orange, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: methodColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: methodColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pago #${item.paymentIntentId} — Reserva #${item.reservationId}',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        item.userEmail,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withAlpha(100)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Details grid
            Wrap(
              spacing: 24,
              runSpacing: 6,
              children: [
                _DetailItem(label: 'Monto', value: 'S/${item.amount.toStringAsFixed(2)}', bold: true),
                _DetailItem(label: 'Metodo', value: methodLabel),
                _DetailItem(label: 'Proveedor', value: item.paymentProvider),
                if (item.createdAt.isNotEmpty)
                  _DetailItem(label: 'Fecha', value: _formatDate(item.createdAt)),
                if (item.providerReference.isNotEmpty)
                  _DetailItem(label: 'Referencia', value: item.providerReference),
              ],
            ),

            // Yape email verification details
            if (senderName != null || txDate != null || confirmationSource != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.isMultipleMatch ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.isMultipleMatch ? Colors.orange.shade200 : Colors.green.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (confirmationSource != null)
                      Row(
                        children: [
                          Icon(
                            item.isMultipleMatch ? Icons.warning_amber : Icons.verified,
                            size: 16,
                            color: item.isMultipleMatch ? Colors.orange.shade700 : Colors.green.shade700,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              confirmationSource,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: item.isMultipleMatch ? Colors.orange.shade800 : Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (senderName != null) ...[
                      const SizedBox(height: 4),
                      Text('Remitente Yape: $senderName',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                    ],
                    if (txDate != null) ...[
                      const SizedBox(height: 2),
                      Text('Fecha operacion: $txDate',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                    ],
                  ],
                ),
              ),
            ],

            // Generic gateway message for non-Yape
            if (senderName == null && item.gatewayMessage.isNotEmpty && item.isManualTransfer) ...[
              const SizedBox(height: 8),
              Text(
                item.gatewayMessage,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: current == value,
      onSelected: (_) => onSelected(value),
    );
  }
}

class AdminPaymentHistoryItem {
  const AdminPaymentHistoryItem({
    required this.paymentIntentId,
    required this.reservationId,
    required this.userEmail,
    required this.amount,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.paymentProvider,
    required this.providerReference,
    required this.gatewayStatus,
    required this.gatewayMessage,
    required this.paymentFlow,
    required this.createdAt,
  });

  final String paymentIntentId;
  final String reservationId;
  final String userEmail;
  final double amount;
  final String paymentStatus;
  final String paymentMethod;
  final String paymentProvider;
  final String providerReference;
  final String gatewayStatus;
  final String gatewayMessage;
  final String paymentFlow;
  final String createdAt;

  bool get isManualTransfer => providerReference.startsWith('TRANSFER-');
  bool get isAutoConfirmedByEmail => gatewayStatus == 'AUTO_CONFIRMED_YAPE_EMAIL';
  bool get isMultipleMatch => gatewayStatus == 'YAPE_EMAIL_MULTIPLE_MATCH';
  bool get isConfirmedByOperator => gatewayStatus == 'OFFLINE_CONFIRMED_BY_OPERATOR';

  factory AdminPaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    return AdminPaymentHistoryItem(
      paymentIntentId: json['paymentIntentId']?.toString() ?? '-',
      reservationId: json['reservationId']?.toString() ?? '-',
      userEmail: json['userEmail']?.toString() ?? '-',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentStatus: json['paymentStatus']?.toString() ?? 'UNKNOWN',
      paymentMethod: json['paymentMethod']?.toString() ?? '-',
      paymentProvider: json['paymentProvider']?.toString() ?? '-',
      providerReference: json['providerReference']?.toString() ?? '',
      gatewayStatus: json['gatewayStatus']?.toString() ?? '',
      gatewayMessage: json['gatewayMessage']?.toString() ?? '',
      paymentFlow: json['paymentFlow']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

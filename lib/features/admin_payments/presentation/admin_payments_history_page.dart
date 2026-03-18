import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/state/realtime_app_event_cursor_provider.dart';

final paymentHistoryStatusFilterProvider = StateProvider<String>((ref) => 'ALL');

final adminPaymentHistoryProvider = FutureProvider<List<AdminPaymentHistoryItem>>((
  ref,
) async {
  ref.watch(realtimeAppEventCursorProvider);
  final dio = ref.read(dioProvider);
  final response = await dio.get<Map<String, dynamic>>(
    '/payments/history',
    queryParameters: {'page': 0, 'size': 100},
  );
  final data = response.data ?? <String, dynamic>{};
  final items = data['items'] as List<dynamic>? ?? const [];
  return items
      .map((item) => AdminPaymentHistoryItem.fromJson(item as Map<String, dynamic>))
      .toList();
});

class AdminPaymentsHistoryPage extends ConsumerWidget {
  AdminPaymentsHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(adminPaymentHistoryProvider);
    final filter = ref.watch(paymentHistoryStatusFilterProvider);

    return AppShellScaffold(
      title: 'Historial de pagos',
      currentRoute: '/admin/payments-history',
      child: historyAsync.when(
        data: (items) {
          final filtered = filter == 'ALL'
              ? items
              : items.where((item) => item.paymentStatus == filter).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _StatusChip(
                      label: 'Todos',
                      value: 'ALL',
                      current: filter,
                      onSelected: (value) =>
                          ref.read(paymentHistoryStatusFilterProvider.notifier).state = value,
                    ),
                    _StatusChip(
                      label: 'Pendientes',
                      value: 'PENDING',
                      current: filter,
                      onSelected: (value) =>
                          ref.read(paymentHistoryStatusFilterProvider.notifier).state = value,
                    ),
                    _StatusChip(
                      label: 'Confirmados',
                      value: 'CONFIRMED',
                      current: filter,
                      onSelected: (value) =>
                          ref.read(paymentHistoryStatusFilterProvider.notifier).state = value,
                    ),
                    _StatusChip(
                      label: 'Fallidos',
                      value: 'FAILED',
                      current: filter,
                      onSelected: (value) =>
                          ref.read(paymentHistoryStatusFilterProvider.notifier).state = value,
                    ),
                    _StatusChip(
                      label: 'Reembolsados',
                      value: 'REFUNDED',
                      current: filter,
                      onSelected: (value) =>
                          ref.read(paymentHistoryStatusFilterProvider.notifier).state = value,
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(adminPaymentHistoryProvider),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.t('recargar')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyStateView(message: 'No hay pagos para este filtro.')
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.receipt_long_outlined),
                              title: Text(
                                'Pago #${item.paymentIntentId} - Reserva #${item.reservationId}',
                              ),
                              subtitle: Text(
                                '${item.userEmail}\nS/${item.amount.toStringAsFixed(2)} | ${item.paymentMethod} | ${item.paymentProvider}',
                              ),
                              isThreeLine: true,
                              trailing: Chip(
                                label: Text(item.paymentStatus),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: 'No se pudo cargar historial de pagos: $error',
          onRetry: () => ref.invalidate(adminPaymentHistoryProvider),
        ),
      ),
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
  });

  final String paymentIntentId;
  final String reservationId;
  final String userEmail;
  final double amount;
  final String paymentStatus;
  final String paymentMethod;
  final String paymentProvider;

  factory AdminPaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    return AdminPaymentHistoryItem(
      paymentIntentId: json['paymentIntentId']?.toString() ?? '-',
      reservationId: json['reservationId']?.toString() ?? '-',
      userEmail: json['userEmail']?.toString() ?? '-',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentStatus: json['paymentStatus']?.toString() ?? 'UNKNOWN',
      paymentMethod: json['paymentMethod']?.toString() ?? '-',
      paymentProvider: json['paymentProvider']?.toString() ?? '-',
    );
  }
}


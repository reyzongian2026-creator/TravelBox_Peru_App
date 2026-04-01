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
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.receipt_long_outlined),
                              title: Text(
                                '${context.l10n.t('payment')} #${item.paymentIntentId} - '
                                '${context.l10n.t('operator_reservation')} #${item.reservationId}',
                              ),
                              subtitle: Text(
                                '${item.userEmail}\nS/${item.amount.toStringAsFixed(2)} | ${item.paymentMethod} | ${item.paymentProvider}',
                              ),
                              isThreeLine: true,
                              trailing: Chip(
                                label: Text(
                                  paymentStatusLabel(
                                    context,
                                    item.paymentStatus,
                                  ),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          );
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

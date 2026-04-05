import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../shared/utils/status_localizer.dart';
import '../data/payment_repository.dart';

final clientPaymentHistoryPageProvider = StateProvider<int>((ref) => 0);

final clientPaymentHistoryProvider =
    FutureProvider<PaymentHistoryResult>((ref) async {
      final repository = ref.read(paymentRepositoryProvider);
      final page = ref.watch(clientPaymentHistoryPageProvider);
      return repository.getPaymentHistory(page: page, size: 10);
    });

class PaymentHistoryPage extends ConsumerWidget {
  const PaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(clientPaymentHistoryProvider);

    return AppShellScaffold(
      title: context.l10n.t('payments_history_title'),
      currentRoute: '/payments-history',
      child: historyAsync.when(
        data: (pageData) {
          if (pageData.items.isEmpty) {
            return EmptyStateView(
              message: context.l10n.t('payments_history_empty_filtered'),
              actionLabel: context.l10n.t('recargar'),
              onAction: () => ref.invalidate(clientPaymentHistoryProvider),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pageData.items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == pageData.items.length) {
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
                                  clientPaymentHistoryPageProvider.notifier,
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
                        onPressed: pageData.hasNext
                            ? () {
                                ref
                                        .read(
                                          clientPaymentHistoryPageProvider
                                              .notifier,
                                        )
                                        .state =
                                    pageData.page + 1;
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        label: Text(context.l10n.t('next')),
                      ),
                    ],
                  ),
                );
              }

              final item = pageData.items[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(
                    '${context.l10n.t('reservation')} #${item.reservationCode.isEmpty ? item.reservationId : item.reservationCode}',
                  ),
                  subtitle: Text(
                    '${context.l10n.t('amount')}: S/${item.amount.toStringAsFixed(2)}\n'
                    '${context.l10n.t('reservation_method')}: ${paymentMethodLabel(context, item.method)}\n'
                    '${context.l10n.t('incident_created_at')}: ${PeruTime.formatDateTime(item.createdAt)}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        label: Text(paymentStatusLabel(context, item.status)),
                        visualDensity: VisualDensity.compact,
                      ),
                      OutlinedButton(
                        onPressed: item.reservationId.isEmpty
                            ? null
                            : () => context.push(
                                '/reservation/${item.reservationId}',
                              ),
                        child: Text(context.l10n.t('ver')),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: AppErrorFormatter.readable(
            error,
            (String key, {Map<String, dynamic>? params}) => context.l10n.t(key),
          ),
          onRetry: () => ref.invalidate(clientPaymentHistoryProvider),
        ),
      ),
    );
  }
}

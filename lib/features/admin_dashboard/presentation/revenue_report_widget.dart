import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/widgets/state_views.dart';
import '../data/admin_dashboard_repository.dart';

final revenueReportProvider = FutureProvider.family<RevenueReport, DateTimeRange?>((ref, dateRange) async {
  if (dateRange == null) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = now;
    return ref.read(adminDashboardRepositoryProvider).getRevenueReport(start, end);
  }
  return ref.read(adminDashboardRepositoryProvider).getRevenueReport(dateRange.start, dateRange.end);
});

final selectedDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

class RevenueReportWidget extends ConsumerWidget {
  const RevenueReportWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(selectedDateRangeProvider);
    final reportAsync = ref.watch(revenueReportProvider(dateRange));
    final l10n = context.l10n;
    final responsive = context.responsive;
    final currencyLocale = 'es_PE';
    final formatter = NumberFormat.simpleCurrency(locale: currencyLocale);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsive.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.t('dashboard_revenue'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _selectDateRange(context, ref),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(dateRange != null
                      ? '${DateFormat('dd/MM').format(dateRange.start)} - ${DateFormat('dd/MM').format(dateRange.end)}'
                      : l10n.t('select_dates')),
                ),
              ],
            ),
            SizedBox(height: responsive.itemGap),
            reportAsync.when(
              data: (report) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryRow(context, l10n, formatter, report),
                    SizedBox(height: responsive.sectionGap),
                    if (report.byDay.isNotEmpty) ...[
                      Text(
                        l10n.t('revenue_by_day'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SizedBox(height: responsive.itemGap),
                      SizedBox(
                        height: 150,
                        child: _RevenueTrendChart(
                          data: report.byDay,
                          formatter: formatter,
                        ),
                      ),
                    ],
                    if (report.byWarehouse.isNotEmpty) ...[
                      SizedBox(height: responsive.sectionGap),
                      Text(
                        l10n.t('revenue_by_warehouse'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SizedBox(height: responsive.itemGap),
                      ...report.byWarehouse.take(5).map((item) => _RevenueListTile(
                        title: item.warehouseName,
                        subtitle: '${item.reservationCount} ${l10n.t('reservas')}',
                        trailing: formatter.format(item.revenue),
                      )),
                    ],
                    if (report.byCity.isNotEmpty) ...[
                      SizedBox(height: responsive.sectionGap),
                      Text(
                        l10n.t('revenue_by_city'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SizedBox(height: responsive.itemGap),
                      ...report.byCity.take(5).map((item) => _RevenueListTile(
                        title: item.cityName,
                        subtitle: '${item.reservationCount} ${l10n.t('reservas')}',
                        trailing: formatter.format(item.revenue),
                      )),
                    ],
                  ],
                );
              },
              loading: () => const LoadingStateView(),
              error: (e, _) => ErrorStateView(
                message: '$e',
                onRetry: () => ref.invalidate(revenueReportProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, AppLocalizations l10n, NumberFormat formatter, RevenueReport report) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _SummaryChip(
          label: l10n.t('total_revenue'),
          value: formatter.format(report.totalRevenue),
          color: Colors.green,
        ),
        _SummaryChip(
          label: l10n.t('total_reservations'),
          value: '${report.totalReservations}',
          color: Colors.blue,
        ),
        _SummaryChip(
          label: l10n.t('average_ticket'),
          value: formatter.format(report.averageReservationValue),
          color: Colors.orange,
        ),
      ],
    );
  }

  Future<void> _selectDateRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: ref.read(selectedDateRangeProvider),
    );
    if (picked != null) {
      ref.read(selectedDateRangeProvider.notifier).state = picked;
    }
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _RevenueTrendChart extends StatelessWidget {
  final List<RevenueByDay> data;
  final NumberFormat formatter;

  const _RevenueTrendChart({required this.data, required this.formatter});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    
    final maxRevenue = data.map((e) => e.revenue.toDouble()).reduce((a, b) => a > b ? a : b);
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        final height = maxRevenue > 0 ? (item.revenue.toDouble() / maxRevenue) * 120 : 0.0;
        return SizedBox(
          width: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                formatter.format(item.revenue.toDouble()),
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                height: height.clamp(4.0, 120.0),
                width: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.date.substring(5),
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RevenueListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;

  const _RevenueListTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/utils/peru_time.dart';
import '../domain/dashboard_optimized_provider.dart';

enum AdminDashboardPeriodOption { week, month, year }

extension AdminDashboardPeriodOptionX on AdminDashboardPeriodOption {
  String get code => switch (this) {
    AdminDashboardPeriodOption.week => 'week',
    AdminDashboardPeriodOption.month => 'month',
    AdminDashboardPeriodOption.year => 'year',
  };

  String get label => switch (this) {
    AdminDashboardPeriodOption.week => 'period_week',
    AdminDashboardPeriodOption.month => 'period_month',
    AdminDashboardPeriodOption.year => 'period_year',
  };
}

final adminDashboardPeriodProvider = StateProvider<AdminDashboardPeriodOption>(
  (ref) => AdminDashboardPeriodOption.month,
);

final adminDashboardNotifierProvider =
    StateNotifierProvider<DashboardStatsNotifier, AsyncValue<Map<String, dynamic>>>(
  (ref) => DashboardStatsNotifier(ref),
);

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPeriod = ref.watch(adminDashboardPeriodProvider);
    final dashboard = ref.watch(adminDashboardNotifierProvider);

    return AppShellScaffold(
      title: context.l10n.t('admin_dashboard_title'),
      currentRoute: '/admin/dashboard',
      child: dashboard.when(
        data: (stats) {
          ref.read(adminDashboardNotifierProvider.notifier).setPeriod(selectedPeriod.code);
          return _DashboardContent(stats: stats, selectedPeriod: selectedPeriod);
        },
        loading: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(adminDashboardNotifierProvider.notifier).refresh();
          });
          return const LoadingStateView();
        },
        error: (error, _) => ErrorStateView(
          message: '${context.l10n.t('dashboard_load_failed')}: $error',
          onRetry: () => ref.read(adminDashboardNotifierProvider.notifier).refresh(force: true),
        ),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.stats, required this.selectedPeriod});

  final Map<String, dynamic> stats;
  final AdminDashboardPeriodOption selectedPeriod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = _asMap(stats['summary']);
    final topWarehouses = _asList(stats['topWarehouses']);
    final topCities = _asList(stats['topCities']);
    final topCouriers = _asList(stats['topCouriers']);
    final topOperators = _asList(stats['topOperators']);
    final trend = _asList(stats['trend']);
    final statusBreakdown = _asList(stats['statusBreakdown']);
    final bestWarehouse = _asMap(stats['bestWarehouse']);
    final localeCode = Localizations.localeOf(
      context,
    ).languageCode.trim().toLowerCase();
    final currencyLocale = localeCode == 'es' ? 'es_PE' : localeCode;

    final formatter = NumberFormat.currency(
      locale: currencyLocale,
      symbol: 'S/',
      decimalDigits: 2,
    );
    final l10n = context.l10n;
    final kpiCards = <_KpiStat>[
      _KpiStat(
        title: l10n.t('reservas'),
        value: '${_asInt(summary['reservations'])}',
        subtitle: l10n.t('dashboard_period_selected'),
        colors: const [Color(0xFF0B8B8C), Color(0xFF2AAAC2)],
      ),
      _KpiStat(
        title: l10n.t('dashboard_revenue'),
        value: formatter.format(_asDouble(summary['confirmedRevenue'])),
        subtitle: l10n.t('dashboard_confirmed_collections'),
        colors: const [Color(0xFF1F6E8C), Color(0xFF3F9AC1)],
      ),
      _KpiStat(
        title: l10n.t('dashboard_clients'),
        value: '${_asInt(summary['uniqueClients'])}',
        subtitle: l10n.t('admin_dashboard_unique_clients'),
        colors: const [Color(0xFF475569), Color(0xFF64748B)],
      ),
      _KpiStat(
        title: l10n.t('dashboard_completed'),
        value: '${_asInt(summary['completedReservations'])}',
        subtitle: '${_asDouble(summary['completionRate']).toStringAsFixed(1)}%',
        colors: const [Color(0xFF168F64), Color(0xFF30A46C)],
      ),
      _KpiStat(
        title: l10n.t('dashboard_cancelled'),
        value: '${_asInt(summary['cancelledReservations'])}',
        subtitle:
            '${_asDouble(summary['cancellationRate']).toStringAsFixed(1)}%',
        colors: const [Color(0xFFC43D3D), Color(0xFFDE7060)],
      ),
      _KpiStat(
        title: l10n.t('dashboard_active'),
        value: '${_asInt(summary['activeReservations'])}',
        subtitle:
            '${l10n.t('dashboard_open_incidents')}: ${_asInt(summary['openIncidents'])}',
        colors: const [Color(0xFF1D4ED8), Color(0xFF2563EB)],
      ),
    ];

    final responsive = context.responsive;
    final isMobile = responsive.isMobile;
    final cardPadding = responsive.cardPadding;
    final itemGap = responsive.itemGap;
    final sectionGap = responsive.sectionGap;
    final rankingMinHeight = isMobile ? 188.0 : 220.0;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 14 : 18),
            margin: EdgeInsets.all(isMobile ? 16 : 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF173B56), Color(0xFF1F6E8C)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('admin_dashboard_operations_hub'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: itemGap / 2),
                Text(
                  '${stats['periodLabel'] ?? context.l10n.t('admin_dashboard_current_period')} '
                  '- ${context.l10n.t('admin_dashboard_updated_prefix')} '
                  '${_formattedDate(stats['generatedAt'])}',
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
                SizedBox(height: sectionGap),
                SegmentedButton<AdminDashboardPeriodOption>(
                  segments: AdminDashboardPeriodOption.values
                      .map(
                        (period) => ButtonSegment(
                          value: period,
                          label: Text(_periodLabel(context, period)),
                        ),
                      )
                      .toList(),
                  selected: {selectedPeriod},
                  onSelectionChanged: (selection) {
                    ref.read(adminDashboardPeriodProvider.notifier).state =
                        selection.first;
                  },
                ),
              ],
            ),
          ),
          TabBar(
            isScrollable: isMobile,
            tabs: [
              Tab(text: context.l10n.t('admin_dashboard_tab_admin_core')),
              Tab(text: context.l10n.t('admin_dashboard_tab_operator_ops')),
              Tab(text: context.l10n.t('admin_dashboard_tab_incidents')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // TAB 1: Admin Core
                ListView(
                  padding: responsive.pageInsets(
                    top: responsive.verticalPadding,
                    bottom: responsive.sectionGap,
                  ),
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final spacing = itemGap;
                        final columns = _kpiColumnsForWidth(
                          constraints.maxWidth,
                        );
                        final totalSpacing = spacing * (columns - 1);
                        final cardWidth =
                            (constraints.maxWidth - totalSpacing) / columns -
                            0.1;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: kpiCards
                              .map(
                                (kpi) => SizedBox(
                                  width: cardWidth,
                                  child: _KpiCard(
                                    title: kpi.title,
                                    value: kpi.value,
                                    subtitle: kpi.subtitle,
                                    colors: kpi.colors,
                                    compact: isMobile,
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    SizedBox(height: sectionGap),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.warehouse_outlined),
                            title: Text(
                              context.l10n.t('operacion_de_almacenes'),
                            ),
                            subtitle: Text(
                              context.l10n.t('checkin_etiquetado_y_entrega'),
                            ),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () => context.go('/admin/warehouses'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.manage_accounts_outlined),
                            title: Text(context.l10n.t('users_and_roles')),
                            subtitle: Text(
                              context.l10n.t(
                                'access_roles_account_status',
                              ),
                            ),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () => context.go('/admin/users'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Wrap(
                          spacing: itemGap,
                          runSpacing: itemGap,
                          children: [
                            FilledButton.icon(
                              onPressed: () => context.go('/admin/tracking'),
                              icon: const Icon(Icons.route_outlined),
                              label: Text(context.l10n.t('tracking_logistico')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/admin/incidents'),
                              icon: Icon(Icons.support_agent_outlined),
                              label: Text(context.l10n.t('soporte')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.go('/admin/reservations'),
                              icon: Icon(Icons.luggage_outlined),
                              label: Text(context.l10n.t('reservas')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/ops/qr-handoff'),
                              icon: Icon(Icons.qr_code_scanner_outlined),
                              label: Text(context.l10n.t('qr_y_pin')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (bestWarehouse.isNotEmpty) ...[
                      SizedBox(height: sectionGap),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.emoji_events_outlined),
                          title: Text(
                            '${context.l10n.t('admin_dashboard_best_warehouse_prefix')}: ${bestWarehouse['warehouseName'] ?? '-'}',
                          ),
                          subtitle: Text(
                            '${bestWarehouse['city'] ?? '-'} - ${_asInt(bestWarehouse['interactionCount'])} ${context.l10n.t('dashboard_interactions')} - ${formatter.format(_asDouble(bestWarehouse['confirmedRevenue']))}',
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: sectionGap),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.t(
                                'admin_dashboard_period_trend_title',
                              ),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: sectionGap),
                            _TrendChart(
                              points: trend,
                              selectedPeriod: selectedPeriod,
                              formatter: formatter,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final spacing = sectionGap;
                        final columns = _rankingColumnsForWidth(
                          constraints.maxWidth,
                        );
                        final totalSpacing = spacing * (columns - 1);
                        final cardWidth =
                            (constraints.maxWidth - totalSpacing) / columns -
                            0.1;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _RankingCard(
                                title: context.l10n.t(
                                  'dashboard_top_warehouses',
                                ),
                                minHeight: rankingMinHeight,
                                padding: cardPadding,
                                spacing: itemGap,
                                children: topWarehouses.isEmpty
                                    ? [
                                        Text(
                                          context.l10n.t(
                                            'aun_no_hay_data_para_este_periodo',
                                          ),
                                        ),
                                      ]
                                    : topWarehouses.take(5).map((item) {
                                        return _RankingTile(
                                          title:
                                              item['warehouseName']
                                                  ?.toString() ??
                                              '-',
                                          subtitle:
                                              '${item['city'] ?? '-'} - ${_asInt(item['interactionCount'])} ${context.l10n.t('dashboard_interactions')}',
                                          trailing: formatter.format(
                                            _asDouble(item['confirmedRevenue']),
                                          ),
                                          progress: _ratio(
                                            _asDouble(item['interactionCount']),
                                            _maxValue(
                                              topWarehouses,
                                              'interactionCount',
                                            ),
                                          ),
                                        );
                                      }).toList(),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _RankingCard(
                                title: context.l10n.t('dashboard_top_cities'),
                                minHeight: rankingMinHeight,
                                padding: cardPadding,
                                spacing: itemGap,
                                children: topCities.isEmpty
                                    ? [
                                        Text(
                                          context.l10n.t(
                                            'aun_no_hay_data_para_este_periodo',
                                          ),
                                        ),
                                      ]
                                    : topCities.take(5).map((item) {
                                        return _RankingTile(
                                          title:
                                              item['city']?.toString() ?? '-',
                                          subtitle:
                                              '${_asInt(item['interactionCount'])} ${context.l10n.t('reservas')} - ${_asInt(item['incidentCount'])} ${context.l10n.t('incidencias')}',
                                          trailing: formatter.format(
                                            _asDouble(item['confirmedRevenue']),
                                          ),
                                          progress: _ratio(
                                            _asDouble(item['interactionCount']),
                                            _maxValue(
                                              topCities,
                                              'interactionCount',
                                            ),
                                          ),
                                        );
                                      }).toList(),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _RankingCard(
                                title: context.l10n.t('dashboard_top_couriers'),
                                minHeight: rankingMinHeight,
                                padding: cardPadding,
                                spacing: itemGap,
                                children: topCouriers.isEmpty
                                    ? [
                                        Text(
                                          context.l10n.t(
                                            'admin_dashboard_no_courier_data',
                                          ),
                                        ),
                                      ]
                                    : topCouriers.take(5).map((item) {
                                        return _RankingTile(
                                          title:
                                              item['fullName']?.toString() ??
                                              '-',
                                          subtitle:
                                              '${item['email'] ?? '-'} | ${_asInt(item['activeDeliveryCount'])} ${context.l10n.t('dashboard_active')}',
                                          trailing:
                                              '${_asInt(item['deliveryCompletedCount'])} ${context.l10n.t('dashboard_completed')}',
                                          progress: _ratio(
                                            _asDouble(
                                              item['deliveryCompletedCount'],
                                            ),
                                            _maxValue(
                                              topCouriers,
                                              'deliveryCompletedCount',
                                            ),
                                          ),
                                        );
                                      }).toList(),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _RankingCard(
                                title: context.l10n.t(
                                  'dashboard_top_operators',
                                ),
                                minHeight: rankingMinHeight,
                                padding: cardPadding,
                                spacing: itemGap,
                                children: topOperators.isEmpty
                                    ? [
                                        Text(
                                          context.l10n.t(
                                            'admin_dashboard_no_operator_data',
                                          ),
                                        ),
                                      ]
                                    : topOperators.take(5).map((item) {
                                        return _RankingTile(
                                          title:
                                              item['fullName']?.toString() ??
                                              '-',
                                          subtitle:
                                              '${item['email'] ?? '-'} | ${_asInt(item['activeDeliveryCount'])} ${context.l10n.t('dashboard_active')}',
                                          trailing:
                                              '${_asInt(item['deliveryCreatedCount'])} ${context.l10n.t('dashboard_created')}',
                                          progress: _ratio(
                                            _asDouble(
                                              item['deliveryCreatedCount'],
                                            ),
                                            _maxValue(
                                              topOperators,
                                              'deliveryCreatedCount',
                                            ),
                                          ),
                                        );
                                      }).toList(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: sectionGap),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.t('dashboard_reservation_status'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: itemGap),
                            Wrap(
                              spacing: itemGap,
                              runSpacing: itemGap,
                              children: statusBreakdown
                                  .map(
                                    (item) => Chip(
                                      label: Text(
                                        '${item['label'] ?? item['status']}: ${_asInt(item['count'])}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // TAB 2: Operaciones Operador
                ListView(
                  padding: responsive.pageInsets(
                    top: responsive.verticalPadding,
                    bottom: responsive.sectionGap,
                  ),
                  children: [
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.assignment_outlined),
                            title: Text(context.l10n.t('reservas_operativas')),
                            subtitle: Text(
                              context.l10n.t('admin_dashboard_latest_5_paged'),
                            ),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () => context.go('/operator/reservations'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.point_of_sale_outlined),
                            title: Text(context.l10n.t('pagos_en_caja')),
                            subtitle: Text(
                              context.l10n.t(
                                'dashboard_cash_validation_subtitle',
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/operator/cash-payments'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.qr_code_scanner_outlined),
                            title: Text(context.l10n.t('operacion_qr_y_pin')),
                            subtitle: Text(
                              context.l10n.t('admin_dashboard_qr_pin_subtitle'),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/ops/qr-handoff'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.route_outlined),
                            title: Text(context.l10n.t('tracking_logistico')),
                            subtitle: Text(
                              context.l10n.t(
                                'seguimiento_de_deliveries_en_vivo',
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/operator/tracking'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text(context.l10n.t('historial_de_pagos')),
                            subtitle: Text(
                              context.l10n.t('trazabilidad_completa_de_cobros'),
                            ),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () => context.go('/admin/payments-history'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // TAB 3: Incidencias
                ListView(
                  padding: responsive.pageInsets(
                    top: responsive.verticalPadding,
                    bottom: responsive.sectionGap,
                  ),
                  children: [
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.warning_amber_outlined),
                            title: Text(context.l10n.t('incidencias')),
                            subtitle: Text(
                              context.l10n.t('seguimiento_y_resolucion'),
                            ),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () => context.go('/admin/incidents'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.support_agent_outlined),
                            title: Text(context.l10n.t('soporte')),
                            subtitle: Text(
                              context.l10n.t(
                                'incident_support_ticket_subtitle',
                              ),
                            ),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () => context.go('/support/incidents'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.points,
    required this.selectedPeriod,
    required this.formatter,
  });

  final List<dynamic> points;
  final AdminDashboardPeriodOption selectedPeriod;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Text(context.l10n.t('sin_datos_para_graficar'));
    }
    final maxRevenue = _maxValue(points, 'confirmedRevenue');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((rawPoint) {
          final point = _asMap(rawPoint);
          final revenue = _asDouble(point['confirmedRevenue']);
          final height = maxRevenue == 0
              ? 0.18
              : (revenue / maxRevenue).clamp(0.18, 1.0);
          return SizedBox(
            width: selectedPeriod == AdminDashboardPeriodOption.year ? 56 : 42,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_asInt(point['reservations'])}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 6),
                Container(
                  height: 120 * height,
                  width: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xFF0B8B8C), Color(0xFF5CC7D8)],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  point['label']?.toString() ?? '-',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  formatter.format(revenue),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.progress,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(trailing),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF0B8B8C)),
          ),
        ],
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.children,
    required this.minHeight,
    required this.padding,
    required this.spacing,
  });

  final String title;
  final List<Widget> children;
  final double minHeight;
  final double padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: spacing),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.colors,
    required this.compact,
  });

  final String title;
  final String value;
  final String subtitle;
  final List<Color> colors;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padding = compact ? 12.0 : 16.0;
    final minHeight = compact ? 100.0 : 120.0;
    return Container(
      padding: EdgeInsets.all(padding),
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withOpacity(0.88)),
          ),
        ],
      ),
    );
  }
}

class _KpiStat {
  const _KpiStat({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.colors,
  });

  final String title;
  final String value;
  final String subtitle;
  final List<Color> colors;
}

int _kpiColumnsForWidth(double width) {
  if (width < 560) return 1;
  if (width < 860) return 2;
  final estimated = ((width + 10) / 170).floor();
  return estimated.clamp(2, 4).toInt();
}

int _rankingColumnsForWidth(double width) {
  if (width >= 1360) return 4;
  if (width >= 980) return 2;
  return 1;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }
  return const <dynamic>[];
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double _maxValue(List<dynamic> items, String key) {
  double max = 0;
  for (final item in items) {
    final value = _asDouble(_asMap(item)[key]);
    if (value > max) {
      max = value;
    }
  }
  return max;
}

double _ratio(double value, double max) {
  if (max <= 0) {
    return 0;
  }
  return value / max;
}

String _periodLabel(BuildContext context, AdminDashboardPeriodOption period) {
  switch (period) {
    case AdminDashboardPeriodOption.week:
      return context.l10n.t('period_week');
    case AdminDashboardPeriodOption.month:
      return context.l10n.t('period_month');
    case AdminDashboardPeriodOption.year:
      return context.l10n.t('period_year');
  }
}

String _formattedDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return '-';
  }
  return PeruTime.formatDateTime(parsed);
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/state/realtime_app_event_cursor_provider.dart';
import '../../../shared/state/warehouse_catalog_sync.dart';
import '../../../shared/utils/peru_time.dart';

enum AdminDashboardPeriodOption { week, month, year }

extension AdminDashboardPeriodOptionX on AdminDashboardPeriodOption {
  String get code => switch (this) {
    AdminDashboardPeriodOption.week => 'week',
    AdminDashboardPeriodOption.month => 'month',
    AdminDashboardPeriodOption.year => 'year',
  };

  String get label => switch (this) {
    AdminDashboardPeriodOption.week => 'Semana',
    AdminDashboardPeriodOption.month => 'Mes',
    AdminDashboardPeriodOption.year => 'Anio',
  };
}

final adminDashboardPeriodProvider = StateProvider<AdminDashboardPeriodOption>(
  (ref) => AdminDashboardPeriodOption.month,
);

final adminDashboardProvider =
    FutureProvider.family<Map<String, dynamic>, AdminDashboardPeriodOption>((
      ref,
      period,
    ) async {
      ref.watch(realtimeAppEventCursorProvider);
      ref.watch(warehouseCatalogVersionProvider);
      final dio = ref.read(dioProvider);
      const paths = [
        '/admin/dashboard',
        '/admin/dashboard/summary',
        '/admin/stats',
        '/admin/overview',
      ];

      DioException? lastError;
      for (final path in paths) {
        try {
          final response = await dio.get<Map<String, dynamic>>(
            path,
            queryParameters: {'period': period.code},
          );
          return response.data ?? <String, dynamic>{};
        } on DioException catch (error) {
          lastError = error;
          final statusCode = error.response?.statusCode ?? 0;
          if (statusCode != 404 && statusCode != 405) {
            rethrow;
          }
        }
      }

      throw lastError ?? StateError('No se pudo cargar dashboard admin');
    });

class AdminDashboardPage extends ConsumerWidget {
  AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPeriod = ref.watch(adminDashboardPeriodProvider);
    final dashboard = ref.watch(adminDashboardProvider(selectedPeriod));

    return AppShellScaffold(
      title: 'Panel admin',
      currentRoute: '/admin/dashboard',
      child: dashboard.when(
        data: (stats) =>
            _DashboardContent(stats: stats, selectedPeriod: selectedPeriod),
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(
          message: 'No se pudo cargar dashboard: ${_errorMessage(error)}',
          onRetry: () => ref.invalidate(adminDashboardProvider(selectedPeriod)),
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

    final formatter = NumberFormat.currency(
      locale: 'es_PE',
      symbol: 'S/',
      decimalDigits: 2,
    );
    final kpiCards = <_KpiStat>[
      _KpiStat(
        title: 'Reservas',
        value: '${_asInt(summary['reservations'])}',
        subtitle: 'Periodo seleccionado',
        colors: const [Color(0xFF0B8B8C), Color(0xFF2AAAC2)],
      ),
      _KpiStat(
        title: 'Ingresos',
        value: formatter.format(_asDouble(summary['confirmedRevenue'])),
        subtitle: 'Cobros confirmados',
        colors: const [Color(0xFF1F6E8C), Color(0xFF3F9AC1)],
      ),
      _KpiStat(
        title: 'Clientes',
        value: '${_asInt(summary['uniqueClients'])}',
        subtitle: 'Clientes únicos',
        colors: const [Color(0xFF475569), Color(0xFF64748B)],
      ),
      _KpiStat(
        title: 'Completadas',
        value: '${_asInt(summary['completedReservations'])}',
        subtitle: '${_asDouble(summary['completionRate']).toStringAsFixed(1)}%',
        colors: const [Color(0xFF168F64), Color(0xFF30A46C)],
      ),
      _KpiStat(
        title: 'Canceladas',
        value: '${_asInt(summary['cancelledReservations'])}',
        subtitle:
            '${_asDouble(summary['cancellationRate']).toStringAsFixed(1)}%',
        colors: const [Color(0xFFC43D3D), Color(0xFFDE7060)],
      ),
      _KpiStat(
        title: 'Activas',
        value: '${_asInt(summary['activeReservations'])}',
        subtitle: 'Incidencias abiertas: ${_asInt(summary['openIncidents'])}',
        colors: const [Color(0xFF1D4ED8), Color(0xFF2563EB)],
      ),
    ];

    final responsive = context.responsive;
    return ListView(
      padding: responsive.pageInsets(
        top: responsive.verticalPadding,
        bottom: 24,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
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
                'Operación central',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${stats['periodLabel'] ?? 'Periodo actual'} - actualizado ${_formattedDate(stats['generatedAt'])}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 14),
              SegmentedButton<AdminDashboardPeriodOption>(
                segments: AdminDashboardPeriodOption.values
                    .map(
                      (period) => ButtonSegment(
                        value: period,
                        label: Text(period.label),
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
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final columns = _kpiColumnsForWidth(constraints.maxWidth);
            final totalSpacing = spacing * (columns - 1);
            final cardWidth =
                (constraints.maxWidth - totalSpacing) / columns - 0.1;

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
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
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
                  onPressed: () => context.go('/admin/reservations'),
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
        SizedBox(height: 16),
        if (bestWarehouse.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: Text(
                'Mejor almacén: ${bestWarehouse['warehouseName'] ?? '-'}',
              ),
              subtitle: Text(
                '${bestWarehouse['city'] ?? '-'} - ${_asInt(bestWarehouse['interactionCount'])} interacciones - ${formatter.format(_asDouble(bestWarehouse['confirmedRevenue']))}',
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evolucion del periodo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _TrendChart(
                  points: trend,
                  selectedPeriod: selectedPeriod,
                  formatter: formatter,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final columns = _rankingColumnsForWidth(constraints.maxWidth);
            final totalSpacing = spacing * (columns - 1);
            final cardWidth =
                (constraints.maxWidth - totalSpacing) / columns - 0.1;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _RankingCard(
                    title: 'Top almacenes',
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
                              title: item['warehouseName']?.toString() ?? '-',
                              subtitle:
                                  '${item['city'] ?? '-'} - ${_asInt(item['interactionCount'])} interacciones',
                              trailing: formatter.format(
                                _asDouble(item['confirmedRevenue']),
                              ),
                              progress: _ratio(
                                _asDouble(item['interactionCount']),
                                _maxValue(topWarehouses, 'interactionCount'),
                              ),
                            );
                          }).toList(),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _RankingCard(
                    title: 'Ciudades con mayor demanda',
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
                              title: item['city']?.toString() ?? '-',
                              subtitle:
                                  '${_asInt(item['interactionCount'])} reservas - ${_asInt(item['incidentCount'])} incidencias',
                              trailing: formatter.format(
                                _asDouble(item['confirmedRevenue']),
                              ),
                              progress: _ratio(
                                _asDouble(item['interactionCount']),
                                _maxValue(topCities, 'interactionCount'),
                              ),
                            );
                          }).toList(),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _RankingCard(
                    title: 'Top couriers',
                    children: topCouriers.isEmpty
                        ? const [
                            Text(
                              'Aún no hay entregas suficientes en este periodo.',
                            ),
                          ]
                        : topCouriers.take(5).map((item) {
                            return _RankingTile(
                              title: item['fullName']?.toString() ?? '-',
                              subtitle:
                                  '${item['email'] ?? '-'} | ${_asInt(item['activeDeliveryCount'])} activos',
                              trailing:
                                  '${_asInt(item['deliveryCompletedCount'])} completados',
                              progress: _ratio(
                                _asDouble(item['deliveryCompletedCount']),
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
                    title: 'Top operadores',
                    children: topOperators.isEmpty
                        ? const [
                            Text(
                              'Aún no hay operadores con servicios generados.',
                            ),
                          ]
                        : topOperators.take(5).map((item) {
                            return _RankingTile(
                              title: item['fullName']?.toString() ?? '-',
                              subtitle:
                                  '${item['email'] ?? '-'} | ${_asInt(item['activeDeliveryCount'])} activos',
                              trailing:
                                  '${_asInt(item['deliveryCreatedCount'])} creados',
                              progress: _ratio(
                                _asDouble(item['deliveryCreatedCount']),
                                _maxValue(topOperators, 'deliveryCreatedCount'),
                              ),
                            );
                          }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado de reservas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.warehouse_outlined),
                title: Text(context.l10n.t('operacion_de_almacenes')),
                subtitle: Text(context.l10n.t('checkin_etiquetado_y_entrega')),
                trailing: Icon(Icons.chevron_right),
                onTap: () => context.go('/admin/warehouses'),
              ),
              ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: Text(context.l10n.t('reservas')),
                subtitle: Text(context.l10n.t('busqueda_y_cambios_de_estado')),
                trailing: Icon(Icons.chevron_right),
                onTap: () => context.go('/admin/reservations'),
              ),
              ListTile(
                leading: const Icon(Icons.point_of_sale_outlined),
                title: Text(context.l10n.t('pagos_en_caja')),
                subtitle: Text('Validacion de pagos cash/counter pendientes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/admin/cash-payments'),
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: Text(context.l10n.t('incidencias')),
                subtitle: Text(context.l10n.t('seguimiento_y_resolucion')),
                trailing: Icon(Icons.chevron_right),
                onTap: () => context.go('/admin/incidents'),
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
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: Text(context.l10n.t('usuarios_y_roles')),
                subtitle: Text(
                  context.l10n.t('accesos_roles_y_estados_de_cuenta'),
                ),
                trailing: Icon(Icons.chevron_right),
                onTap: () => context.go('/admin/users'),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner_outlined),
                title: Text(context.l10n.t('operacion_qr_y_pin')),
                subtitle: Text(
                  'Escaneo, etiqueta de maleta, validación presencial y delivery seguro',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/ops/qr-handoff'),
              ),
            ],
          ),
        ),
      ],
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
  const _RankingCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 220),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
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
  });

  final String title;
  final String value;
  final String subtitle;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.88)),
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

String _formattedDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return '-';
  }
  return PeruTime.formatDateTime(parsed);
}

String _errorMessage(Object error) {
  final text = error.toString();
  final match = RegExp(r'message[=:]\s*([^,}]+)').firstMatch(text);
  if (match != null) {
    return match.group(1)!.trim();
  }
  return text;
}
